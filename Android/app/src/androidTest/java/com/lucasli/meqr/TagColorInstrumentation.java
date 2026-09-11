package com.lucasli.meqr;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.view.ViewGroup;
import android.view.inspector.WindowInspector;
import android.widget.TextView;
import java.util.Arrays;
import java.util.List;

public final class TagColorInstrumentation extends Instrumentation {
    private Activity activity;
    @Override public void onCreate(Bundle args) { super.onCreate(args); start(); }
    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            check(getTargetContext().getPackageName().endsWith(".tagcolorcheck"), "Isolated package required");
            new I18n(getTargetContext()).setLanguageMode(I18n.ZH_HANS);
            activity = startActivitySync(new Intent().setClassName(getTargetContext(), "com.lucasli.meqr.MainActivity").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            waitForIdleSync();
            onMain(() -> {
                String tag = "世界计划";
                List<String> colors = Arrays.asList("#112233", "#223344", "#334455", "#445566", "#556677", "#667788");
                check(CardTagColorPalette.colorsFor(tag, null).length == 6, "Six preset colors");
                check(CardTagColorPalette.solidColorFor(tag) == 0xFF00A0E9, "Catalog solid blue");
                for (String mode : Arrays.asList("solid", "preset", "custom")) {
                    String encoded = CardTagColorPalette.encodeMode(mode, colors);
                    check(CardTagColorPalette.modeFor(tag, encoded).equals(mode), "Mode round trip");
                    check(CardTagColorPalette.customColorsFor(tag, encoded).size() == 5, "Retained custom five");
                    int[] rendered = CardTagColorPalette.colorsFor(tag, encoded);
                    check(rendered.length == (mode.equals("solid") ? 1 : mode.equals("preset") ? 6 : 5), "Render mode");
                    if (mode.equals("custom")) check(rendered[0] == 0xFF112233, "Custom overrides catalog");
                }
                check(CardTagColorPalette.colorsFor(tag, "@solid")[0] == 0xFF00A0E9, "Legacy solid");
                check(CardTagColorPalette.colorsFor(tag, "#123456")[0] == 0xFF123456, "Legacy custom");
                invoke("showEditor", new Class<?>[]{MeQrProfile.class}, new Object[]{null});
                invoke("appendTag", new Class<?>[]{String.class}, new Object[]{tag});
                invoke("appendTag", new Class<?>[]{String.class}, new Object[]{"初音未来"});
                invoke("showTagColorEditor", new Class<?>[]{String.class}, new Object[]{tag});
            });
            waitForIdleSync();
            onMain(() -> check(find("颜色 1") == null, "Default hides palette"));
            click("自定义");
            for (int i = 0; i < 4; i++) click("＋  增加颜色");
            onMain(() -> {
                check(find("颜色 5") != null, "Five rows visible");
                check(find("＋  增加颜色") == null, "Five limit");
            });
            screenshot("custom-five");
            onMain(() -> {
                android.widget.EditText hex = (android.widget.EditText) find("#00A0E9");
                check(hex != null, "HEX field exists"); hex.setText("123456");
                ((android.widget.EditText) find("#00A0E9")).setText("ABCDEF");
            });
            dragFirstColor();
            screenshot("reordered-five");
            click("复制配色到…"); click("初音未来");
            click("拼色");
            onMain(() -> check(find("颜色 1") == null, "Mixed hides palette"));
            screenshot("default-six");
            click("自定义");
            onMain(() -> check(find("颜色 5") != null, "Toggle retains colors"));
            click("保存");
            onMain(() -> {
                try {
                    java.lang.reflect.Field sessionField = MainActivity.class.getDeclaredField("editSession"); sessionField.setAccessible(true);
                    Object session = sessionField.get(activity);
                    java.lang.reflect.Field profileField = session.getClass().getDeclaredField("profile"); profileField.setAccessible(true);
                    MeQrProfile profile = (MeQrProfile) profileField.get(session);
                    check(profile.tagColors("世界计划")[0] == 0xFFABCDEF && profile.tagColors("世界计划")[1] == 0xFF123456, "HEX edit and drag saved");
                    check(profile.tagColors("初音未来")[0] == 0xFFABCDEF, "Palette copied on Save");
                    check(profile.tagColors("初音未来").length == 5, "Five-color copy");
                } catch (Exception e) { throw new RuntimeException(e); }
            });
            onMain(() -> invoke("showTagColorEditor", new Class<?>[]{String.class}, new Object[]{"世界计划"}));
            waitForIdleSync();
            onMain(() -> check(find("颜色 5") != null, "Reopen retains custom five"));
            result.putString("stream", "PASS: palette modes, legacy values, five colors, default visibility, toggle and reopen\n");
            finish(Activity.RESULT_OK, result);
        } catch (Throwable error) {
            result.putString("stream", android.util.Log.getStackTraceString(error));
            finish(Activity.RESULT_CANCELED, result);
        }
    }
    private void onMain(Runnable block) {
        Throwable[] failure = {null};
        runOnMainSync(() -> { try { block.run(); } catch (Throwable e) { failure[0] = e; } });
        if (failure[0] != null) throw new AssertionError(failure[0]);
    }
    private void dragFirstColor() throws Exception {
        float[] positions = new float[4];
        onMain(() -> {
            java.util.ArrayList<View> handles = new java.util.ArrayList<>();
            for (View window : WindowInspector.getGlobalWindowViews()) handles(window, handles);
            check(handles.size() >= 2, "Drag handles");
            for (int i = 0; i < 2; i++) {
                int[] location = new int[2]; handles.get(i).getLocationOnScreen(location);
                positions[i * 2] = location[0] + handles.get(i).getWidth() / 2f;
                positions[i * 2 + 1] = location[1] + handles.get(i).getHeight() / 2f;
            }
        });
        long start = android.os.SystemClock.uptimeMillis();
        pointer(start, android.view.MotionEvent.ACTION_DOWN, positions[0], positions[1]);
        Thread.sleep(750);
        for (int i = 1; i <= 15; i++) {
            pointer(start, android.view.MotionEvent.ACTION_MOVE, positions[0] + (positions[2] - positions[0]) * i / 15f, positions[1] + (positions[3] - positions[1]) * i / 15f);
            Thread.sleep(25);
        }
        pointer(start, android.view.MotionEvent.ACTION_UP, positions[2], positions[3]); waitForIdleSync();
    }
    private void pointer(long start, int action, float x, float y) {
        android.view.MotionEvent event = android.view.MotionEvent.obtain(start, android.os.SystemClock.uptimeMillis(), action, x, y, 0);
        event.setSource(android.view.InputDevice.SOURCE_TOUCHSCREEN);
        getUiAutomation().injectInputEvent(event, true); event.recycle();
    }
    private void handles(View view, java.util.List<View> result) {
        if (!view.isShown()) return;
        if ("调整色段顺序".contentEquals(view.getContentDescription() == null ? "" : view.getContentDescription())) result.add(view);
        if (view instanceof ViewGroup) for (int i = 0; i < ((ViewGroup) view).getChildCount(); i++) handles(((ViewGroup) view).getChildAt(i), result);
    }
    private void invoke(String method, Class<?>[] types, Object[] args) {
        try { java.lang.reflect.Method m = MainActivity.class.getDeclaredMethod(method, types); m.setAccessible(true); m.invoke(activity, args); }
        catch (Exception e) { throw new RuntimeException(e); }
    }
    private View find(String label) {
        List<View> windows = WindowInspector.getGlobalWindowViews();
        for (int i = windows.size() - 1; i >= 0; i--) { View result = find(windows.get(i), label); if (result != null) return result; }
        return null;
    }
    private View find(View view, String label) {
        if (view.getVisibility() != View.VISIBLE) return null;
        if (view instanceof TextView && ((TextView) view).getText().toString().equals(label)) return view;
        if (view instanceof ViewGroup) for (int i = 0; i < ((ViewGroup) view).getChildCount(); i++) {
            View match = find(((ViewGroup) view).getChildAt(i), label); if (match != null) return match;
        }
        return null;
    }
    private void click(String text) {
        onMain(() -> {
            View v = find(text); check(v != null, "Missing " + text);
            android.view.ViewParent parent = v.getParent();
            while (parent instanceof View && !(parent instanceof android.widget.ListView)) parent = parent.getParent();
            if (parent instanceof android.widget.ListView) {
                android.widget.ListView list = (android.widget.ListView) parent;
                int position = list.getPositionForView(v); list.performItemClick(v, position, list.getItemIdAtPosition(position));
            } else v.performClick();
        }); waitForIdleSync();
    }
    private void screenshot(String name) throws Exception {
        waitForIdleSync();
        Thread.sleep(350);
        android.graphics.Bitmap bitmap = getUiAutomation().takeScreenshot();
        try (java.io.FileOutputStream out = new java.io.FileOutputStream(new java.io.File(getTargetContext().getExternalFilesDir(null), name + ".png"))) {
            bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, out);
        }
    }
    private static void check(boolean value, String message) { if (!value) throw new AssertionError(message); }
}
