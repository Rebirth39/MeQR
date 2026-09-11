package com.lucasli.meqr;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Intent;
import android.os.Bundle;
import android.view.accessibility.AccessibilityNodeInfo;
import java.util.concurrent.atomic.AtomicInteger;

public final class TagReportInstrumentation extends Instrumentation {
    @Override public void onCreate(Bundle arguments) { super.onCreate(arguments); start(); }

    @Override public void onStart() {
        Bundle result = new Bundle();
        Activity activity = null;
        try {
            Intent intent = new Intent().setClassName(getTargetContext(), "com.lucasli.meqr.MainActivity")
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity = startActivitySync(intent);
            waitForIdleSync();
            Activity host = activity;
            AtomicInteger attempts = new AtomicInteger();
            String[] requestID = {null};
            runOnMainSync(() -> {
                I18n i18n = new I18n(host);
                i18n.setLanguageMode(I18n.EN);
                TagReport.show(host, i18n, "Project Sekai", payload -> {
                    check(payload.getString("description").equals("Wrong colors"), "Description missing");
                    if (attempts.getAndIncrement() == 0) {
                        requestID[0] = payload.getString("request_id");
                        throw new java.io.IOException("Simulated network failure");
                    }
                    check(requestID[0].equals(payload.getString("request_id")), "Retry ID changed");
                    return "MEQR-20260907-ABCDEF";
                });
            });
            waitForIdleSync();
            click("Submit");
            check(attempts.get() == 0, "Empty form submitted");
            AccessibilityNodeInfo field = waitNode("Description", true);
            Bundle text = new Bundle();
            text.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, "Wrong colors");
            check(field.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, text), "Could not enter text");
            click("Submit");
            waitNode("Could not confirm submission. Your text is retained; please retry.", false);
            check(waitNode("Wrong colors", false) != null, "Failure erased input");
            click("Submit");
            waitNode("MEQR-20260907-ABCDEF", false);
            check(attempts.get() == 2, "Unexpected submit count");
            result.putString("stream", "Native Tag report: empty validation, failure retention, retry ID and receipt passed\n");
            finish(Activity.RESULT_OK, result);
        } catch (Throwable error) {
            try (java.io.FileOutputStream output = getTargetContext().openFileOutput("tag-report-failure.png", 0)) {
                getUiAutomation().takeScreenshot().compress(android.graphics.Bitmap.CompressFormat.PNG, 100, output);
            } catch (Exception ignored) { }
            result.putString("stream", "FAIL: " + error + "\n");
            finish(Activity.RESULT_CANCELED, result);
        } finally {
            if (activity != null) {
                Activity host = activity;
                runOnMainSync(host::finish);
            }
        }
    }

    private void click(String text) throws Exception {
        check(waitNode(text, false).performAction(AccessibilityNodeInfo.ACTION_CLICK), "Click failed: " + text);
        waitForIdleSync();
    }

    private AccessibilityNodeInfo waitNode(String text, boolean editable) throws Exception {
        for (int i = 0; i < 50; i++) {
            AccessibilityNodeInfo node = find(getUiAutomation().getRootInActiveWindow(), text, editable);
            if (node != null) return node;
            Thread.sleep(100);
        }
        throw new AssertionError("Missing: " + text);
    }

    private AccessibilityNodeInfo find(AccessibilityNodeInfo node, String text, boolean editable) {
        if (node == null) return null;
        if ((!editable || node.isEditable()) && (text.equalsIgnoreCase(node.getText() == null ? "" : node.getText().toString())
                || text.contentEquals(node.getHintText() == null ? "" : node.getHintText()))) return node;
        for (int i = 0; i < node.getChildCount(); i++) {
            AccessibilityNodeInfo found = find(node.getChild(i), text, editable);
            if (found != null) return found;
        }
        return null;
    }

    private static void check(boolean value, String message) { if (!value) throw new AssertionError(message); }
}
