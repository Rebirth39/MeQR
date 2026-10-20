package com.lucasli.meqr;

import android.content.Context;
import android.graphics.Bitmap;
import android.net.Uri;

import org.json.JSONArray;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;

final class ProfileStore {
    private final Context context;
    private final File dataFile;
    private final File imageDir;
    private boolean loadError;

    ProfileStore(Context context) {
        this.context = context.getApplicationContext();
        this.dataFile = new File(context.getFilesDir(), "profiles.json");
        this.imageDir = new File(context.getFilesDir(), "images");
        //noinspection ResultOfMethodCallIgnored
        imageDir.mkdirs();
    }

    boolean hadLoadError() {
        return loadError;
    }

    synchronized List<MeQrProfile> load() {
        loadError = false;
        List<MeQrProfile> profiles = new ArrayList<>();
        if (!dataFile.exists() && !new File(dataFile + ".bak").exists()) {
            return profiles;
        }
        try {
            String json = new String(new android.util.AtomicFile(dataFile).readFully(), StandardCharsets.UTF_8);
            I18n i18n = new I18n(context);
            String language = i18n.resolvedLanguage();
            for (MeQrProfile profile : decode(json)) {
                profile.reconcileTags(language);
                profiles.add(profile);
            }
        } catch (Exception ignored) {
            loadError = true;
            return new ArrayList<>();
        }
        Collections.sort(profiles, Comparator.comparingInt((MeQrProfile p) -> p.sortOrder).thenComparingLong(p -> p.createdAt));
        return profiles;
    }

    static List<MeQrProfile> decode(String json) throws IOException {
        List<MeQrProfile> profiles = new ArrayList<>();
        try {
            JSONArray array = new JSONArray(json);
            java.util.Set<String> ids = new java.util.HashSet<>();
            for (int index = 0; index < array.length(); index++) {
                MeQrProfile profile = MeQrProfile.fromJson(array.getJSONObject(index));
                if (profile.id.isEmpty() || !ids.add(profile.id)) throw new IOException("Invalid or duplicate card ID.");
                profiles.add(profile);
            }
        } catch (Exception error) {
            throw new IOException("Invalid profile data.", error);
        }
        return profiles;
    }

    synchronized void save(List<MeQrProfile> profiles) throws IOException {
        if (loadError) {
            throw new IOException("Refusing to overwrite profile data after a load failure.");
        }
        normalizeSortOrder(profiles);
        if (profiles.isEmpty() && dataFile.exists() && dataFile.length() > 2) {
            File backup = new File(context.getFilesDir(), "profiles.json.pre-empty-" + System.currentTimeMillis() + ".json");
            try {
                Files.copy(dataFile.toPath(), backup.toPath(), java.nio.file.StandardCopyOption.REPLACE_EXISTING);
            } catch (IOException ignored) {
            }
        }
        JSONArray array = new JSONArray();
        try {
            for (MeQrProfile profile : profiles) {
                array.put(profile.toJson());
            }
        } catch (Exception exception) {
            throw new IOException(exception);
        }
        android.util.AtomicFile atomic = new android.util.AtomicFile(dataFile);
        FileOutputStream output = null;
        try {
            byte[] bytes = array.toString(2).getBytes(StandardCharsets.UTF_8);
            output = atomic.startWrite();
            output.write(bytes);
            atomic.finishWrite(output);
        } catch (Exception exception) {
            if (output != null) atomic.failWrite(output);
            throw new IOException(exception);
        }
    }

    String copyImage(Uri uri, String prefix) throws IOException {
        String fileName = prefix + "_" + System.currentTimeMillis() + ".jpg";
        File target = new File(imageDir, fileName);
        try (InputStream input = context.getContentResolver().openInputStream(uri);
             FileOutputStream output = new FileOutputStream(target)) {
            if (input == null) {
                throw new IOException("Could not open image input stream.");
            }
            byte[] buffer = new byte[16 * 1024];
            int read;
            while ((read = input.read(buffer)) != -1) {
                output.write(buffer, 0, read);
            }
        }
        return target.getAbsolutePath();
    }

    String saveBitmap(Bitmap bitmap, String prefix) throws IOException {
        String fileName = prefix + "_" + System.currentTimeMillis() + ".png";
        File target = new File(imageDir, fileName);
        try (FileOutputStream output = new FileOutputStream(target)) {
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, output);
        }
        return target.getAbsolutePath();
    }

    void normalizeSortOrder(List<MeQrProfile> profiles) {
        for (int i = 0; i < profiles.size(); i++) {
            profiles.get(i).sortOrder = i;
        }
    }
}
