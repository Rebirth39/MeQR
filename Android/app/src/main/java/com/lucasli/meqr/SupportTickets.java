package com.lucasli.meqr;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.res.AssetFileDescriptor;
import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;
import android.graphics.Color;
import android.text.InputFilter;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.EditText;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

final class SupportTickets {
    static final int PICK_ATTACHMENT = 1008;
    private static final long MAX_ATTACHMENT_BYTES = 50L * 1024L * 1024L;
    private static final String BLANK_CODE_PATTERN = "[A-HJ-KM-NP-Z2-9]{6}";
    private static final String BASE = "https://report.meqrcode.cn";
    private static final String PREFS = "support";
    private static final long ALERT_THROTTLE_MS = 60_000L;
    private static volatile String alertText;
    private static volatile long lastAlertCheck;
    private static boolean fetchingBlank;
    private static boolean blankFetchQueued;
    private static long blankEpoch;
    private static Runnable pendingBlankCallback;
    private static java.lang.ref.WeakReference<Activity> pendingBlankHost;
    private static java.util.function.Consumer<Uri> attachmentCallback;

    static final class TooLarge extends Exception { }

    private static final class SelectedAttachment {
        final Uri uri;
        final String name;
        final String mime;
        final long size;

        SelectedAttachment(Uri uri, String name, String mime, long size) {
            this.uri = uri;
            this.name = name;
            this.mime = mime;
            this.size = size;
        }
    }

    static synchronized String deviceId(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        String id = prefs.getString("device_id", "");
        if (id.isEmpty()) {
            id = UUID.randomUUID().toString();
            prefs.edit().putString("device_id", id).apply();
        }
        return id;
    }

    static synchronized String cachedBlankCode(Context context) {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("blank_code", "");
    }

    static void prepareBlankCode(Activity activity, Runnable onReady) {
        fetchBlankCode(activity, false, onReady);
    }

    static void refreshBlankCode(Activity activity, Runnable onReady) {
        fetchBlankCode(activity, true, onReady);
    }

    // The server binds the blank code to the ticket and tells us its replacement
    // (next_support_code). Anonymous submissions never reach this method: only a
    // non-empty consumed code bumps the epoch and triggers a re-fetch.
    static void blankCodeConsumed(Context context, String consumed, String nextCode) {
        if (consumed == null || consumed.isEmpty()) return;
        boolean refetch = false;
        synchronized (SupportTickets.class) {
            blankEpoch++;
            SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
            if (consumed.equals(prefs.getString("blank_code", ""))) {
                prefs.edit().remove("blank_code").apply();
            }
            if (nextCode != null && nextCode.matches(BLANK_CODE_PATTERN)) {
                prefs.edit().putString("blank_code", nextCode).apply();
            } else {
                refetch = true;
            }
        }
        if (refetch) fetchBlankCode(context.getApplicationContext(), true, null);
    }

    private static void fetchBlankCode(Context context, boolean force, Runnable onReady) {
        final long startEpoch;
        synchronized (SupportTickets.class) {
            if (onReady != null && context instanceof Activity) {
                pendingBlankCallback = onReady;
                pendingBlankHost = new java.lang.ref.WeakReference<>((Activity) context);
            }
            if (!force && !context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("blank_code", "").isEmpty()) {
                firePendingBlankCallback();
                return;
            }
            if (fetchingBlank) {
                blankFetchQueued = true;
                return;
            }
            fetchingBlank = true;
            startEpoch = blankEpoch;
        }
        final Context app = context.getApplicationContext();
        new Thread(() -> {
            String code = null;
            String issuedDeviceId = null;
            try {
                JSONObject response = request(BASE + "/api/support-code",
                        new JSONObject().put("device_id", deviceId(app)), 16384);
                code = response.optString("support_code");
                if (response.optBoolean("device_id_generated")) issuedDeviceId = response.optString("device_id");
            } catch (Exception ignored) {
                // The blank code is a convenience; submission works without it.
            }
            boolean refetch;
            synchronized (SupportTickets.class) {
                fetchingBlank = false;
                // A submission that consumed the old blank code while this request
                // was in flight makes the response stale; discard it and refetch.
                boolean stale = startEpoch != blankEpoch;
                if (!stale) {
                    SharedPreferences.Editor editor = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit();
                    if (code != null && code.matches(BLANK_CODE_PATTERN)) editor.putString("blank_code", code);
                    if (issuedDeviceId != null && issuedDeviceId.matches("[A-Za-z0-9_-]{8,80}")) editor.putString("device_id", issuedDeviceId);
                    editor.apply();
                }
                refetch = stale || blankFetchQueued;
                blankFetchQueued = false;
            }
            if (refetch) fetchBlankCode(app, true, null);
            else firePendingBlankCallback();
        }, "support-code").start();
    }

    private static void firePendingBlankCallback() {
        Runnable callback;
        Activity host;
        synchronized (SupportTickets.class) {
            callback = pendingBlankCallback;
            host = pendingBlankHost == null ? null : pendingBlankHost.get();
            pendingBlankCallback = null;
            pendingBlankHost = null;
        }
        if (callback != null && host != null && !host.isFinishing() && !host.isDestroyed()) host.runOnUiThread(callback);
    }

    static void postMessage(Context context, String ticketId, String text, String requestId) throws Exception {
        request(BASE + "/api/tickets/" + ticketId + "/message",
                new JSONObject().put("device_id", deviceId(context)).put("text", text).put("request_id", requestId), 16384);
    }

    static void pickAttachment(Activity activity, java.util.function.Consumer<Uri> callback) {
        attachmentCallback = callback;
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("*/*");
        intent.putExtra(Intent.EXTRA_MIME_TYPES, new String[]{"image/*", "video/*"});
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        try {
            activity.startActivityForResult(intent, PICK_ATTACHMENT);
        } catch (Exception error) {
            attachmentCallback = null;
            callback.accept(null);
        }
    }

    static boolean handleActivityResult(Activity activity, int requestCode, int resultCode, Intent data) {
        if (requestCode != PICK_ATTACHMENT) return false;
        java.util.function.Consumer<Uri> callback = attachmentCallback;
        attachmentCallback = null;
        if (callback == null) return true;
        if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null) return true;
        Uri uri = data.getData();
        try {
            activity.getContentResolver().takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
        } catch (Exception ignored) {
            // Some providers don't offer persistable grants; the URI still works for this session.
        }
        callback.accept(uri);
        return true;
    }

    // Size is probed BEFORE any bytes are read so oversized videos are rejected
    // without being loaded or copied.
    private static SelectedAttachment probeAttachment(Context context, Uri uri) throws Exception {
        String name = "";
        long size = -1;
        try (Cursor cursor = context.getContentResolver().query(uri,
                new String[]{OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE}, null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                name = cursor.getString(0);
                if (!cursor.isNull(1)) size = cursor.getLong(1);
            }
        } catch (Exception ignored) { }
        if (size < 0) {
            try (AssetFileDescriptor descriptor = context.getContentResolver().openAssetFileDescriptor(uri, "r")) {
                if (descriptor != null) size = descriptor.getLength();
            } catch (Exception ignored) { }
        }
        if (size > MAX_ATTACHMENT_BYTES) throw new TooLarge();
        String mime = context.getContentResolver().getType(uri);
        if (mime == null) mime = "";
        if (!(mime.startsWith("image/") || mime.startsWith("video/"))) throw new IllegalStateException("unsupported_attachment");
        if (name == null || name.isEmpty()) name = mime.startsWith("video/") ? "video.mp4" : "image.jpg";
        return new SelectedAttachment(uri, name, mime, size);
    }

    private static void postMessageOrAttachment(Context context, String ticketId, String text,
                                                String requestId, SelectedAttachment attachment) throws Exception {
        if (attachment == null) {
            postMessage(context, ticketId, text, requestId);
            return;
        }
        String boundary = "Boundary-" + UUID.randomUUID();
        byte[] device = multipartField(boundary, "device_id", deviceId(context));
        byte[] message = multipartField(boundary, "text", text);
        byte[] requestField = multipartField(boundary, "request_id", requestId);
        byte[] prefix = ("--" + boundary + "\r\n" +
                "Content-Disposition: form-data; name=\"attachment\"; filename=\"" +
                attachment.name.replaceAll("[^A-Za-z0-9._-]", "_") + "\"\r\n" +
                "Content-Type: " + attachment.mime + "\r\n\r\n").getBytes(StandardCharsets.UTF_8);
        byte[] suffix = ("\r\n--" + boundary + "--\r\n").getBytes(StandardCharsets.UTF_8);
        long overhead = device.length + message.length + requestField.length + prefix.length + suffix.length;

        // When the provider can't report a size, measure through a temp file
        // (aborting past the cap) so the upload can still use a fixed length.
        File temporary = null;
        long size = attachment.size;
        InputStream source = null;
        try {
            if (size < 0) {
                temporary = File.createTempFile("meqr-attachment-", ".upload", context.getCacheDir());
                size = copyAttachment(context, attachment.uri, temporary);
                if (size <= 0 || size > MAX_ATTACHMENT_BYTES) throw new TooLarge();
                source = new FileInputStream(temporary);
            } else {
                source = context.getContentResolver().openInputStream(attachment.uri);
            }
            if (source == null) throw new IllegalStateException("attachment_unreadable");
            HttpURLConnection connection = (HttpURLConnection) new URL(BASE + "/api/tickets/" + ticketId + "/message").openConnection();
            connection.setConnectTimeout(15000);
            connection.setReadTimeout(180000);
            connection.setRequestMethod("POST");
            connection.setDoOutput(true);
            connection.setRequestProperty("Content-Type", "multipart/form-data; boundary=" + boundary);
            connection.setFixedLengthStreamingMode(overhead + size);
            try (OutputStream output = connection.getOutputStream(); InputStream input = source) {
                source = null;
                output.write(device);
                output.write(message);
                output.write(requestField);
                output.write(prefix);
                byte[] buffer = new byte[64 * 1024];
                int count;
                while ((count = input.read(buffer)) != -1) output.write(buffer, 0, count);
                output.write(suffix);
            }
            int status = connection.getResponseCode();
            if (status < 200 || status > 299) throw new IllegalStateException("HTTP " + status);
            connection.disconnect();
        } finally {
            if (source != null) try { source.close(); } catch (Exception ignored) { }
            if (temporary != null && !temporary.delete()) temporary.deleteOnExit();
        }
    }

    private static byte[] multipartField(String boundary, String name, String value) {
        return ("--" + boundary + "\r\nContent-Disposition: form-data; name=\"" + name + "\"\r\n\r\n" + value + "\r\n")
                .getBytes(StandardCharsets.UTF_8);
    }

    private static long copyAttachment(Context context, Uri uri, File destination) throws Exception {
        long total = 0;
        try (InputStream input = context.getContentResolver().openInputStream(uri);
             OutputStream output = new FileOutputStream(destination)) {
            if (input == null) throw new IllegalStateException("attachment_unreadable");
            byte[] buffer = new byte[64 * 1024];
            int count;
            while ((count = input.read(buffer)) != -1) {
                total += count;
                if (total > MAX_ATTACHMENT_BYTES) throw new TooLarge();
                output.write(buffer, 0, count);
            }
        }
        return total;
    }

    static JSONArray fetchTickets(Context context) throws Exception {
        final long startEpoch;
        synchronized (SupportTickets.class) { startEpoch = blankEpoch; }
        JSONObject response = request(BASE + "/api/tickets/by-device/" + deviceId(context), null, 262144);
        String blank = response.optString("blank_support_code");
        if (blank.matches(BLANK_CODE_PATTERN)) {
            synchronized (SupportTickets.class) {
                if (startEpoch == blankEpoch) {
                    context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("blank_code", blank).apply();
                }
            }
        }
        JSONArray tickets = response.optJSONArray("tickets");
        return tickets == null ? new JSONArray() : tickets;
    }

    static String alertText(Context context) {
        String value = alertText;
        if (value == null) {
            value = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("pending_alert", "");
            alertText = value.isEmpty() ? null : value;
        }
        return alertText;
    }

    static void clearAlert() { alertText = null; }

    static void clearAlert(Context context) {
        alertText = null;
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove("pending_alert").apply();
    }

    static void refreshAlerts(Activity activity, I18n i18n, Runnable onChange) {
        long now = System.currentTimeMillis();
        if (now - lastAlertCheck < ALERT_THROTTLE_MS) return;
        lastAlertCheck = now;
        new Thread(() -> {
            JSONArray tickets;
            try { tickets = fetchTickets(activity); } catch (Exception error) { return; }
            String alert = computeAlert(activity, i18n, tickets);
            String previous = alertText;
            alertText = alert;
            if (!Objects.equals(previous, alert) && onChange != null) activity.runOnUiThread(onChange);
        }, "ticket-alerts").start();
    }

    // Progress is driven by the team only: status, needs_info and admin_note.
    // The user's own supplementary messages never raise the banner.
    private static String alertState(JSONObject ticket) {
        return ticket.optString("status") + "|" + ticket.optBoolean("needs_info") + "|" + ticket.optString("admin_note");
    }

    // Snapshots written before the admin-note-only format carried user_messages in
    // a fourth segment; strip it so upgrading users don't get a spurious banner.
    static String normalizeAlertState(String state) {
        if (state == null) return null;
        int first = state.indexOf('|');
        int second = first < 0 ? -1 : state.indexOf('|', first + 1);
        int third = second < 0 ? -1 : state.indexOf('|', second + 1);
        if (third < 0) return state;
        if (state.endsWith("]") || state.endsWith("null")) return state.substring(0, third);
        return state;
    }

    private static String computeAlert(Context context, I18n i18n, JSONArray tickets) {
        try {
            SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
            JSONObject old;
            try { old = new JSONObject(prefs.getString("snapshot", "{}")); }
            catch (Exception invalid) { old = new JSONObject(); }
            JSONObject next = new JSONObject();
            int needsInfo = 0, changed = 0;
            for (int i = 0; i < tickets.length(); i++) {
                JSONObject ticket = tickets.optJSONObject(i);
                if (ticket == null) continue;
                String id = ticket.optString("id");
                if (id.isEmpty()) continue;
                boolean needs = ticket.optBoolean("needs_info");
                String state = alertState(ticket);
                next.put(id, state);
                String prev = normalizeAlertState(old.optString(id, null));
                boolean previouslyNeeded = false;
                if (prev != null) {
                    String[] parts = prev.split("\\|", 3);
                    previouslyNeeded = parts.length > 1 && "true".equals(parts[1]);
                }
                if (needs && !previouslyNeeded) needsInfo++;
                else if (prev != null && !prev.equals(state)) changed++;
            }
            String pending = prefs.getString("pending_alert", "");
            if (needsInfo > 0) pending = i18n.tf("ticketNeedsInfoBanner", needsInfo);
            else if (changed > 0) pending = i18n.tf("ticketUpdatedBanner", changed);
            prefs.edit().putString("snapshot", next.toString()).putString("pending_alert", pending).apply();
            return pending.isEmpty() ? null : pending;
        } catch (Exception ignored) { }
        return null;
    }

    static void show(Activity activity, I18n i18n) {
        clearAlert(activity);
        int padding = Math.round(16 * activity.getResources().getDisplayMetrics().density);
        LinearLayout content = new LinearLayout(activity);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setPadding(padding, padding / 2, padding, padding / 2);

        TextView codeLabel = Ui.text(activity, i18n.t("ticketBlankCode"), Ui.MUTED, 12);
        content.addView(codeLabel);
        LinearLayout codeRow = new LinearLayout(activity);
        codeRow.setOrientation(LinearLayout.HORIZONTAL);
        codeRow.setGravity(Gravity.CENTER_VERTICAL);
        TextView code = Ui.boldText(activity, "", Ui.TEAL_DEEP, 20);
        code.setTypeface(android.graphics.Typeface.MONOSPACE, android.graphics.Typeface.BOLD);
        code.setTextIsSelectable(true);
        code.setPadding(0, padding / 4, 0, 0);
        codeRow.addView(code, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        android.widget.Button copy = Ui.button(activity, i18n.t("copy"));
        codeRow.addView(copy, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        content.addView(codeRow);
        TextView codeHint = Ui.text(activity, i18n.t("ticketBlankCodeHint"), Ui.MUTED, 12);
        codeHint.setPadding(0, padding / 4, 0, padding / 2);
        content.addView(codeHint);

        LinearLayout rows = new LinearLayout(activity);
        rows.setOrientation(LinearLayout.VERTICAL);
        content.addView(rows);

        ScrollView scroll = new ScrollView(activity);
        scroll.addView(content);
        AlertDialog dialog = new AlertDialog.Builder(Ui.dialogContext(activity))
                .setTitle(i18n.t("myTickets"))
                .setView(scroll)
                .setPositiveButton(i18n.t("done"), null)
                .setNeutralButton(i18n.t("ticketRefresh"), null)
                .create();
        final boolean[] dismissed = {false};
        dialog.setOnDismissListener(d -> dismissed[0] = true);

        Runnable updateCode = () -> {
            if (activity.isFinishing() || activity.isDestroyed() || dismissed[0]) return;
            String value = cachedBlankCode(activity);
            code.setText(value.isEmpty() ? i18n.t("ticketsLoading") : value);
            copy.setEnabled(!value.isEmpty());
        };
        copy.setOnClickListener(v -> {
            String value = cachedBlankCode(activity);
            if (value.isEmpty()) return;
            android.content.ClipboardManager clipboard =
                    (android.content.ClipboardManager) activity.getSystemService(Context.CLIPBOARD_SERVICE);
            if (clipboard != null) {
                clipboard.setPrimaryClip(android.content.ClipData.newPlainText(i18n.t("supportCode"), value));
            }
            Toast.makeText(activity, i18n.t("copied"), Toast.LENGTH_SHORT).show();
        });

        Runnable refresh = new Runnable() {
            @Override public void run() {
                if (activity.isFinishing() || activity.isDestroyed() || dismissed[0]) return;
                rows.removeAllViews();
                TextView loading = Ui.text(activity, i18n.t("ticketsLoading"), Ui.MUTED, 14);
                loading.setGravity(Gravity.CENTER);
                loading.setPadding(0, padding, 0, padding);
                rows.addView(loading);
                new Thread(() -> {
                    JSONArray tickets = null;
                    try { tickets = fetchTickets(activity); } catch (Exception ignored) { }
                    JSONArray result = tickets;
                    activity.runOnUiThread(() -> {
                        if (activity.isFinishing() || activity.isDestroyed() || dismissed[0] || !dialog.isShowing()) return;
                        rows.removeAllViews();
                        updateCode.run();
                        if (result == null) {
                            TextView failure = Ui.text(activity, i18n.t("ticketsLoadFailed"), Ui.TEAL, 14);
                            failure.setGravity(Gravity.CENTER);
                            failure.setPadding(0, padding, 0, padding);
                            failure.setOnClickListener(v -> run());
                            rows.addView(failure);
                            return;
                        }
                        if (result.length() == 0) {
                            TextView empty = Ui.text(activity, i18n.t("ticketsEmpty"), Ui.MUTED, 14);
                            empty.setGravity(Gravity.CENTER);
                            empty.setPadding(0, padding, 0, padding);
                            rows.addView(empty);
                            return;
                        }
                        for (int i = 0; i < result.length(); i++) {
                            JSONObject ticket = result.optJSONObject(i);
                            if (ticket == null) continue;
                            rows.addView(ticketRow(activity, i18n, ticket));
                        }
                    });
                }, "tickets-refresh").start();
            }
        };

        dialog.show();
        android.widget.Button refreshButton = dialog.getButton(AlertDialog.BUTTON_NEUTRAL);
        if (refreshButton != null) refreshButton.setOnClickListener(v -> refresh.run());
        updateCode.run();
        refreshBlankCode(activity, updateCode);
        refresh.run();
    }

    private static View ticketRow(Activity activity, I18n i18n, JSONObject ticket) {
        int padding = Math.round(12 * activity.getResources().getDisplayMetrics().density);
        LinearLayout row = new LinearLayout(activity);
        row.setOrientation(LinearLayout.VERTICAL);
        row.setPadding(padding, padding, padding, padding);
        row.setBackground(Ui.rounded(Ui.SURFACE_2, padding, Ui.BORDER, Math.max(1, padding / 12)));

        LinearLayout heading = new LinearLayout(activity);
        heading.setOrientation(LinearLayout.HORIZONTAL);
        heading.setGravity(Gravity.CENTER_VERTICAL);
        String title = ticket.optString("title");
        TextView name = Ui.boldText(activity, title.isEmpty() ? ticket.optString("id") : title, Ui.TEXT, 15);
        name.setMaxLines(2);
        name.setEllipsize(android.text.TextUtils.TruncateAt.END);
        heading.addView(name, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        if (ticket.optBoolean("needs_info")) {
            TextView badge = Ui.boldText(activity, i18n.t("ticketNeedsInfo"), Color.WHITE, 11);
            badge.setBackground(Ui.rounded(Color.rgb(179, 38, 30), padding / 2));
            badge.setPadding(padding / 2, padding / 6, padding / 2, padding / 6);
            heading.addView(badge);
        }
        row.addView(heading);

        String code = ticket.optString("support_code");
        TextView meta = Ui.text(activity, statusText(i18n, ticket.optString("status"))
                + (code.isEmpty() ? "" : " · " + code), Ui.MUTED, 12);
        meta.setPadding(0, padding / 4, 0, 0);
        row.addView(meta);
        TextView time = Ui.text(activity, formatTime(ticket.optString("created_at")), Ui.DIM, 11);
        time.setPadding(0, padding / 6, 0, 0);
        row.addView(time);

        row.setOnClickListener(v -> showDetail(activity, i18n, ticket));
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.setMargins(0, 0, 0, padding / 2);
        row.setLayoutParams(params);
        return row;
    }

    private static String draftTextKey(String ticketId) { return "msg_text_" + ticketId; }
    private static String draftFingerprintKey(String ticketId) { return "msg_fp_" + ticketId; }
    private static String draftRequestKey(String ticketId) { return "msg_req_" + ticketId; }
    private static String draftAttachmentKey(String ticketId) { return "msg_att_" + ticketId; }

    // Same unsent draft → same request_id, so a retry after a lost receipt stays
    // idempotent on the server. Any content change mints a fresh one.
    static String draftFingerprint(String text, String name, long size, String mime) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest((text + "\n" + name + "|" + size + "|" + mime).getBytes(StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder();
            for (byte b : hash) hex.append(String.format("%02x", b));
            return hex.toString();
        } catch (Exception error) {
            return text + "\n" + name + "|" + size + "|" + mime;
        }
    }

    private static void showDetail(Activity activity, I18n i18n, JSONObject ticket) {
        int padding = Math.round(18 * activity.getResources().getDisplayMetrics().density);
        String ticketId = ticket.optString("id");
        SharedPreferences prefs = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        JSONObject[] current = {ticket};

        LinearLayout page = new LinearLayout(activity);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setPadding(padding, padding / 2, padding, padding / 2);
        LinearLayout detail = new LinearLayout(activity);
        detail.setOrientation(LinearLayout.VERTICAL);
        page.addView(detail);

        EditText followUp = new EditText(activity);
        followUp.setHint(i18n.t("ticketAddInfoPlaceholder"));
        followUp.setTextColor(Ui.TEXT);
        followUp.setHintTextColor(Ui.DIM);
        followUp.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE);
        followUp.setFilters(new InputFilter[]{new InputFilter.LengthFilter(2000)});
        followUp.setMinLines(3);
        followUp.setText(prefs.getString(draftTextKey(ticketId), ""));
        page.addView(followUp);

        SelectedAttachment[] selected = {null};
        LinearLayout attachmentRow = new LinearLayout(activity);
        attachmentRow.setOrientation(LinearLayout.HORIZONTAL);
        attachmentRow.setGravity(Gravity.CENTER_VERTICAL);
        attachmentRow.setVisibility(View.GONE);
        TextView attachmentLabel = Ui.text(activity, "", Ui.TEXT, 13);
        attachmentRow.addView(attachmentLabel, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        android.widget.Button removeAttachment = Ui.button(activity, "×");
        removeAttachment.setContentDescription(i18n.t("removeImage"));
        attachmentRow.addView(removeAttachment, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        page.addView(attachmentRow);
        removeAttachment.setOnClickListener(v -> {
            selected[0] = null;
            attachmentRow.setVisibility(View.GONE);
        });

        String draftAttachment = prefs.getString(draftAttachmentKey(ticketId), "");
        if (!draftAttachment.isEmpty()) {
            try {
                JSONObject saved = new JSONObject(draftAttachment);
                Uri uri = Uri.parse(saved.getString("uri"));
                SelectedAttachment restored = probeAttachment(activity, uri);
                if (restored.name.equals(saved.optString("name")) && restored.size == saved.optLong("size")) {
                    selected[0] = restored;
                    attachmentLabel.setText(attachmentLine(restored.name, restored.mime, restored.size));
                    attachmentRow.setVisibility(View.VISIBLE);
                }
            } catch (Exception ignored) {
                // The picked file is gone or no longer readable; drop only the attachment.
            }
        }

        LinearLayout actions = new LinearLayout(activity);
        actions.setOrientation(LinearLayout.HORIZONTAL);
        android.widget.Button attach = Ui.button(activity, i18n.t("ticketAddFile"));
        actions.addView(attach, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        android.widget.Button send = Ui.button(activity, i18n.t("ticketSend"));
        LinearLayout.LayoutParams sendParams = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1);
        sendParams.setMargins(padding / 2, 0, 0, 0);
        actions.addView(send, sendParams);
        page.addView(actions);

        attach.setOnClickListener(v -> pickAttachment(activity, uri -> {
            if (activity.isFinishing() || activity.isDestroyed()) return;
            if (uri == null) {
                Toast.makeText(activity, i18n.t("ticketAttachmentFailed"), Toast.LENGTH_LONG).show();
                return;
            }
            try {
                SelectedAttachment probed = probeAttachment(activity, uri);
                selected[0] = probed;
                attachmentLabel.setText(attachmentLine(probed.name, probed.mime, probed.size));
                attachmentRow.setVisibility(View.VISIBLE);
            } catch (TooLarge tooLarge) {
                Toast.makeText(activity, i18n.t("ticketAttachmentTooLarge"), Toast.LENGTH_LONG).show();
            } catch (Exception error) {
                Toast.makeText(activity, i18n.t("ticketAttachmentFailed"), Toast.LENGTH_LONG).show();
            }
        }));

        Runnable rebuild = () -> renderDetail(detail, activity, i18n, current[0], padding);
        rebuild.run();

        ScrollView scroll = new ScrollView(activity);
        scroll.addView(page);
        AlertDialog dialog = new AlertDialog.Builder(Ui.dialogContext(activity))
                .setTitle(i18n.t("myTickets"))
                .setView(scroll)
                .setPositiveButton(i18n.t("done"), null)
                .create();

        send.setOnClickListener(v -> {
            String text = followUp.getText().toString().trim();
            SelectedAttachment attachment = selected[0];
            if (text.isEmpty() && attachment == null) return;
            String fingerprint = draftFingerprint(text,
                    attachment == null ? "" : attachment.name,
                    attachment == null ? -1 : attachment.size,
                    attachment == null ? "" : attachment.mime);
            String requestId = fingerprint.equals(prefs.getString(draftFingerprintKey(ticketId), ""))
                    ? prefs.getString(draftRequestKey(ticketId), "")
                    : "";
            if (requestId.isEmpty()) requestId = UUID.randomUUID().toString();
            SharedPreferences.Editor draft = prefs.edit()
                    .putString(draftTextKey(ticketId), followUp.getText().toString())
                    .putString(draftFingerprintKey(ticketId), fingerprint)
                    .putString(draftRequestKey(ticketId), requestId);
            if (attachment != null) {
                try {
                    draft.putString(draftAttachmentKey(ticketId), new JSONObject()
                            .put("uri", attachment.uri.toString())
                            .put("name", attachment.name)
                            .put("mime", attachment.mime)
                            .put("size", attachment.size).toString());
                } catch (Exception ignored) { }
            } else {
                draft.remove(draftAttachmentKey(ticketId));
            }
            draft.apply();
            send.setEnabled(false);
            attach.setEnabled(false);
            String finalRequestId = requestId;
            new Thread(() -> {
                String failure = null;
                try {
                    postMessageOrAttachment(activity, ticketId, text, finalRequestId, attachment);
                    JSONObject fresh = null;
                    try {
                        JSONArray tickets = fetchTickets(activity);
                        for (int i = 0; i < tickets.length(); i++) {
                            JSONObject candidate = tickets.optJSONObject(i);
                            if (candidate != null && ticketId.equals(candidate.optString("id"))) { fresh = candidate; break; }
                        }
                    } catch (Exception ignored) { }
                    if (fresh != null) current[0] = fresh;
                    else optimisticAppend(current[0], text, attachment);
                    prefs.edit().remove(draftTextKey(ticketId)).remove(draftFingerprintKey(ticketId))
                            .remove(draftRequestKey(ticketId)).remove(draftAttachmentKey(ticketId)).apply();
                } catch (Exception error) {
                    failure = error.getMessage();
                }
                String result = failure;
                activity.runOnUiThread(() -> {
                    if (activity.isFinishing() || activity.isDestroyed() || !dialog.isShowing()) return;
                    send.setEnabled(true);
                    attach.setEnabled(true);
                    if (result != null) {
                        Toast.makeText(activity, i18n.t("ticketSendFailed"), Toast.LENGTH_LONG).show();
                        return;
                    }
                    followUp.setText("");
                    selected[0] = null;
                    attachmentRow.setVisibility(View.GONE);
                    rebuild.run();
                    Toast.makeText(activity, i18n.t("ticketSent"), Toast.LENGTH_SHORT).show();
                });
            }, "ticket-message").start();
        });

        dialog.show();
    }

    private static void optimisticAppend(JSONObject ticket, String text, SelectedAttachment attachment) {
        try {
            JSONArray messages = ticket.optJSONArray("user_messages");
            if (messages == null) {
                messages = new JSONArray();
                ticket.put("user_messages", messages);
            }
            JSONObject message = new JSONObject()
                    .put("text", text)
                    .put("at", java.time.OffsetDateTime.now(java.time.ZoneOffset.UTC)
                            .format(java.time.format.DateTimeFormatter.ISO_OFFSET_DATE_TIME));
            if (attachment != null) {
                message.put("attachments", new JSONArray().put(new JSONObject()
                        .put("name", attachment.name).put("mime_type", attachment.mime).put("byte_size", attachment.size)));
            }
            messages.put(message);
        } catch (Exception ignored) { }
    }

    private static void renderDetail(LinearLayout content, Activity activity, I18n i18n, JSONObject ticket, int padding) {
        content.removeAllViews();
        if (ticket.optBoolean("needs_info")) {
            TextView warning = Ui.boldText(activity, i18n.t("ticketNeedsInfo"), Color.WHITE, 13);
            warning.setBackground(Ui.rounded(Color.rgb(179, 38, 30), padding / 2));
            warning.setPadding(padding / 2, padding / 3, padding / 2, padding / 3);
            content.addView(warning);
            TextView hint = Ui.text(activity, i18n.t("ticketNeedsInfoHint"), Ui.MUTED, 12);
            hint.setPadding(0, padding / 4, 0, padding / 2);
            content.addView(hint);
        }

        String title = ticket.optString("title");
        content.addView(Ui.boldText(activity, title.isEmpty() ? i18n.t("myTickets") : title, Ui.TEXT, 18));
        TextView status = Ui.text(activity, statusText(i18n, ticket.optString("status")), Ui.TEAL_DEEP, 13);
        status.setPadding(0, padding / 4, 0, padding / 2);
        content.addView(status);

        addMetaLine(content, activity, i18n.tf("ticketIdLabel", ticket.optString("id")));
        String code = ticket.optString("support_code");
        if (!code.isEmpty()) addMetaLine(content, activity, i18n.tf("supportCodeIs", code));
        String created = ticket.optString("created_at");
        if (!created.isEmpty()) addMetaLine(content, activity, i18n.tf("ticketSubmittedAt", formatTime(created)));
        String updated = ticket.optString("updated_at");
        if (!updated.isEmpty()) addMetaLine(content, activity, i18n.tf("ticketUpdatedAt", formatTime(updated)));

        TextView replyLabel = Ui.boldText(activity, i18n.t("ticketReply"), Ui.TEXT, 14);
        replyLabel.setPadding(0, padding / 2, 0, padding / 6);
        content.addView(replyLabel);
        String note = ticket.optString("admin_note");
        TextView reply = Ui.text(activity, note.trim().isEmpty() ? i18n.t("ticketNoReply") : note, Ui.TEXT, 14);
        reply.setTextIsSelectable(true);
        content.addView(reply);

        JSONArray messages = ticket.optJSONArray("user_messages");
        if (messages != null && messages.length() > 0) {
            TextView historyLabel = Ui.boldText(activity, i18n.t("ticketMyMessages"), Ui.TEXT, 14);
            historyLabel.setPadding(0, padding / 2, 0, padding / 6);
            content.addView(historyLabel);
            for (int index = 0; index < messages.length(); index++) {
                JSONObject message = messages.optJSONObject(index);
                if (message == null) continue;
                String text = message.optString("text");
                if (!text.isEmpty()) {
                    TextView history = Ui.text(activity, text, Ui.TEXT, 14);
                    history.setTextIsSelectable(true);
                    content.addView(history);
                }
                for (String line : attachmentLines(message)) {
                    content.addView(Ui.text(activity, line, Ui.MUTED, 13));
                }
                String when = formatTime(message.optString("at"));
                if (!when.isEmpty()) {
                    TextView stamp = Ui.text(activity, when, Ui.DIM, 11);
                    stamp.setPadding(0, padding / 8, 0, padding / 4);
                    content.addView(stamp);
                }
            }
        }
    }

    // The server returns both an attachments array (mime_type/byte_size) and a
    // single attachment field (mime/size); accept either.
    static List<String> attachmentLines(JSONObject message) {
        List<String> lines = new ArrayList<>();
        JSONArray attachments = message.optJSONArray("attachments");
        if (attachments != null) {
            for (int i = 0; i < attachments.length(); i++) {
                JSONObject attachment = attachments.optJSONObject(i);
                if (attachment != null) lines.add(describeAttachment(attachment));
            }
        }
        if (lines.isEmpty()) {
            JSONObject single = message.optJSONObject("attachment");
            if (single != null) lines.add(describeAttachment(single));
        }
        return lines;
    }

    private static String describeAttachment(JSONObject attachment) {
        String mime = attachment.optString("mime_type");
        if (mime.isEmpty()) mime = attachment.optString("mime");
        long size = attachment.optLong("byte_size", -1);
        if (size < 0) size = attachment.optLong("size", -1);
        return attachmentLine(attachment.optString("name"), mime, size);
    }

    private static String attachmentLine(String name, String mime, long size) {
        String icon = mime != null && mime.startsWith("video/") ? "🎬 " : "🖼 ";
        return icon + (name == null || name.isEmpty() ? "attachment" : name) + (size >= 0 ? " · " + formatSize(size) : "");
    }

    static String formatSize(long bytes) {
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return String.format(java.util.Locale.US, "%.1f KB", bytes / 1024f);
        return String.format(java.util.Locale.US, "%.1f MB", bytes / (1024f * 1024f));
    }

    private static void addMetaLine(LinearLayout content, Activity activity, String text) {
        TextView line = Ui.text(activity, text, Ui.MUTED, 12);
        line.setTextIsSelectable(true);
        line.setPadding(0, Math.round(3 * activity.getResources().getDisplayMetrics().density), 0, 0);
        content.addView(line);
    }

    private static String statusText(I18n i18n, String status) {
        switch (status) {
            case "open": return i18n.t("ticketStatusOpen");
            case "processing": return i18n.t("ticketStatusProcessing");
            case "resolved": return i18n.t("ticketStatusResolved");
            case "closed": return i18n.t("ticketStatusClosed");
            default: return status;
        }
    }

    private static String formatTime(String iso) {
        try {
            java.time.OffsetDateTime parsed = java.time.OffsetDateTime.parse(iso);
            return java.time.format.DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm")
                    .format(parsed.atZoneSameInstant(java.time.ZoneId.systemDefault()));
        } catch (Exception error) {
            return "";
        }
    }

    private static JSONObject request(String url, JSONObject payload, int limit) throws Exception {
        HttpURLConnection connection = (HttpURLConnection) new URL(url).openConnection();
        connection.setConnectTimeout(15000);
        connection.setReadTimeout(20000);
        connection.setInstanceFollowRedirects(false);
        connection.setUseCaches(false);
        try {
            if (payload != null) {
                connection.setRequestMethod("POST");
                connection.setDoOutput(true);
                connection.setRequestProperty("Content-Type", "application/json");
                byte[] body = payload.toString().getBytes(StandardCharsets.UTF_8);
                connection.setFixedLengthStreamingMode(body.length);
                try (java.io.OutputStream output = connection.getOutputStream()) { output.write(body); }
            }
            int status = connection.getResponseCode();
            if (status < 200 || status > 299) throw new IllegalStateException("HTTP " + status);
            try (InputStream input = connection.getInputStream(); ByteArrayOutputStream output = new ByteArrayOutputStream()) {
                byte[] buffer = new byte[1024];
                int count;
                while ((count = input.read(buffer)) != -1) {
                    if (output.size() + count > limit) throw new IllegalStateException("Response too large");
                    output.write(buffer, 0, count);
                }
                return new JSONObject(output.toString("UTF-8"));
            }
        } finally { connection.disconnect(); }
    }
}
