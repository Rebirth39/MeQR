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

    ProfileStore(Context context) {
        this.context = context.getApplicationContext();
        this.dataFile = new File(context.getFilesDir(), "profiles.json");
        this.imageDir = new File(context.getFilesDir(), "images");
        //noinspection ResultOfMethodCallIgnored
        imageDir.mkdirs();
    }

    List<MeQrProfile> load() {
        List<MeQrProfile> profiles = new ArrayList<>();
        if (!dataFile.exists()) {
            return profiles;
        }
        try {
            String json = new String(Files.readAllBytes(dataFile.toPath()), StandardCharsets.UTF_8);
            JSONArray array = new JSONArray(json);
            for (int i = 0; i < array.length(); i++) {
                profiles.add(MeQrProfile.fromJson(array.getJSONObject(i)));
            }
        } catch (Exception ignored) {
            return profiles;
        }
        Collections.sort(profiles, Comparator.comparingInt((MeQrProfile p) -> p.sortOrder).thenComparingLong(p -> p.createdAt));
        return profiles;
    }

    void save(List<MeQrProfile> profiles) throws IOException {
        normalizeSortOrder(profiles);
        JSONArray array = new JSONArray();
        try {
            for (MeQrProfile profile : profiles) {
                array.put(profile.toJson());
            }
        } catch (Exception exception) {
            throw new IOException(exception);
        }
        try (FileOutputStream output = new FileOutputStream(dataFile, false)) {
            output.write(array.toString(2).getBytes(StandardCharsets.UTF_8));
        } catch (Exception exception) {
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
