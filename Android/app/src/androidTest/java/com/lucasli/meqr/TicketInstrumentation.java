package com.lucasli.meqr;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Intent;
import android.os.Bundle;
import android.view.KeyEvent;
import android.view.accessibility.AccessibilityNodeInfo;

public final class TicketInstrumentation extends Instrumentation {
    private Activity activity;
    @Override public void onCreate(Bundle args) { super.onCreate(args); start(); }
    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            check(getTargetContext().getPackageName().endsWith(".ticketcheck"), "Use isolated test package only");
            policyTests();
            getTargetContext().getSharedPreferences("settings", 0).edit().clear().commit();
            new I18n(getTargetContext()).setLanguageMode(I18n.EN);
            java.io.File data = new java.io.File(getTargetContext().getFilesDir(), "profiles.json");
            data.delete();
            launch();
            click("Start My Card");
            setText("Profile Name", "Ticket Test");
            click("Continue");
            waitNode("Add your first platform");
            sendKeyDownUpSync(KeyEvent.KEYCODE_BACK);
            waitNode("Introduce yourself");
            waitNode("Ticket Test");
            check(!getTargetContext().getSharedPreferences("settings", 0).getBoolean("android_profile_v1", false), "Premature completion");
            // Activity destruction and restart must restore the incomplete draft.
            runOnMainSync(() -> { callActivityOnPause(activity); callActivityOnStop(activity); activity.finish(); });
            waitForIdleSync();
            launch();
            waitNode("Ticket Test");
            click("Continue");
            setText("QR Content", "https://example.com");
            click("Custom");
            click("Common Apps");
            screenshot("ticket-android-platform-picker");
            click("QQ");
            waitNode("This does not match the platform's usual link format. Check it; original content can still be saved.\nFor QQ / WeChat, import the official personal QR code. An account number is not an add-friend link.");
            screenshot("ticket-android-platform");
            click("Continue");
            waitNode("Choose your card style");
            click("Continue");
            Thread.sleep(400);
            click("Continue");
            waitNode("Your first card is ready");
            click("Finish Setup");
            check(getTargetContext().getSharedPreferences("settings", 0).getBoolean("android_profile_v1", false), "Completion not saved");
            sendKeyDownUpSync(KeyEvent.KEYCODE_BACK);
            waitNode("Ticket Test");
            click("Ticket Test");
            sendKeyDownUpSync(KeyEvent.KEYCODE_BACK);
            check((Boolean) field("showingCardList"), "Pager Back did not show list");
            screenshot("ticket-android-list");
            runOnMainSync(() -> invoke("showEditor", new Class<?>[]{MeQrProfile.class}, new Object[]{null}));
            waitForIdleSync();
            waitNode("New Profile");
            Thread.sleep(400);
            sendKeyDownUpSync(KeyEvent.KEYCODE_BACK);
            waitNode("Discard unsaved changes?");
            click("Cancel");
            check(field("editSession") != null, "Cancel discarded editor");
            // A directory at the atomic-file staging path forces storage failure.
            java.io.File staging = new java.io.File(data.getPath() + ".new");
            check(staging.mkdir(), "Could not inject failed save");
            click("Save");
            check(field("editSession") != null, "Failed save dismissed editor");
            staging.delete();
            check(new ProfileStore(getTargetContext()).load().size() == 1, "Failed save lost stored card");
            sendKeyDownUpSync(KeyEvent.KEYCODE_BACK);
            click("Delete");
            runOnMainSync(() -> invoke("reviewQRLink", new Class<?>[]{String.class}, new Object[]{"javascript:alert(1)"}));
            waitNode("Check the full content and domain below. Open only if you trust the source.\n\njavascript:alert(1)\n\n" + new I18n(getTargetContext()).t("qrFormatWarning"));
            check(find(getUiAutomation().getRootInActiveWindow(), "Open Link") == null, "Dangerous QR is openable");
            screenshot("ticket-android-qr-review");
            click("Cancel");
            result.putString("stream", "PASS: QR policy, step Back, draft restart, platform picker, completion, card list, discard and failed-save retention\n");
            finish(Activity.RESULT_OK, result);
        } catch (Throwable error) {
            screenshot("ticket-android-failure");
            result.putString("stream", "FAIL: " + error + "\n");
            finish(Activity.RESULT_CANCELED, result);
        } finally { if (activity != null) runOnMainSync(activity::finish); }
    }
    private void policyTests() {
        for (String value : new String[]{"javascript:alert(1)", "intent://scan", "weixin://scanqrcode", "https://qq.com@evil.test", "https://", "https://qq.com/a b"})
            check(QRLinkPolicy.webURL(value) == null, value);
        for (String value : new String[]{"https://qm.qq.com.evil.test/q/abc", "https://evil.test/?qq.com", "https://notx.com"})
            check(QRLinkPolicy.platformID(value).equals("custom"), value);
        check(QRLinkPolicy.platformID("HTTPS://QM.QQ.COM/q/abc").equals("qq"), "Case folding");
        check(QRLinkPolicy.platformID("https://weixin.qq.com/abc").equals("wechat"), "WeChat precedence");
        for (String value : new String[]{"https://qm.qq.com/q/abc", "https://qm.qq.com/cgi-bin/qm/qr?k=abc"})
            check(QRLinkPolicy.warningKey(value, "qq") == null, value);
        for (String value : new String[]{"123456", "https://qq.com", "https://qm.qq.com/q/", "https://qm.qq.com/cgi-bin/qm/qr?k="})
            check("qrFormatWarning".equals(QRLinkPolicy.warningKey(value, "qq")), value);
        check(QRLinkPolicy.warningKey("plain custom text", "custom") == null, "Custom text");
        for (String value : new String[]{"http://example.com", "https://127.0.0.1", "https://[::1]"})
            check("qrDestinationWarning".equals(QRLinkPolicy.warningKey(value, "custom")), value);
    }
    private void launch() { activity = startActivitySync(new Intent().setClassName(getTargetContext(), "com.lucasli.meqr.MainActivity").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); waitForIdleSync(); }
    private Object field(String name) throws Exception { java.lang.reflect.Field f = MainActivity.class.getDeclaredField(name); f.setAccessible(true); return f.get(activity); }
    private void invoke(String name, Class<?>[] types, Object[] args) {
        try { java.lang.reflect.Method m = MainActivity.class.getDeclaredMethod(name, types); m.setAccessible(true); m.invoke(activity, args); }
        catch (Exception error) { throw new RuntimeException(error); }
    }
    private void setText(String hint, String value) throws Exception {
        Bundle args = new Bundle(); args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, value);
        check(waitNode(hint).performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args), "Set text " + hint); waitForIdleSync();
    }
    private void click(String text) throws Exception {
        for (int i = 0; i < 10; i++) {
            waitNode(text);
            AccessibilityNodeInfo target = findClickable(getUiAutomation().getRootInActiveWindow(), text);
            if (target != null && target.performAction(AccessibilityNodeInfo.ACTION_CLICK)) { waitForIdleSync(); Thread.sleep(300); return; }
            Thread.sleep(100);
        }
        throw new AssertionError("Click " + text);
    }
    private AccessibilityNodeInfo findClickable(AccessibilityNodeInfo node, String text) {
        if (node == null) return null;
        if (node.isClickable() && (text.equalsIgnoreCase(String.valueOf(node.getText())) || text.equalsIgnoreCase(String.valueOf(node.getContentDescription())))) return node;
        for (int i = 0; i < node.getChildCount(); i++) { AccessibilityNodeInfo n = findClickable(node.getChild(i), text); if (n != null) return n; }
        return null;
    }
    private AccessibilityNodeInfo waitNode(String text) throws Exception {
        for (int i = 0; i < 60; i++) { AccessibilityNodeInfo n = find(getUiAutomation().getRootInActiveWindow(), text); if (n != null) return n; Thread.sleep(100); }
        throw new AssertionError("Missing: " + text);
    }
    private AccessibilityNodeInfo find(AccessibilityNodeInfo node, String text) {
        if (node == null) return null;
        if (text.equalsIgnoreCase(String.valueOf(node.getText())) || text.equalsIgnoreCase(String.valueOf(node.getContentDescription())) || text.equalsIgnoreCase(String.valueOf(node.getHintText()))) return node;
        for (int i = 0; i < node.getChildCount(); i++) { AccessibilityNodeInfo n = find(node.getChild(i), text); if (n != null) return n; }
        return null;
    }
    private void screenshot(String name) {
        try (java.io.FileOutputStream out = getTargetContext().openFileOutput(name + ".png", 0)) { getUiAutomation().takeScreenshot().compress(android.graphics.Bitmap.CompressFormat.PNG, 100, out); } catch (Exception ignored) { }
    }
    private static void check(boolean value, String message) { if (!value) throw new AssertionError(message); }
}
