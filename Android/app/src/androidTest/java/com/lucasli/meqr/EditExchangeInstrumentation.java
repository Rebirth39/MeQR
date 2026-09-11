package com.lucasli.meqr;

import android.app.Instrumentation;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Bundle;
import android.util.Base64;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.File;
import java.io.FileOutputStream;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

public final class EditExchangeInstrumentation extends Instrumentation {
    private MainActivity activity;
    private I18n i18n;

    @Override public void onCreate(Bundle args) { super.onCreate(args); start(); }

    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            check(getTargetContext().getPackageName().endsWith(".editexchangetest"), "Isolated package required");
            i18n = new I18n(getTargetContext());
            imageTests();
            getTargetContext().getSharedPreferences("settings", 0).edit().putBoolean("android_profile_v1", true).commit();
            MeQrProfile first = fixture("First"), second = fixture("Second");
            new ProfileStore(getTargetContext()).save(new ArrayList<>(java.util.Arrays.asList(first, second)));
            activity = (MainActivity) startActivitySync(new Intent().setClassName(getTargetContext(), MainActivity.class.getName())
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            onMain(() -> saveFrom(false, 1, "Edited current card"));
            pass("Existing card save returns to that card");
            onMain(() -> saveFrom(true, 0, "Edited from list"));
            pass("Editing from list selects the saved card");
            onMain(() -> saveFrom(false, -1, "New card"));
            pass("New card save selects the newly added card");
            onMain(() -> {
                List<MeQrProfile> profiles = profiles();
                int count = profiles.size();
                call("showEditor", new Class<?>[]{MeQrProfile.class}, profiles.get(0));
                Object session = get(activity, "editSession");
                EditText name = (EditText) get(session, "name");
                name.setText("Must not persist");
                File staging = new File(getTargetContext().getFilesDir(), "profiles.json.new");
                check(staging.mkdir(), "Failed-save injection");
                try {
                    check(saveButton(name.getRootView()).performClick(), "Click Save");
                    check(get(activity, "editSession") == session, "Failed save keeps editor open");
                    List<MeQrProfile> saved = new ProfileStore(getTargetContext()).load();
                    check(saved.size() == count && !saved.get(0).name.equals("Must not persist"), "Failed save retains data");
                } finally { staging.delete(); }
            });
            pass("Failed save retains editor and stored cards");
            onMain(activity::finish);
            result.putString("stream", "PASS: all image, cache and editor regressions\n");
            finish(-1, result);
        } catch (Throwable error) {
            result.putString("stream", android.util.Log.getStackTraceString(error));
            finish(1, result);
        }
    }

    private void imageTests() throws Exception {
        MeQrProfile actual = new ProfileStore(getTargetContext()).load().get(0);
        actual.avatarPath = localImage(actual.avatarPath);
        actual.backgroundPath = localImage(actual.backgroundPath);
        actual.bannerPath = localImage(actual.bannerPath);
        String fingerprint = MeQrExchangeCodeStore.fingerprint(actual, i18n, null);
        MeQrExchangeCodeStore.Record record = MeQrExchangeCodeStore.create(actual, i18n, fingerprint, null);
        JSONObject online = record.onlineProfile;
        check(online.getString("s").equals(actual.subtitle.trim()), "Online full introduction retained");
        checkImage(online, "a", 1);
        checkImage(online, "b", aspect(actual.backgroundPath));
        checkImage(online, "bn", aspect(actual.bannerPath));
        check(online.toString().getBytes(StandardCharsets.UTF_8).length < 900 * 1024, "Server size limit");
        MeQrExchangeProfile offline = MeQrExchangeCodec.decodePayload(MeQrExchangeCodec.offlinePayload(actual, i18n));
        check(offline.backgroundBase64.isEmpty() && offline.bannerBase64.isEmpty(), "Offline remains image-free");
        check(!offline.subtitle.equals(actual.subtitle), "Offline short introduction remains separate");
        Files.write(new File(getTargetContext().getFilesDir(), "online-fixture.json").toPath(), online.toString().getBytes(StandardCharsets.UTF_8));
        pass("Actual preview images decode with original aspect ratios; online full / offline short retained");

        MeQrExchangeCodeStore store = new MeQrExchangeCodeStore(getTargetContext());
        String legacy = legacyFingerprint(actual);
        record.fingerprint = legacy;
        record.onlineProfile.remove("b"); record.onlineProfile.remove("bn");
        store.save(actual.id, record);
        check(store.load(actual.id, fingerprint) == null, "Missing-image legacy cache invalidated");
        MeQrExchangeCodeStore.Record replacement = MeQrExchangeCodeStore.create(actual, i18n, fingerprint, null);
        check(!record.sessionId.equals(replacement.sessionId), "Immutable session replaced");
        store.save(actual.id, replacement);
        store.markSynced(actual.id, record);
        check(!store.load(actual.id, fingerprint).synced, "Stale sync cannot replace new snapshot");
        store.markSynced(actual.id, replacement);
        check(store.load(actual.id, fingerprint).synced, "New code sync persists");
        check(store.load(actual.id, fingerprint).payload.equals(replacement.payload), "Reopen/sync retains new code");
        MeQrProfile plain = fixture("No images");
        check(legacyFingerprint(plain).equals(MeQrExchangeCodeStore.fingerprint(plain, i18n, null)), "Unaffected caches unchanged");
        pass("Legacy image cache refresh, immutable session, stale completion and stable new code");

        Bitmap noise = Bitmap.createBitmap(2400, 1600, Bitmap.Config.ARGB_8888);
        Random random = new Random(42);
        int[] pixels = new int[2400];
        for (int y = 0; y < 1600; y++) {
            for (int x = 0; x < pixels.length; x++) pixels[x] = 0xff000000 | random.nextInt(0x1000000);
            noise.setPixels(pixels, 0, 2400, 0, y, 2400, 1);
        }
        File source = new File(getTargetContext().getFilesDir(), "noise.png");
        try (FileOutputStream output = new FileOutputStream(source)) { noise.compress(Bitmap.CompressFormat.PNG, 100, output); }
        noise.recycle();
        plain.avatarPath = plain.backgroundPath = plain.bannerPath = source.getPath();
        JSONObject noisy = MeQrExchangeCodec.onlineProfile(plain, i18n);
        checkImage(noisy, "b", 1.5); checkImage(noisy, "bn", 1.5);
        check(noisy.toString().getBytes(StandardCharsets.UTF_8).length < 900 * 1024, "High-detail images fit server limit");
        pass("High-detail large images fit server limit without square cropping");
        plain.backgroundPath = new File(getTargetContext().getFilesDir(), "missing.jpg").getPath();
        plain.bannerPath = source.getPath();
        Files.write(source.toPath(), new byte[]{1, 2, 3});
        JSONObject invalid = MeQrExchangeCodec.onlineProfile(plain, i18n);
        check(!invalid.has("b") && !invalid.has("bn"), "Unreadable images do not corrupt exchange");
        pass("Missing and corrupt images handled");
    }

    private String localImage(String old) { return new File(getTargetContext().getFilesDir(), "images/" + new File(old).getName()).getPath(); }
    private static double aspect(String path) {
        BitmapFactory.Options options = new BitmapFactory.Options(); options.inJustDecodeBounds = true;
        BitmapFactory.decodeFile(path, options);
        return (double) options.outWidth / options.outHeight;
    }
    private static void checkImage(JSONObject json, String key, double aspect) throws Exception {
        byte[] bytes = Base64.decode(json.getString(key), Base64.DEFAULT);
        Bitmap bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.length);
        check(bitmap != null, "Decodable " + key);
        check(Math.abs((double) bitmap.getWidth() / bitmap.getHeight() - aspect) < 0.01, "Aspect ratio " + key);
        bitmap.recycle();
    }
    private String legacyFingerprint(MeQrProfile p) throws Exception {
        JSONArray values = new JSONArray().put("exchange-v2").put(p.id).put(p.name).put(p.subtitle)
                .put(p.template).put(p.textColor).put(p.backgroundColor).put(p.qrColor)
                .put(fileDigest(p.avatarPath)).put(fileDigest(p.backgroundPath)).put(fileDigest(p.bannerPath)).put("");
        for (String tag : p.tags) values.put(tag);
        for (MeQrItem item : p.qrItems.subList(0, Math.min(3, p.qrItems.size()))) {
            values.put(new JSONArray().put(item.platform).put(item.platformDisplayName(i18n)).put(item.qrContent));
        }
        return MeQrExchangeCodeStore.digest(values.toString().getBytes(StandardCharsets.UTF_8));
    }
    private static String fileDigest(String path) throws Exception {
        return path == null || path.isEmpty() ? "" : MeQrExchangeCodeStore.digest(Files.readAllBytes(new File(path).toPath()));
    }
    private MeQrProfile fixture(String name) {
        MeQrProfile profile = new MeQrProfile(); profile.name = name; profile.firstItem().qrContent = "fixture"; return profile;
    }
    private void saveFrom(boolean list, int index, String name) throws Exception {
        List<MeQrProfile> profiles = profiles();
        field(activity, "showingCardList").set(activity, list);
        field(activity, "currentPage").set(activity, list || index < 0 ? 1 : index);
        activity.renderMain();
        int expected = index < 0 ? profiles.size() : index;
        call("showEditor", new Class<?>[]{MeQrProfile.class}, index < 0 ? null : profiles.get(index));
        Object session = get(activity, "editSession");
        EditText input = (EditText) get(session, "name"); input.setText(name);
        check(saveButton(input.getRootView()).performClick(), "Save button clicked");
        check(!(Boolean) get(activity, "showingCardList"), "Saved card shown instead of list");
        check((Integer) get(activity, "currentPage") == expected, "Correct selected card");
        check(new ProfileStore(getTargetContext()).load().get(expected).name.equals(name), "Saved card persisted");
        check(!input.isAttachedToWindow(), "Successful save dismisses editor");
    }
    @SuppressWarnings("unchecked") private List<MeQrProfile> profiles() throws Exception { return (List<MeQrProfile>) get(activity, "profiles"); }
    private Button saveButton(View view) {
        if (view instanceof Button && ((Button) view).getText().toString().equals(i18n.t("save"))) return (Button) view;
        if (view instanceof ViewGroup) {
            ViewGroup group = (ViewGroup) view;
            for (int i = 0; i < group.getChildCount(); i++) { Button button = saveButton(group.getChildAt(i)); if (button != null) return button; }
        }
        return null;
    }
    private static Field field(Object target, String name) throws Exception { Field f = target.getClass().getDeclaredField(name); f.setAccessible(true); return f; }
    private static Object get(Object target, String name) throws Exception { return field(target, name).get(target); }
    private void call(String name, Class<?>[] types, Object... args) throws Exception { Method m = MainActivity.class.getDeclaredMethod(name, types); m.setAccessible(true); m.invoke(activity, args); }
    private interface Checked { void run() throws Exception; }
    private void onMain(Checked action) throws Exception {
        CountDownLatch done = new CountDownLatch(1); Throwable[] failure = {null};
        new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> {
            try { action.run(); } catch (Throwable e) { failure[0] = e; } finally { done.countDown(); }
        });
        check(done.await(30, TimeUnit.SECONDS), "Main action deadline");
        if (failure[0] != null) throw new AssertionError(failure[0]);
    }
    private void pass(String message) { Bundle status = new Bundle(); status.putString("stream", "PASS: " + message + "\n"); sendStatus(0, status); }
    private static void check(boolean condition, String message) { if (!condition) throw new AssertionError(message); }
}
