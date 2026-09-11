package com.lucasli.meqr;

import android.app.Instrumentation;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.Rect;
import android.os.Bundle;
import android.view.KeyEvent;
import android.view.accessibility.AccessibilityNodeInfo;
import java.io.File;
import java.io.FileOutputStream;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

public final class DesignAlignmentInstrumentation extends Instrumentation {
    @Override public void onCreate(Bundle arguments) { super.onCreate(arguments); start(); }
    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            check(getTargetContext().getPackageName().endsWith(".designalignmenttest"), "Isolated package required");
            I18n i18n = new I18n(getTargetContext());
            i18n.setLanguageMode(I18n.EN);
            MeQrProfile profile = new ProfileStore(getTargetContext()).load().get(0);
            profile.avatarPath = image(profile.avatarPath);
            profile.backgroundPath = image(profile.backgroundPath);
            profile.bannerPath = image(profile.bannerPath);
            new ProfileStore(getTargetContext()).save(new ArrayList<>(java.util.Collections.singletonList(profile)));
            getTargetContext().getSharedPreferences("settings", 0).edit().putBoolean("android_profile_v1", true).commit();
            MainActivity activity = (MainActivity) startActivitySync(new Intent().setClassName(getTargetContext(), MainActivity.class.getName()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            waitForIdleSync();
            save("android-front.png", CardRenderer.render(profile, i18n, 1080));
            MeQrExchangeCodeStore.Record code = MeQrExchangeCodeStore.create(profile, i18n, "local-layout-fixture", null);
            code.synced = true;
            String payload = code.payload;
            for (String template : new String[]{"rhodes", "standard"}) {
                profile.template = template;
                CountDownLatch done = new CountDownLatch(1);
                Throwable[] failure = {null};
                new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> {
                    try {
                        Method method = MainActivity.class.getDeclaredMethod("showExchangeCodeSheet", MeQrProfile.class, MeQrExchangeCodeStore.Record.class);
                        method.setAccessible(true); method.invoke(activity, profile, code);
                    } catch (Throwable error) { failure[0] = error; }
                    finally { done.countDown(); }
                });
                check(done.await(30, TimeUnit.SECONDS), "Sheet deadline");
                if (failure[0] != null) throw new AssertionError(failure[0]);
                waitForIdleSync();
                AccessibilityNodeInfo save = waitNode(i18n.t("saveMeQrCode"));
                Rect saveBounds = new Rect(); save.getBoundsInScreen(saveBounds);
                Rect qrBounds = new Rect(); waitNode(i18n.t("meqrProfileCode"), "android.widget.ImageView").getBoundsInScreen(qrBounds);
                Bitmap screenshot = getUiAutomation().takeScreenshot();
                check(qrBounds.width() == qrBounds.height() && qrBounds.width() > 300, "Stable square QR");
                check(qrBounds.bottom < saveBounds.top && saveBounds.bottom <= screenshot.getHeight(), "QR and fixed save action do not overlap");
                check(saveBounds.left >= 0 && saveBounds.right <= screenshot.getWidth(), "Save fits screen");
                save("android-exchange-" + template + ".png", screenshot);
                check(code.payload.equals(payload), "Presentation preserves cached exchange code");
                waitNode(i18n.t("done")).performAction(AccessibilityNodeInfo.ACTION_CLICK);
                waitForIdleSync();
            }
            sendKeyDownUpSync(KeyEvent.KEYCODE_BACK);
            runOnMainSync(activity::finish);
            result.putString("stream", "PASS: front render, Rhodes/standard exchange layout, square QR, visible fixed save, Done navigation, unchanged payload\n");
            finish(-1, result);
        } catch (Throwable error) {
            result.putString("stream", android.util.Log.getStackTraceString(error)); finish(1, result);
        }
    }
    private String image(String old) { return new File(getTargetContext().getFilesDir(), "images/" + new File(old).getName()).getPath(); }
    private void save(String name, Bitmap bitmap) throws Exception {
        try (FileOutputStream out = getTargetContext().openFileOutput(name, 0)) { bitmap.compress(Bitmap.CompressFormat.PNG, 100, out); }
    }
    private AccessibilityNodeInfo waitNode(String text) throws Exception { return waitNode(text, null); }
    private AccessibilityNodeInfo waitNode(String text, String type) throws Exception {
        for (int i = 0; i < 50; i++) {
            AccessibilityNodeInfo node = find(getUiAutomation().getRootInActiveWindow(), text, type);
            if (node != null) return node;
            Thread.sleep(100);
        }
        throw new AssertionError("Missing " + text);
    }
    private AccessibilityNodeInfo find(AccessibilityNodeInfo node, String text, String type) {
        if (node == null) return null;
        if ((text.equals(String.valueOf(node.getText())) || text.equals(String.valueOf(node.getContentDescription())))
                && (type == null || type.equals(String.valueOf(node.getClassName())))) return node;
        for (int i = 0; i < node.getChildCount(); i++) { AccessibilityNodeInfo found = find(node.getChild(i), text, type); if (found != null) return found; }
        return null;
    }
    private static void check(boolean value, String message) { if (!value) throw new AssertionError(message); }
}
