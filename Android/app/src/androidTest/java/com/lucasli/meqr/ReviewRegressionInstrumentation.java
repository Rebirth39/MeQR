package com.lucasli.meqr;

import android.app.Instrumentation;
import android.content.Context;
import android.content.ContextWrapper;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Bundle;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;
import java.util.zip.ZipOutputStream;

public final class ReviewRegressionInstrumentation extends Instrumentation {
    @Override public void onCreate(Bundle arguments) { super.onCreate(arguments); start(); }
    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            check(getTargetContext().getPackageName().endsWith(".review20260917"), "Isolated package required");
            result.putString("stream", runChecks(getTargetContext()));
            finish(-1, result);
        } catch (Throwable error) {
            result.putString("stream", android.util.Log.getStackTraceString(error));
            finish(1, result);
        }
    }

    public static String runChecks(Context base) throws Exception {
        Fixture context = new Fixture(base);
        ProfileStore store = new ProfileStore(context);
        MeQrProfile original = profile("Original");
        File originalImage = new File(context.getFilesDir(), "images/original.png");
        byte[] png = java.util.Base64.getDecoder().decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=");
        Files.write(originalImage.toPath(), png);
        original.avatarPath = originalImage.getAbsolutePath();
        store.save(Collections.singletonList(original));
        File data = new File(context.getFilesDir(), "profiles.json");
        byte[] before = Files.readAllBytes(data.toPath());

        String damaged = "[" + original.toJson() + ",null," + profile("Tail").toJson() + "]";
        Files.write(data.toPath(), damaged.getBytes(StandardCharsets.UTF_8));
        check(store.load().isEmpty() && store.hadLoadError(), "Partial load must fail closed");
        expectFailure(() -> store.save(Collections.singletonList(original)));
        check(new String(Files.readAllBytes(data.toPath()), StandardCharsets.UTF_8).equals(damaged), "Load failure must preserve complete original file");
        Files.write(data.toPath(), before);
        check(store.load().size() == 1 && !store.hadLoadError(), "Valid explicit recovery clears load failure");

        BackupManager backups = new BackupManager(context);
        File archive = new File(context.getFilesDir(), "fixture.zip");
        writeArchive(archive, "profiles.json", "[null]".getBytes(StandardCharsets.UTF_8));
        expectFailure(() -> backups.importBackup(Uri.fromFile(archive)));
        unchanged(data, before, originalImage, png);

        MeQrProfile missing = profile("Missing image");
        missing.avatarPath = "/other-phone/images/missing.png";
        writeArchive(archive, "profiles.json", new JSONArray().put(missing.toJson()).toString().getBytes(StandardCharsets.UTF_8));
        expectFailure(() -> backups.importBackup(Uri.fromFile(archive)));
        unchanged(data, before, originalImage, png);
        writeArchive(archive, "../escaped", png);
        expectFailure(() -> backups.importBackup(Uri.fromFile(archive)));
        unchanged(data, before, originalImage, png);

        MeQrProfile incoming = profile("Restored");
        incoming.avatarPath = "/another-phone/images/avatar.png";
        try (ZipOutputStream zip = new ZipOutputStream(Files.newOutputStream(archive.toPath()))) {
            entry(zip, "profiles.json", new JSONArray().put(incoming.toJson()).toString().getBytes(StandardCharsets.UTF_8));
            entry(zip, "images/avatar.png", png);
        }
        List<MeQrProfile> restored = backups.importBackup(Uri.fromFile(archive));
        check(restored.size() == 1 && restored.get(0).name.equals("Restored"), "Restore complete card");
        check(new File(restored.get(0).avatarPath).isFile(), "Rebase restored images to this installation");
        check(Arrays.equals(Files.readAllBytes(originalImage.toPath()), png), "Keep original images for rollback");
        check(Arrays.equals(Files.readAllBytes(new File(context.getFilesDir(), "profiles.json.pre-restore").toPath()), before), "Keep original JSON for rollback");
        for (int index = 0; index < 140; index++) Files.write(new File(context.getFilesDir(), "images/orphan-" + index).toPath(), png);
        File export = new File(context.getFilesDir(), "export.zip");
        backups.exportBackup(Uri.fromFile(export));
        try (ZipFile zip = new ZipFile(export)) { check(zip.size() == 2, "Export referenced images only"); }
        check(backups.importBackup(Uri.fromFile(export)).size() == 1, "Export can be imported again");

        List<MeQrProfile> oversized = new ArrayList<>();
        for (int index = 0; index < 128; index++) {
            MeQrProfile card = profile("Card " + index);
            card.avatarPath = new File(context.getFilesDir(), "images/orphan-" + index).getAbsolutePath();
            oversized.add(card);
        }
        store.load();
        store.save(oversized);
        File rejected = new File(context.getFilesDir(), "rejected.zip");
        expectFailure(() -> backups.exportBackup(Uri.fromFile(rejected)));
        check(!rejected.exists(), "Reject oversize backup before creating output");

        AtomicInteger deliveries = new AtomicInteger();
        EncounterStore.SessionFetcher noFetch = (url, token) -> { throw new AssertionError("Unexpected fetch"); };
        EncounterStore queue = new EncounterStore(context, noFetch, (session, reply) -> { throw new IOException("Offline"); });
        MeQrExchangeProfile contact = new MeQrExchangeProfile();
        contact.name = "Contact";
        JSONObject reply = new JSONObject().put("n", "Local snapshot");
        queue.saveScannedProfile(contact, null, "review-session", reply);
        synchronize(queue);
        check(queue.records().get(0).pendingConfirmationProfile != null, "Offline reply remains pending");
        EncounterStore reopened = new EncounterStore(context, noFetch, (session, saved) -> {
            check(saved.getString("n").equals("Local snapshot"), "Retry persisted snapshot");
            deliveries.incrementAndGet();
        });
        synchronize(reopened);
        check(deliveries.get() == 1 && reopened.records().get(0).pendingConfirmationProfile == null, "Retry after restart succeeds");
        reopened.saveScannedProfile(contact, null, "review-session", reply);
        synchronize(reopened);
        check(deliveries.get() == 1 && reopened.records().size() == 1, "No duplicate confirmation after success");

        Fixture receiving = new Fixture(base);
        CountDownLatch started = new CountDownLatch(1), release = new CountDownLatch(1), finished = new CountDownLatch(2);
        EncounterStore receiver = new EncounterStore(receiving, (url, token) -> {
            started.countDown();
            check(release.await(5, TimeUnit.SECONDS), "Release fetch");
            MeQrRemoteService.EncounterSession session = new MeQrRemoteService.EncounterSession("fixed", url, contact, null, "waiting", null);
            session.reusable = true;
            session.confirmations.add(new MeQrRemoteService.Confirmation("first", contact, 1234));
            return session;
        });
        receiver.registerOutgoingSession("fixed", "token");
        receiver.syncPendingSessions(finished::countDown);
        check(started.await(5, TimeUnit.SECONDS), "Fetch started");
        receiver.syncPendingSessions(finished::countDown);
        check(finished.getCount() == 2, "Waiters do not complete before active sync");
        release.countDown();
        check(finished.await(5, TimeUnit.SECONDS), "Both observers receive completion");
        check(receiver.pendingCount() == 1 && receiver.records().size() == 1, "Reusable session adds records without removing pending session");
        MeQrProfile rhodes = profile("Rhodes");
        rhodes.template = "rhodes";
        check(ProfileSyncClient.document(rhodes, Collections.emptyMap()).getString("template").equals("rhodesPass"), "Canonical sync template");
        check(ProfileSyncScreen.normalizeCode("nbz5-2wga-7u85-1q4s").equals("NBZ52WGA7U851Q4S"), "New lowercase invite");
        check(ProfileSyncScreen.normalizeCode("ABCDEF0123456789ABCDEF0123456789").equals("abcdef0123456789abcdef0123456789"), "Legacy hex invite");
        check(MeQrRemoteService.encounterSessionID("https://profile.meqrcode.cn/encounter-sessions/fixed#offline=x").equals("fixed"), "Offline session ID");
        check(MeQrRemoteService.encounterSessionID("https://example.com/encounter-sessions/fixed") == null, "Reject unrelated session host");
        return "PASS: partial-load protection, invalid/missing-image/traversal restore, image and JSON preservation, image rebasing, export limits, durable reply retry, duplicate suppression, reusable-session observers, sync template, binding codes, session validation\n";
    }

    private static MeQrProfile profile(String name) {
        MeQrProfile profile = new MeQrProfile();
        profile.name = name;
        profile.firstItem().qrContent = "https://example.com";
        return profile;
    }
    private static void synchronize(EncounterStore store) throws Exception {
        CountDownLatch completion = new CountDownLatch(1);
        store.syncPendingSessions(completion::countDown);
        check(completion.await(5, TimeUnit.SECONDS), "Sync completes");
    }
    private static void unchanged(File data, byte[] before, File image, byte[] png) throws Exception {
        check(Arrays.equals(Files.readAllBytes(data.toPath()), before), "Failed restore preserves JSON");
        check(Arrays.equals(Files.readAllBytes(image.toPath()), png), "Failed restore preserves image");
    }
    private static void writeArchive(File target, String name, byte[] data) throws Exception {
        try (ZipOutputStream zip = new ZipOutputStream(Files.newOutputStream(target.toPath()))) { entry(zip, name, data); }
    }
    private static void entry(ZipOutputStream zip, String name, byte[] bytes) throws Exception {
        zip.putNextEntry(new ZipEntry(name)); zip.write(bytes); zip.closeEntry();
    }
    private interface Work { void run() throws Exception; }
    private static void expectFailure(Work work) throws Exception {
        try { work.run(); } catch (IOException expected) { return; }
        throw new AssertionError("Expected operation to fail");
    }
    private static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }
    private static final class Fixture extends ContextWrapper {
        private final File files;
        private final String prefix = UUID.randomUUID().toString();
        Fixture(Context base) { super(base); files = new File(base.getCacheDir(), prefix); files.mkdirs(); }
        @Override public Context getApplicationContext() { return this; }
        @Override public File getFilesDir() { return files; }
        @Override public SharedPreferences getSharedPreferences(String name, int mode) { return super.getSharedPreferences(prefix + name, mode); }
    }
}
