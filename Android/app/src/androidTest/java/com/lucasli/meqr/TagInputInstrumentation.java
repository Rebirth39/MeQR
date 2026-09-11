package com.lucasli.meqr;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Intent;
import android.graphics.Rect;
import android.os.Bundle;
import android.view.View;
import android.view.ViewGroup;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import java.util.List;

public final class TagInputInstrumentation extends Instrumentation {
    private Activity activity;
    @Override public void onCreate(Bundle args) { super.onCreate(args); start(); }
    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            check(getTargetContext().getPackageName().endsWith(".taginputcheck"), "Isolated package required");
            getTargetContext().getSharedPreferences("settings", 0).edit().putBoolean("android_profile_v1", true).commit();
            new I18n(getTargetContext()).setLanguageMode(I18n.ZH_HANS);
            activity = startActivitySync(new Intent().setClassName(getTargetContext(), "com.lucasli.meqr.MainActivity").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            waitForIdleSync();
            runOnMainSync(() -> invoke("showEditor", new Class<?>[]{MeQrProfile.class}, new Object[]{null}));
            waitForIdleSync();
            enter("初音未来"); enter("世界计划"); enter("Wonderlands x Showtime"); enter("MyGO!!!!!"); enter("高松灯"); enter("maimai"); enter("maimai 14500+");
            runOnMainSync(() -> {
                check(tags().size() == 7, "Missing entered tags");
                check(input().length() == 0, "Committed text still visible");
                check(CardTagColorPalette.colorsFor("世界计划", null).length == 6, "Sekai is not six colors");
                input().setText("unfinished draft");
                invoke("appendTag", new Class<?>[]{String.class}, new Object[]{"Custom library tag"});
                check(input().getText().toString().equals("unfinished draft"), "Library erased draft");
                input().setText("");
                invoke("writeTags", new Class<?>[]{List.class}, new Object[]{tags().subList(0, 7)});
                View section = (View) chips().getParent();
                section.requestRectangleOnScreen(new Rect(0, 0, section.getWidth(), section.getHeight()), true);
                android.view.ViewParent parent = section.getParent();
                while (parent instanceof View && !(parent instanceof ScrollView)) parent = parent.getParent();
                if (parent instanceof ScrollView) ((ScrollView) parent).scrollBy(0, Math.round(220 * activity.getResources().getDisplayMetrics().density));
            });
            waitForIdleSync(); Thread.sleep(300);
            runOnMainSync(() -> assertLayout(chips()));
            screenshot("android-tag-input-seven");
            // The production chip drag listeners must reorder while preserving the draft.
            dragFirstToLast();
            runOnMainSync(() -> {
                check(!tags().get(0).equals("初音未来"), "Drag did not reorder");
                check(tags().size() == 7, "Drag lost tags");
                LinearLayout chip = (LinearLayout) chips().getChildAt(0);
                chip.getChildAt(1).performClick();
                check(tags().size() == 6, "Remove failed");
            });
            enter("初音未来");
            check(tags().size() == 6, "Duplicate created another chip");
            enter("A,B,C,D,E");
            runOnMainSync(() -> {
                check(tags().size() == 10, "Limit not enforced");
                check(input().getText().toString().equals("E"), "Overflow input lost");
                ((LinearLayout) chips().getChildAt(0)).getChildAt(1).performClick();
                input().onEditorAction(android.view.inputmethod.EditorInfo.IME_ACTION_DONE);
                check(tags().size() == 10 && input().length() == 0, "Retry after removal failed");
                input().setText("");
                invoke("writeTags", new Class<?>[]{List.class}, new Object[]{java.util.Arrays.asList("初音未来", "世界计划", "Wonderlands x Showtime", "MyGO!!!!!", "高松灯", "maimai", "maimai 14500+")});
                input().setText("Save pending draft");
                check((Boolean) invoke("saveEdit", new Class<?>[]{}, new Object[]{}), "Save failed");
                check(new ProfileStore(getTargetContext()).load().stream().anyMatch(p -> p.tags.contains("Save pending draft")), "Save lost pending tag");
            });
            // Measure the actual chip renderer at narrow and normal widths, including long names.
            runOnMainSync(() -> {
                invoke("writeTags", new Class<?>[]{List.class}, new Object[]{java.util.Arrays.asList("LongCustomTagWithoutSpacesThatMustStayInsideTheForm", "世界计划", "maimai")});
                for (int width : new int[]{240, 320, 380}) {
                    int pixels = Math.round(width * activity.getResources().getDisplayMetrics().density);
                    chips().measure(View.MeasureSpec.makeMeasureSpec(pixels, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED));
                    chips().layout(0, 0, pixels, chips().getMeasuredHeight());
                    assertLayout(chips());
                }
            });
            result.putString("stream", "PASS: Return commits, seven-chip flow, six colors, library draft retention, drag, delete, dedup, limit/retry, save draft, narrow/long labels\n");
            finish(Activity.RESULT_OK, result);
        } catch (Throwable error) {
            screenshot("android-tag-input-failure");
            result.putString("stream", "FAIL: " + error + "\n"); finish(Activity.RESULT_CANCELED, result);
        } finally { if (activity != null) runOnMainSync(activity::finish); }
    }
    private void enter(String value) {
        runOnMainSync(() -> { input().setText(value); input().onEditorAction(android.view.inputmethod.EditorInfo.IME_ACTION_DONE); });
        waitForIdleSync();
    }
    private void dragFirstToLast() throws Exception {
        int[][] points = {new int[2], new int[2]};
        runOnMainSync(() -> {
            View first = chips().getChildAt(0), last = chips().getChildAt(chips().getChildCount() - 1);
            first.getLocationOnScreen(points[0]); last.getLocationOnScreen(points[1]);
            points[0][0] += 12; points[0][1] += first.getHeight() / 2;
            points[1][0] += 12; points[1][1] += last.getHeight() / 2;
        });
        long down = android.os.SystemClock.uptimeMillis();
        pointer(down, android.view.MotionEvent.ACTION_DOWN, points[0][0], points[0][1]);
        Thread.sleep(800);
        for (int i = 1; i <= 20; i++) {
            pointer(down, android.view.MotionEvent.ACTION_MOVE, points[0][0] + (points[1][0] - points[0][0]) * i / 20f,
                    points[0][1] + (points[1][1] - points[0][1]) * i / 20f);
            Thread.sleep(30);
        }
        pointer(down, android.view.MotionEvent.ACTION_UP, points[1][0], points[1][1]);
        waitForIdleSync(); Thread.sleep(200);
    }
    private void pointer(long down, int action, float x, float y) {
        android.view.MotionEvent e = android.view.MotionEvent.obtain(down, android.os.SystemClock.uptimeMillis(), action, x, y, 0);
        e.setSource(android.view.InputDevice.SOURCE_TOUCHSCREEN);
        check(getUiAutomation().injectInputEvent(e, true), "Pointer injection failed"); e.recycle();
    }
    @Override public void runOnMainSync(Runnable action) {
        Throwable[] failure = {null};
        super.runOnMainSync(() -> { try { action.run(); } catch (Throwable e) { failure[0] = e; } });
        if (failure[0] != null) throw new AssertionError(failure[0]);
    }
    private void assertLayout(LinearLayout flow) {
        float density = activity.getResources().getDisplayMetrics().density;
        int previousRight = 0, previousTop = -1;
        for (int i = 0; i < flow.getChildCount(); i++) {
            View chip = flow.getChildAt(i);
            check(chip.getWidth() > 0 && chip.getRight() <= flow.getWidth(), "Chip exceeds form");
            check(chip.getHeight() <= Math.round(29 * density), "Chip too tall");
            if (chip.getTop() == previousTop) check(Math.abs(chip.getLeft() - previousRight - Math.round(6 * density)) <= 1, "Wrong gap");
            else check(chip.getLeft() == 0, "Not leading aligned");
            previousRight = chip.getRight(); previousTop = chip.getTop();
        }
    }
    private Object session() { return field(activity, "editSession"); }
    private EditText input() { return (EditText) field(session(), "tags"); }
    private LinearLayout chips() { return (LinearLayout) field(session(), "tagChips"); }
    private List<String> tags() { return new java.util.ArrayList<>(((MeQrProfile) field(session(), "profile")).tags); }
    private Object field(Object object, String name) {
        try { java.lang.reflect.Field f = object.getClass().getDeclaredField(name); f.setAccessible(true); return f.get(object); }
        catch (Exception e) { throw new RuntimeException(e); }
    }
    private Object invoke(String name, Class<?>[] types, Object[] args) {
        try { java.lang.reflect.Method m = MainActivity.class.getDeclaredMethod(name, types); m.setAccessible(true); return m.invoke(activity, args); }
        catch (Exception e) { throw new RuntimeException(e); }
    }
    private void screenshot(String name) {
        try (java.io.FileOutputStream out = getTargetContext().openFileOutput(name + ".png", 0)) { getUiAutomation().takeScreenshot().compress(android.graphics.Bitmap.CompressFormat.PNG, 100, out); } catch (Exception ignored) { }
    }
    private static void check(boolean condition, String message) { if (!condition) throw new AssertionError(message); }
}
