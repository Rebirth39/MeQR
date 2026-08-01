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
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
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
    private final Context context;

    BackupManager(Context context) {
        this.context = context.getApplicationContext();
    }

    void exportBackup(Uri target) throws IOException {
        File filesDir = context.getFilesDir();
        File dataFile = new File(filesDir, "profiles.json");
        File imageDir = new File(filesDir, "images");
        OutputStream output = context.getContentResolver().openOutputStream(target);
        if (output == null) {
            throw new IOException("Could not open backup target.");
        }
        try (ZipOutputStream zip = new ZipOutputStream(output)) {
            if (dataFile.exists()) {
                addFile(zip, "profiles.json", dataFile);
            }
            File[] images = imageDir.listFiles();
            if (images != null) {
                Arrays.sort(images, Comparator.comparing(File::getName));
                for (File image : images) {
                    if (image.isFile()) {
                        addFile(zip, "images/" + image.getName(), image);
                    }
                }
            }
        }
    }

    List<MeQrProfile> importBackup(Uri source) throws IOException {
        File filesDir = context.getFilesDir();
        File imageDir = new File(filesDir, "images");
        File dataFile = new File(filesDir, "profiles.json");
        File tempDir = new File(filesDir, "restore_tmp");
        deleteRecursively(tempDir);
        if (!tempDir.mkdirs() && !tempDir.isDirectory()) {
            throw new IOException("Could not create restore directory.");
        }

        InputStream input = context.getContentResolver().openInputStream(source);
        if (input == null) {
            throw new IOException("Could not open backup file.");
        }
        try (ZipInputStream zip = new ZipInputStream(input)) {
            ZipEntry entry;
            byte[] buffer = new byte[16 * 1024];
            while ((entry = zip.getNextEntry()) != null) {
                File out = new File(tempDir, entry.getName());
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

        if (dataFile.exists()) {
            File previous = new File(filesDir, "profiles.json.pre-restore");
            Files.copy(dataFile.toPath(), previous.toPath(), StandardCopyOption.REPLACE_EXISTING);
        }

        deleteRecursively(imageDir);
        if (!imageDir.mkdirs() && !imageDir.isDirectory()) {
            throw new IOException("Could not create image directory.");
        }
        File restoredImages = new File(tempDir, "images");
        if (restoredImages.isDirectory()) {
            File[] files = restoredImages.listFiles();
            if (files != null) {
                for (File image : files) {
                    if (image.isFile()) {
                        Files.copy(image.toPath(), new File(imageDir, image.getName()).toPath(), StandardCopyOption.REPLACE_EXISTING);
                    }
                }
            }
        }
        Files.copy(restoredData.toPath(), dataFile.toPath(), StandardCopyOption.REPLACE_EXISTING);
        deleteRecursively(tempDir);

        List<MeQrProfile> restored = new ArrayList<>();
        try {
            restored.addAll(new ProfileStore(context).load());
        } catch (Exception ignored) {
        }
        return restored;
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
