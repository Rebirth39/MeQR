package com.lucasli.meqr;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.view.ViewGroup;
import android.view.inspector.WindowInspector;
import android.widget.TextView;
import java.util.List;

public final class ToolbarInstrumentation extends Instrumentation {
    private MainActivity activity;
    @Override public void onCreate(Bundle args) { super.onCreate(args); start(); }
    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            check(getTargetContext().getPackageName().endsWith(".toolbarcheck"), "Isolated app required");
            getTargetContext().getSharedPreferences("settings", 0).edit().putBoolean("android_profile_v1", true).commit();
            new I18n(getTargetContext()).setLanguageMode(I18n.ZH_HANS);
            activity = (MainActivity) startActivitySync(new Intent().setClassName(getTargetContext(), "com.lucasli.meqr.MainActivity").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            waitForIdleSync();
            onMain(() -> {
                profiles().clear();
                activity.renderMain();
                check(find(new I18n(activity).t("scanMeQr")) != null, "Empty scan action");
                check(find(new I18n(activity).t("newProfile")) != null, "Empty add action");
            });
            screenshot("toolbar-empty");
            onMain(() -> {
                MeQrProfile profile = new MeQrProfile();
                profile.name = "Toolbar Preview";
                profiles().add(profile);
                activity.renderMain();
                I18n language = new I18n(activity);
                View scan = find(language.t("scanMeQr"));
                View share = find(language.t("meqrProfileCode"));
                View add = find(language.t("newProfile"));
                check(scan != null && share != null && add != null, "Three actions");
                check(scan.getParent() == share.getParent() && share.getParent() == add.getParent(), "Grouped actions");
            });
            screenshot("toolbar-profile");
            onMain(() -> {
                I18n l = new I18n(activity);
                View group = (View) find(l.t("scanMeQr")).getParent();
                int[] pos = new int[2]; group.getLocationOnScreen(pos);
                check(pos[0] >= 0 && pos[0] + group.getWidth() <= activity.getResources().getDisplayMetrics().widthPixels, "Toolbar fits screen");
                find(l.t("meqrProfileCode")).performClick();
            });
            waitForIdleSync();
            onMain(() -> check(find(new I18n(activity).t("encounters")) != null, "Share menu opens"));
            onMain(() -> find(new I18n(activity).t("cancel")).performClick());
            waitForIdleSync(); Thread.sleep(400);
            onMain(() -> find(new I18n(activity).t("settings")).performClick());
            waitForIdleSync();
            onMain(() -> check(find(new I18n(activity).t("cardList")) != null, "Card list retained"));
            onMain(() -> find(new I18n(activity).t("cancel")).performClick());
            waitForIdleSync(); Thread.sleep(400);
            onMain(() -> find(new I18n(activity).t("newProfile")).performClick());
            waitForIdleSync();
            onMain(() -> check(find(new I18n(activity).t("save")) != null, "Add opens editor"));
            result.putString("stream", "PASS: empty/profile toolbar, grouped actions, screen bounds, share/menu/add navigation\n");
            finish(Activity.RESULT_OK, result);
        } catch (Throwable e) {
            result.putString("stream", android.util.Log.getStackTraceString(e));
            finish(Activity.RESULT_CANCELED, result);
        }
    }
    @SuppressWarnings("unchecked") private List<MeQrProfile> profiles() {
        try { java.lang.reflect.Field f = MainActivity.class.getDeclaredField("profiles"); f.setAccessible(true); return (List<MeQrProfile>) f.get(activity); }
        catch (Exception e) { throw new RuntimeException(e); }
    }
    private void onMain(Runnable block) {
        Throwable[] failure = {null};
        runOnMainSync(() -> { try { block.run(); } catch (Throwable e) { failure[0] = e; } });
        if (failure[0] != null) throw new AssertionError(failure[0]);
    }
    private View find(String text) {
        List<View> windows = WindowInspector.getGlobalWindowViews();
        return windows.isEmpty() ? null : find(windows.get(windows.size() - 1), text);
    }
    private View find(View v, String text) {
        if (v.getVisibility() != View.VISIBLE) return null;
        if (text.contentEquals(v.getContentDescription() == null ? "" : v.getContentDescription())) return v;
        if (v instanceof TextView && text.contentEquals(((TextView) v).getText())) return v;
        if (v instanceof ViewGroup) for (int i = 0; i < ((ViewGroup) v).getChildCount(); i++) {
            View match = find(((ViewGroup) v).getChildAt(i), text); if (match != null) return match;
        }
        return null;
    }
    private void screenshot(String name) throws Exception {
        waitForIdleSync(); Thread.sleep(350);
        try (java.io.FileOutputStream out = new java.io.FileOutputStream(new java.io.File(getTargetContext().getExternalFilesDir(null), name + ".png"))) {
            getUiAutomation().takeScreenshot().compress(android.graphics.Bitmap.CompressFormat.PNG, 100, out);
        }
    }
    private static void check(boolean ok, String message) { if (!ok) throw new AssertionError(message); }
}
