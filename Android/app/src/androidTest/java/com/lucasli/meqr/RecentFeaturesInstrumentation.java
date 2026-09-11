package com.lucasli.meqr;

import android.app.Instrumentation;
import android.content.Intent;
import android.os.Bundle;
import android.app.AlertDialog;
import android.app.Dialog;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import com.google.zxing.BinaryBitmap;
import com.google.zxing.RGBLuminanceSource;
import com.google.zxing.common.HybridBinarizer;
import com.google.zxing.qrcode.QRCodeReader;
import java.io.File;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.nio.charset.StandardCharsets;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.json.JSONArray;
import org.json.JSONObject;
public final class RecentFeaturesInstrumentation extends Instrumentation {
    private Context context;
    private MainActivity activity;
    private boolean mainTimedOut;

    @Override public void onCreate(Bundle args) { super.onCreate(args); start(); }

    @Override public void onStart() {
        Bundle result = new Bundle();
        StringBuilder log = new StringBuilder();
        int failures = 0;
        try {
            progress("START: instrumentation");
            context = getTargetContext();
            assertTrue(context.getPackageName().endsWith(".bugaudit20260909"));
            context.getSharedPreferences("settings", 0).edit().putBoolean("android_profile_v1", true).commit();
            progress("START: startActivitySync (30s limit)");
            java.util.concurrent.FutureTask<MainActivity> startup = new java.util.concurrent.FutureTask<>(() ->
                    (MainActivity) startActivitySync(new Intent().setClassName(context, MainActivity.class.getName()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)));
            Thread launcher = new Thread(startup, "audit-activity-launch");
            launcher.setDaemon(true);
            launcher.start();
            try { activity = startup.get(30, TimeUnit.SECONDS); }
            finally { if (!startup.isDone()) startup.cancel(true); }
            progress("PASS: startActivitySync returned");
            onMain(() -> { });
            progress("PASS: main-thread barrier");
            String[] tests = {"editorCopyPreservesRhodesSubtitleAndIsolatesChanges", "restoredDraftPreviewDoesNotEraseAbsentAppearanceField",
                    "systemBackRequestsDiscardAndCancelRetainsDraft", "removedCatalogPaletteSurvivesOpeningAndSavingColorEditor",
                    "catalogRenameCannotStealTheNextTagsReference", "unicodeQrRoundTripsThroughRealPixels",
                    "unicodeColorLayerQrRoundTripsThroughRealPixels", "exchangeCacheKeepsSubtitleAndRejectsStaleCompletion",
                    "outboxPersistsRetryIdentityAndCannotCancelInFlight", "sessionEventsFollowSessionId", "reportBackRetainsDraft"};
            for (String test : tests) {
                progress("START: " + test);
                try {
                    onMain(this::setUp);
                    if (test.startsWith("outbox") || test.startsWith("sessionEvents") || test.startsWith("exchangeCache")) getClass().getDeclaredMethod(test).invoke(this);
                    else onMain(() -> getClass().getDeclaredMethod(test).invoke(this));
                    log.append("PASS: ").append(test).append('\n');
                    progress("PASS: " + test);
                } catch (Throwable error) {
                    failures++;
                    log.append("FAIL: ").append(test).append('\n').append(android.util.Log.getStackTraceString(error));
                    progress("FAIL: " + test + "\n" + android.util.Log.getStackTraceString(error));
                    if (mainTimedOut) break;
                }
            }
        } catch (Throwable error) {
            failures++;
            log.append(android.util.Log.getStackTraceString(error));
            progress("FAIL: startup\n" + android.util.Log.getStackTraceString(error));
        }
        result.putString("stream", log.toString());
        finish(failures == 0 ? -1 : 1, result);
    }

    private interface Checked { void run() throws Exception; }
    private void progress(String message) {
        Bundle status = new Bundle(); status.putString("stream", message + "\n"); sendStatus(0, status);
    }

    private void onMain(Checked action) {
        Throwable[] failure = {null};
        CountDownLatch complete = new CountDownLatch(1);
        Runnable work = () -> {
            try { action.run(); } catch (Throwable error) { failure[0] = error; }
            finally { complete.countDown(); }
        };
        android.os.Handler main = new android.os.Handler(android.os.Looper.getMainLooper());
        main.post(work);
        try {
            if (!complete.await(15, TimeUnit.SECONDS)) {
                main.removeCallbacks(work);
                mainTimedOut = true;
                throw new AssertionError("Main-thread action exceeded 15 seconds");
            }
        } catch (InterruptedException error) {
            Thread.currentThread().interrupt();
            throw new AssertionError(error);
        }
        if (failure[0] != null) throw new AssertionError(failure[0]);
    }

    public void setUp() throws Exception {
        field(activity, "i18n").set(activity, new I18n(context));
        installCatalog(entry("unrelated", "Unrelated", "Unrelated"));
    }

    public void editorCopyPreservesRhodesSubtitleAndIsolatesChanges() throws Exception {
        MeQrProfile source = new MeQrProfile();
        source.template = "rhodes";
        source.passSubtitle = "FIELD OPERATOR";
        source.tags.add("Custom");
        source.reconcileTags("en");
        MeQrProfile copy = (MeQrProfile) invoke("copy", new Class<?>[]{MeQrProfile.class}, source);
        assertEquals(source.passSubtitle, copy.passSubtitle);
        copy.tagReferences.get(0).lastName = "Changed";
        copy.firstItem().qrContent = "changed";
        assertEquals("Custom", source.tagReferences.get(0).lastName);
        assertEquals("", source.firstItem().qrContent);
    }

    public void restoredDraftPreviewDoesNotEraseAbsentAppearanceField() throws Exception {
        MeQrProfile profile = new MeQrProfile();
        profile.passSubtitle = "SAVED DRAFT";
        session(MeQrProfile.fromJson(profile.toJson()));
        MeQrProfile restored = sessionProfile();
        invoke("applyEditFields", new Class<?>[]{MeQrProfile.class}, restored);
        assertEquals("SAVED DRAFT", restored.passSubtitle);
    }

    public void systemBackRequestsDiscardAndCancelRetainsDraft() throws Exception {
        session(new MeQrProfile());
        Dialog editor = new Dialog(activity);
        editor.show();
        Runnable discard = () -> {
            try { invoke("confirmDiscard", new Class<?>[]{Runnable.class}, (Runnable) editor::dismiss); }
            catch (Exception e) { throw new AssertionError(e); }
        };
        invoke("handleDialogBack", new Class<?>[]{Dialog.class, Runnable.class}, editor, discard);
        editor.dispatchKeyEvent(new KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_BACK));
        editor.dispatchKeyEvent(new KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_BACK));
        AlertDialog confirmation = latestAlert();
        assertTrue(editor.isShowing());
        assertTrue(confirmation.isShowing());
        confirmation.getButton(AlertDialog.BUTTON_NEGATIVE).performClick();
        assertTrue(editor.isShowing());
        editor.dismiss();
    }

    public void removedCatalogPaletteSurvivesOpeningAndSavingColorEditor() throws Exception {
        MeQrProfile profile = new MeQrProfile();
        profile.tags.add("Removed tag");
        TagReference reference = new TagReference("Removed tag");
        reference.catalogID = "deleted-id";
        reference.colors = new int[]{0xFF123456, 0xFFABCDEF};
        reference.solid = 0xFFABCDEF;
        profile.tagReferences.add(reference);
        session(profile);
        invoke("showTagColorEditor", new Class<?>[]{String.class}, "Removed tag");
        AlertDialog editor = latestAlert();
        assertTrue("Retained palette must default to mixed mode", findTag(editor.getWindow().getDecorView(), "preset").isSelected());
        findTag(editor.getWindow().getDecorView(), "custom").performClick();
        assertNotNull("Custom starts with the retained solid color", findText(editor.getWindow().getDecorView(), "#ABCDEF"));
        findTag(editor.getWindow().getDecorView(), "preset").performClick();
        editor.getButton(AlertDialog.BUTTON_POSITIVE).performClick();
        assertArrayEquals(reference.colors, profile.tagColors("Removed tag"));
    }

    public void catalogRenameCannotStealTheNextTagsReference() throws Exception {
        installCatalog(entry("first", "Alpha", "Alpha"), entry("second", "Beta", "Beta"));
        MeQrProfile profile = new MeQrProfile();
        profile.tags.add("Alpha"); profile.tags.add("Beta");
        profile.reconcileTags(null);
        profile.tagColorOverrides.put("Alpha", "#123456");
        profile.tagColorOverrides.put("Beta", "#ABCDEF");
        installCatalog(entry("first", "Alpha", "Beta"), entry("second", "Beta", "Gamma"));
        profile.reconcileTags("en");
        assertEquals(java.util.Arrays.asList("Beta", "Gamma"), profile.tags);
        assertEquals("first", profile.tagReferences.get(0).catalogID);
        assertEquals("second", profile.tagReferences.get(1).catalogID);
        assertEquals("#123456", profile.tagColorOverrides.get("Beta"));
        assertEquals("#ABCDEF", profile.tagColorOverrides.get("Gamma"));
        assertEquals("second", MeQrProfile.fromJson(profile.toJson()).tagReferences.get(1).catalogID);
    }

    public void unicodeQrRoundTripsThroughRealPixels() throws Exception {
        String payload = "https://example.com/\u540d\u7247?q=\u521d\u97f3\u30df\u30af\uD83C\uDFB5";
        assertEquals(payload, decode(QrCodeGenerator.generate(payload, Color.BLACK, 512)));
    }

    public void unicodeColorLayerQrRoundTripsThroughRealPixels() throws Exception {
        String payload = "https://example.com/\u4ea4\u6362?q=\uD83C\uDFB5";
        assertEquals(payload, decode(QrCodeGenerator.generateColorLayered(payload, null, 512)));
    }

    public void exchangeCacheKeepsSubtitleAndRejectsStaleCompletion() throws Exception {
        MeQrProfile profile = new MeQrProfile();
        profile.subtitle = "Custom intro";
        I18n i18n = new I18n(context);
        MeQrExchangeCodeStore store = new MeQrExchangeCodeStore(context);
        String fingerprint = MeQrExchangeCodeStore.fingerprint(profile, i18n, "event-one");
        MeQrExchangeCodeStore.Record first = MeQrExchangeCodeStore.create(profile, i18n, fingerprint, "event-one");
        assertEquals(profile.subtitle, first.onlineProfile.getString("s"));
        assertEquals(profile.subtitle, MeQrExchangeCodec.offlineFallback(first.payload).subtitle);
        assertEquals(first.payload, decode(QrCodeGenerator.generateColorLayered(first.payload, first.avatar, 960)));
        store.save(profile.id, first);
        assertEquals(first.payload, new MeQrExchangeCodeStore(context).load(profile.id, fingerprint).payload);
        profile.subtitle = "Changed intro";
        String changed = MeQrExchangeCodeStore.fingerprint(profile, i18n, "event-one");
        assertNotEquals(fingerprint, changed);
        assertNull(store.load(profile.id, changed));
        MeQrExchangeCodeStore.Record second = MeQrExchangeCodeStore.create(profile, i18n, changed, "event-one");
        store.save(profile.id, second);
        store.markSynced(profile.id, first);
        assertFalse(store.load(profile.id, changed).synced);
        store.markSynced(profile.id, second);
        assertTrue(store.load(profile.id, changed).synced);
        assertEquals(second.payload, store.load(profile.id, changed).payload);
        assertNotEquals(changed, MeQrExchangeCodeStore.fingerprint(profile, i18n, "event-two"));
    }

    public void outboxPersistsRetryIdentityAndCannotCancelInFlight() throws Exception {
        File file = new File(context.getFilesDir(), "queue.json");
        String id = UUID.randomUUID().toString();
        JSONObject payload = new JSONObject().put("request_id", id).put("tag_name", "Audit");
        AtomicInteger calls = new AtomicInteger();
        try {
            TagReportOutbox offline = new TagReportOutbox(file, body -> { calls.incrementAndGet(); throw new java.io.IOException("offline"); });
            try {
                offline.enqueue(payload); offline.enqueue(payload);
                assertEquals(1, offline.snapshot().length());
                assertEquals(0, calls.get());
                offline.kick(); awaitState(offline, "pending", 1);
                assertTrue(offline.snapshot().getJSONObject(0).getLong("next") > System.currentTimeMillis());
            } finally { offline.close(); }
            CountDownLatch started = new CountDownLatch(1), finish = new CountDownLatch(1);
            TagReportOutbox online = new TagReportOutbox(file, body -> {
                assertEquals(id, body.getString("request_id"));
                started.countDown();
                assertTrue(finish.await(5, TimeUnit.SECONDS));
                return "MEQR-20260909-ABCDEF";
            });
            try {
                online.retry(id); assertTrue(started.await(5, TimeUnit.SECONDS));
                online.cancel(id); assertEquals(1, online.snapshot().length());
                finish.countDown(); awaitState(online, "sent", 2);
                assertEquals("MEQR-20260909-ABCDEF", online.snapshot().getJSONObject(0).getString("ticket"));
                online.cancel(id); assertEquals(0, online.snapshot().length());
            } finally { finish.countDown(); online.close(); }
        } finally { file.delete(); }
    }

    private void session(MeQrProfile profile) throws Exception {
        Class<?> type = Class.forName("com.lucasli.meqr.MainActivity$EditSession");
        java.lang.reflect.Constructor<?> constructor = type.getDeclaredConstructor(MeQrProfile.class);
        constructor.setAccessible(true);
        field(activity, "editSession").set(activity, constructor.newInstance(profile));
    }

    private MeQrProfile sessionProfile() throws Exception {
        Object session = field(activity, "editSession").get(activity);
        return (MeQrProfile) field(session, "profile").get(session);
    }

    private static Field field(Object target, String name) throws Exception {
        Field field = target.getClass().getDeclaredField(name); field.setAccessible(true); return field;
    }

    private Object invoke(String name, Class<?>[] types, Object... args) throws Exception {
        Method method = MainActivity.class.getDeclaredMethod(name, types); method.setAccessible(true);
        return method.invoke(activity, args);
    }

    private static View findTag(View root, String tag) {
        if (tag.equals(root.getTag())) return root;
        if (root instanceof ViewGroup) for (int i = 0; i < ((ViewGroup) root).getChildCount(); i++) {
            View result = findTag(((ViewGroup) root).getChildAt(i), tag); if (result != null) return result;
        }
        return null;
    }

    private static View findText(View root, String text) {
        if (root instanceof EditText && text.contentEquals(((EditText) root).getText())) return root;
        if (root instanceof ViewGroup) for (int i = 0; i < ((ViewGroup) root).getChildCount(); i++) {
            View result = findText(((ViewGroup) root).getChildAt(i), text); if (result != null) return result;
        }
        return null;
    }

    private static JSONObject entry(String id, String original, String english) throws Exception {
        return new JSONObject().put("id", id).put("names", new JSONObject().put("zhHans", original).put("en", english))
                .put("colors", new JSONArray().put("#123456").put("#ABCDEF"));
    }

    private static void installCatalog(JSONObject... entries) throws Exception {
        JSONArray array = new JSONArray(); for (JSONObject entry : entries) array.put(entry);
        RemoteTagCatalog.install(new JSONObject().put("schemaVersion", 1).put("revision", "audit")
                .put("entries", array).toString().getBytes(StandardCharsets.UTF_8), RemoteTagCatalog.Source.BUNDLED);
    }

    private static String decode(Bitmap bitmap) throws Exception {
        int[] pixels = new int[bitmap.getWidth() * bitmap.getHeight()];
        bitmap.getPixels(pixels, 0, bitmap.getWidth(), 0, 0, bitmap.getWidth(), bitmap.getHeight());
        return new QRCodeReader().decode(new BinaryBitmap(new HybridBinarizer(
                new RGBLuminanceSource(bitmap.getWidth(), bitmap.getHeight(), pixels)))).getText();
    }

    private static void awaitState(TagReportOutbox queue, String state, int attempts) throws Exception {
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
        do {
            JSONObject job = queue.snapshot().getJSONObject(0);
            if (state.equals(job.getString("status")) && job.getInt("attempts") >= attempts) return;
            Thread.sleep(10);
        } while (System.nanoTime() < deadline);
        fail("Queue did not reach " + state + ": " + queue.snapshot());
    }

    public void sessionEventsFollowSessionId() throws Exception {
        EventStore events = new EventStore(context);
        MeQrEvent original = events.addCustomEvent("Original event", "Original venue", "");
        events.setActiveEvent(events.addCustomEvent("Current event", "Current venue", ""));
        for (boolean reusable : new boolean[]{false, true}) {
            String sessionId = UUID.randomUUID().toString();
            MeQrExchangeProfile peer = new MeQrExchangeProfile(); peer.id = UUID.randomUUID().toString();
            MeQrRemoteService.EncounterSession remote = new MeQrRemoteService.EncounterSession(sessionId, "", null, peer, "confirmed", original.id);
            remote.reusable = reusable;
            remote.confirmations.add(new MeQrRemoteService.Confirmation("confirmation", peer, 123456));
            EncounterStore store = new EncounterStore(context, (url, token) -> remote);
            store.registerOutgoingSession(sessionId);
            CountDownLatch complete = new CountDownLatch(1);
            store.syncPendingSessions(complete::countDown);
            assertTrue(complete.await(5, TimeUnit.SECONDS));
            String recordId = reusable ? sessionId + ":confirmation" : sessionId;
            EncounterRecord saved = null;
            for (EncounterRecord record : new EncounterStore(context).records()) if (recordId.equals(record.sessionID)) saved = record;
            assertNotNull("Session encounter saved", saved);
            assertEquals(original.id, saved.eventId);
            assertEquals(original.title, saved.eventTitle);
            assertEquals(original.venue, saved.eventVenue);
            if (reusable) assertEquals(123456L, saved.metAt);
        }
    }

    public void reportBackRetainsDraft() throws Exception {
        TagReport.show(activity, new I18n(context), "Audit", payload -> { throw new AssertionError("Must not submit"); });
        AlertDialog report = latestAlert();
        android.widget.Spinner reason = findSpinner(report.getWindow().getDecorView());
        reason.setSelection(1);
        report.dispatchKeyEvent(new KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_BACK));
        report.dispatchKeyEvent(new KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_BACK));
        AlertDialog confirmation = latestAlert();
        assertTrue(confirmation != report);
        confirmation.getButton(AlertDialog.BUTTON_NEGATIVE).performClick();
        assertTrue(report.isShowing());
        assertEquals(1, reason.getSelectedItemPosition());
        report.dismiss();
    }

    private static android.widget.Spinner findSpinner(View root) {
        if (root instanceof android.widget.Spinner) return (android.widget.Spinner) root;
        if (root instanceof ViewGroup) for (int i = 0; i < ((ViewGroup) root).getChildCount(); i++) {
            android.widget.Spinner result = findSpinner(((ViewGroup) root).getChildAt(i)); if (result != null) return result;
        }
        return null;
    }

    private AlertDialog latestAlert() {
        java.util.List<View> windows = android.view.inspector.WindowInspector.getGlobalWindowViews();
        for (int i = windows.size() - 1; i >= 0; i--) {
            android.view.Window.Callback callback = null;
            try {
                Field window = windows.get(i).getClass().getDeclaredField("mWindow"); window.setAccessible(true);
                callback = ((android.view.Window) window.get(windows.get(i))).getCallback();
            } catch (Exception ignored) { }
            if (callback instanceof AlertDialog) return (AlertDialog) callback;
        }
        throw new AssertionError("Missing alert dialog");
    }

    private static void assertTrue(boolean value) { assertTrue("Expected true", value); }
    private static void assertTrue(String message, boolean value) { if (!value) fail(message); }
    private static void assertFalse(boolean value) { assertTrue(!value); }
    private static void assertNull(Object value) { assertTrue(value == null); }
    private static void assertNotNull(String message, Object value) { assertTrue(message, value != null); }
    private static void assertEquals(Object expected, Object actual) {
        if (!java.util.Objects.equals(expected, actual)) fail("Expected " + expected + ", got " + actual);
    }
    private static void assertNotEquals(Object expected, Object actual) { assertTrue(!java.util.Objects.equals(expected, actual)); }
    private static void assertArrayEquals(int[] expected, int[] actual) { assertTrue(java.util.Arrays.equals(expected, actual)); }
    private static void fail(String message) { throw new AssertionError(message); }
}
