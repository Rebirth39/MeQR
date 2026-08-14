package com.lucasli.meqr;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.DownloadManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.Settings;
import android.widget.Toast;

import org.json.JSONObject;

import java.io.BufferedInputStream;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Locale;

final class AppUpdateManager {
    private static final String MANIFEST_URL = "https://meqrcode.cn/config/android-update.json";
    private final Activity activity;
    private final I18n i18n;
    private Uri pendingInstallUri;
    private boolean checkedAutomatically;

    AppUpdateManager(Activity activity, I18n i18n) {
        this.activity = activity;
        this.i18n = i18n;
    }

    void checkAutomatically() {
        if (checkedAutomatically) {
            return;
        }
        checkedAutomatically = true;
        check(false);
    }

    void checkManually() {
        check(true);
    }

    void onResume() {
        if (pendingInstallUri != null && canInstallPackages()) {
            Uri uri = pendingInstallUri;
            pendingInstallUri = null;
            launchInstaller(uri);
        }
    }

    private void check(boolean userInitiated) {
        new Thread(() -> {
            try {
                JSONObject latest = fetchManifest().getJSONObject("latest");
                int versionCode = latest.getInt("versionCode");
                if (versionCode <= currentVersionCode()) {
                    if (userInitiated) {
                        activity.runOnUiThread(() -> toast(i18n.t("alreadyLatest")));
                    }
                    return;
                }
                Update update = Update.from(latest, i18n.resolvedLanguage());
                activity.runOnUiThread(() -> showUpdate(update));
            } catch (Exception exception) {
                if (userInitiated) {
                    activity.runOnUiThread(() -> toast(i18n.t("updateCheckFailed")));
                }
            }
        }, "MeQR-UpdateCheck").start();
    }

    private long currentVersionCode() throws Exception {
        PackageInfo info = activity.getPackageManager().getPackageInfo(activity.getPackageName(), 0);
        return Build.VERSION.SDK_INT >= 28 ? info.getLongVersionCode() : info.versionCode;
    }

    private JSONObject fetchManifest() throws Exception {
        HttpURLConnection connection = (HttpURLConnection) new URL(MANIFEST_URL).openConnection();
        connection.setConnectTimeout(10000);
        connection.setReadTimeout(12000);
        connection.setRequestProperty("Accept", "application/json");
        connection.setRequestProperty("Cache-Control", "no-cache");
        connection.connect();
        if (connection.getResponseCode() < 200 || connection.getResponseCode() >= 300) {
            throw new IllegalStateException("HTTP " + connection.getResponseCode());
        }
        try (BufferedInputStream input = new BufferedInputStream(connection.getInputStream());
             ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[8192];
            int read;
            while ((read = input.read(buffer)) >= 0) {
                output.write(buffer, 0, read);
            }
            return new JSONObject(new String(output.toByteArray(), StandardCharsets.UTF_8));
        } finally {
            connection.disconnect();
        }
    }

    private void showUpdate(Update update) {
        new AlertDialog.Builder(activity)
                .setTitle(i18n.t("updateAvailable") + " " + update.versionName)
                .setMessage(update.notes)
                .setNegativeButton(i18n.t("later"), null)
                .setPositiveButton(i18n.t("updateNow"), (dialog, which) -> download(update))
                .show();
    }

    private void download(Update update) {
        try {
            Uri uri = Uri.parse(update.apkUrl);
            if (!"https".equalsIgnoreCase(uri.getScheme()) || !"meqrcode.cn".equalsIgnoreCase(uri.getHost())) {
                throw new IllegalArgumentException("Untrusted update URL");
            }

            String fileName = "MeQR-Android-" + update.versionName + ".apk";
            DownloadManager.Request request = new DownloadManager.Request(uri)
                    .setTitle("MeQR " + update.versionName)
                    .setDescription(i18n.t("downloadingUpdate"))
                    .setMimeType("application/vnd.android.package-archive")
                    .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                    .setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, fileName);
            DownloadManager manager = (DownloadManager) activity.getSystemService(Context.DOWNLOAD_SERVICE);
            long downloadId = manager.enqueue(request);
            toast(i18n.t("downloadingUpdate"));
            waitForDownload(manager, downloadId, update.sha256);
        } catch (Exception exception) {
            toast(i18n.t("updateDownloadFailed"));
        }
    }

    private void waitForDownload(DownloadManager manager, long downloadId, String expectedSha256) {
        new Thread(() -> {
            DownloadManager.Query query = new DownloadManager.Query().setFilterById(downloadId);
            while (true) {
                try (Cursor cursor = manager.query(query)) {
                    if (cursor != null && cursor.moveToFirst()) {
                        int status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS));
                        if (status == DownloadManager.STATUS_SUCCESSFUL) {
                            Uri uri = manager.getUriForDownloadedFile(downloadId);
                            if (uri != null && verifySha256(uri, expectedSha256)) {
                                activity.runOnUiThread(() -> requestInstall(uri));
                            } else {
                                activity.runOnUiThread(() -> toast(i18n.t("updateVerificationFailed")));
                            }
                            return;
                        }
                        if (status == DownloadManager.STATUS_FAILED) {
                            activity.runOnUiThread(() -> toast(i18n.t("updateDownloadFailed")));
                            return;
                        }
                    }
                } catch (Exception exception) {
                    activity.runOnUiThread(() -> toast(i18n.t("updateDownloadFailed")));
                    return;
                }

                try {
                    Thread.sleep(1000);
                } catch (InterruptedException exception) {
                    Thread.currentThread().interrupt();
                    return;
                }
            }
        }, "MeQR-UpdateDownload").start();
    }

    private boolean verifySha256(Uri uri, String expected) {
        if (expected == null || !expected.matches("[0-9a-fA-F]{64}")) {
            return false;
        }
        try (InputStream input = activity.getContentResolver().openInputStream(uri)) {
            if (input == null) {
                return false;
            }
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] buffer = new byte[8192];
            int read;
            while ((read = input.read(buffer)) >= 0) {
                digest.update(buffer, 0, read);
            }
            StringBuilder actual = new StringBuilder();
            for (byte value : digest.digest()) {
                actual.append(String.format(Locale.US, "%02x", value & 0xff));
            }
            return actual.toString().equalsIgnoreCase(expected);
        } catch (Exception exception) {
            return false;
        }
    }

    private void requestInstall(Uri uri) {
        if (!canInstallPackages()) {
            pendingInstallUri = uri;
            Intent settings = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:" + activity.getPackageName()));
            activity.startActivity(settings);
            toast(i18n.t("allowInstallUpdates"));
            return;
        }
        launchInstaller(uri);
    }

    private boolean canInstallPackages() {
        return Build.VERSION.SDK_INT < 26 || activity.getPackageManager().canRequestPackageInstalls();
    }

    private void launchInstaller(Uri uri) {
        Intent install = new Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_ACTIVITY_NEW_TASK);
        activity.startActivity(install);
    }

    private void toast(String message) {
        Toast.makeText(activity, message, Toast.LENGTH_LONG).show();
    }

    private static final class Update {
        final String versionName;
        final String apkUrl;
        final String sha256;
        final String notes;

        Update(String versionName, String apkUrl, String sha256, String notes) {
            this.versionName = versionName;
            this.apkUrl = apkUrl;
            this.sha256 = sha256;
            this.notes = notes;
        }

        static Update from(JSONObject object, String language) {
            JSONObject notes = object.optJSONObject("notes");
            String localizedNotes = notes == null ? "" : notes.optString(language, notes.optString("zh-Hans", ""));
            return new Update(
                    object.optString("versionName", ""),
                    object.optString("apkUrl", ""),
                    object.optString("sha256", ""),
                    localizedNotes
            );
        }
    }
}
