package com.lucasli.meqr;

import android.content.Context;
import android.net.Uri;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import java.util.List;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import java.util.zip.ZipOutputStream;

/**
 * Exports profiles.json plus all card images as a single zip, and restores
 * from such a zip. The current data file is preserved as profiles.json.pre-restore
 * before an import overwrites it.
 */
final class BackupManager {
    private static final int MAX_BACKUP_ENTRIES = 128;
    private static final long MAX_BACKUP_BYTES = 100L * 1024L * 1024L;
    private final Context context;

    BackupManager(Context context) {
        this.context = context.getApplicationContext();
    }

    void exportBackup(Uri target) throws IOException {
        File filesDir = context.getFilesDir();
        File dataFile = new File(filesDir, "profiles.json");
        byte[] data = dataFile.exists() ? new android.util.AtomicFile(dataFile).readFully() : "[]".getBytes(StandardCharsets.UTF_8);
        List<MeQrProfile> profiles = ProfileStore.decode(new String(data, StandardCharsets.UTF_8));
        Map<String, File> images = new LinkedHashMap<>();
        long totalBytes = data.length;
        for (MeQrProfile profile : profiles) {
            for (String path : new String[]{profile.avatarPath, profile.backgroundPath, profile.bannerPath}) {
                if (path == null || path.isEmpty()) continue;
                File image = new File(path);
                String name = image.getName();
                if (!image.isFile()) throw new IOException("A card image is missing.");
                if (images.containsKey(name)) {
                    if (!images.get(name).getCanonicalPath().equals(image.getCanonicalPath())) throw new IOException("Conflicting image names.");
                    continue;
                }
                images.put(name, image);
                totalBytes += image.length();
            }
        }
        if (images.size() + 1 > MAX_BACKUP_ENTRIES || totalBytes > MAX_BACKUP_BYTES) {
            throw new IOException("Backup exceeds the supported restore limits.");
        }
        OutputStream output = context.getContentResolver().openOutputStream(target);
        if (output == null) {
            throw new IOException("Could not open backup target.");
        }
        try (ZipOutputStream zip = new ZipOutputStream(output)) {
            zip.putNextEntry(new ZipEntry("profiles.json"));
            zip.write(data);
            zip.closeEntry();
            for (Map.Entry<String, File> image : images.entrySet()) addFile(zip, "images/" + image.getKey(), image.getValue());
        }
    }

    List<MeQrProfile> importBackup(Uri source) throws IOException {
        File filesDir = context.getFilesDir();
        File tempDir = new File(filesDir, "restore_" + UUID.randomUUID());
        if (!tempDir.mkdirs() && !tempDir.isDirectory()) {
            throw new IOException("Could not create restore directory.");
        }

        List<File> addedImages = new ArrayList<>();
        boolean committed = false;
        try {
            List<MeQrProfile> restored = restoreStaged(source, tempDir, addedImages);
            committed = true;
            return restored;
        } finally {
            if (!committed) for (File image : addedImages) image.delete();
            deleteRecursively(tempDir);
        }
    }

    private List<MeQrProfile> restoreStaged(Uri source, File tempDir, List<File> addedImages) throws IOException {
        File filesDir = context.getFilesDir();
        File imageDir = new File(filesDir, "images");
        File dataFile = new File(filesDir, "profiles.json");
        InputStream input = context.getContentResolver().openInputStream(source);
        if (input == null) {
            throw new IOException("Could not open backup file.");
        }
        try (ZipInputStream zip = new ZipInputStream(input)) {
            ZipEntry entry;
            byte[] buffer = new byte[16 * 1024];
            int entryCount = 0;
            long totalBytes = 0;
            while ((entry = zip.getNextEntry()) != null) {
                if (++entryCount > MAX_BACKUP_ENTRIES) {
                    throw new IOException("Backup contains too many files.");
                }
                File out = safeRestoreFile(tempDir, entry.getName());
                if (entry.isDirectory()) {
                    if (!out.mkdirs() && !out.isDirectory()) {
                        throw new IOException("Could not create restore entry.");
                    }
                    continue;
                }
                File parent = out.getParentFile();
                if (parent != null && !parent.exists() && !parent.mkdirs()) {
                    throw new IOException("Could not create restore entry directory.");
                }
                try (FileOutputStream fileOutput = new FileOutputStream(out)) {
                    int read;
                    while ((read = zip.read(buffer)) != -1) {
                        totalBytes += read;
                        if (totalBytes > MAX_BACKUP_BYTES) {
                            throw new IOException("Backup is too large.");
                        }
                        fileOutput.write(buffer, 0, read);
                    }
                }
            }
        }

        File restoredData = new File(tempDir, "profiles.json");
        if (!restoredData.exists()) {
            deleteRecursively(tempDir);
            throw new IOException("Backup file is missing profiles.json.");
        }
        List<MeQrProfile> restored = ProfileStore.decode(new String(Files.readAllBytes(restoredData.toPath()), StandardCharsets.UTF_8));
        Map<String, File> restoredImages = new LinkedHashMap<>();
        for (MeQrProfile profile : restored) {
            for (String path : new String[]{profile.avatarPath, profile.backgroundPath, profile.bannerPath}) {
                if (path == null || path.isEmpty()) continue;
                String name = new File(path).getName();
                File image = safeRestoreFile(tempDir, "images/" + name);
                android.graphics.BitmapFactory.Options bounds = new android.graphics.BitmapFactory.Options();
                bounds.inJustDecodeBounds = true;
                android.graphics.BitmapFactory.decodeFile(image.getAbsolutePath(), bounds);
                if (!image.isFile() || bounds.outWidth <= 0 || bounds.outHeight <= 0) throw new IOException("Backup contains a missing or invalid image.");
                restoredImages.put(name, image);
            }
        }

        if (dataFile.exists()) {
            File previous = new File(filesDir, "profiles.json.pre-restore");
            Files.copy(dataFile.toPath(), previous.toPath(), StandardCopyOption.REPLACE_EXISTING);
        }

        if (!imageDir.mkdirs() && !imageDir.isDirectory()) {
            throw new IOException("Could not create image directory.");
        }
        Map<String, String> restoredPaths = new LinkedHashMap<>();
        String prefix = "restore_" + UUID.randomUUID() + "_";
        for (Map.Entry<String, File> image : restoredImages.entrySet()) {
            File destination = new File(imageDir, prefix + addedImages.size());
            addedImages.add(destination);
            Files.copy(image.getValue().toPath(), destination.toPath());
            restoredPaths.put(image.getKey(), destination.getAbsolutePath());
        }
        for (MeQrProfile profile : restored) {
            profile.avatarPath = restoredPath(profile.avatarPath, restoredPaths);
            profile.backgroundPath = restoredPath(profile.backgroundPath, restoredPaths);
            profile.bannerPath = restoredPath(profile.bannerPath, restoredPaths);
        }
        new ProfileStore(context).save(restored);
        return restored;
    }

    private static String restoredPath(String original, Map<String, String> paths) {
        return original == null || original.isEmpty() ? "" : paths.get(new File(original).getName());
    }

    void preserveBeforeRevocation() throws IOException {
        File data = new File(context.getFilesDir(), "profiles.json");
        if (data.exists()) Files.copy(data.toPath(), new File(context.getFilesDir(), "profiles.json.pre-revoke-" + System.currentTimeMillis()).toPath());
    }

    private static void addFile(ZipOutputStream zip, String name, File file) throws IOException {
        zip.putNextEntry(new ZipEntry(name));
        try (InputStream input = Files.newInputStream(file.toPath())) {
            byte[] buffer = new byte[16 * 1024];
            int read;
            while ((read = input.read(buffer)) != -1) {
                zip.write(buffer, 0, read);
            }
        }
        zip.closeEntry();
    }

    private static File safeRestoreFile(File directory, String entryName) throws IOException {
        File output = new File(directory, entryName);
        String directoryPath = directory.getCanonicalPath() + File.separator;
        String outputPath = output.getCanonicalPath();
        if (!outputPath.startsWith(directoryPath)) {
            throw new IOException("Backup contains an invalid path.");
        }
        return output;
    }

    private static void deleteRecursively(File file) {
        if (file == null || !file.exists()) {
            return;
        }
        File[] children = file.listFiles();
        if (children != null) {
            for (File child : children) {
                deleteRecursively(child);
            }
        }
        //noinspection ResultOfMethodCallIgnored
        file.delete();
    }
}
