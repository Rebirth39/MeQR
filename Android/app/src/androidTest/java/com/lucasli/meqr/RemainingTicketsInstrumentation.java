package com.lucasli.meqr;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Intent;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.drawable.BitmapDrawable;
import android.os.Bundle;
import android.os.SystemClock;
import android.text.StaticLayout;
import android.text.TextPaint;
import android.view.View;
import android.view.MotionEvent;
import android.view.ViewGroup;
import android.view.inspector.WindowInspector;
import android.widget.EditText;
import android.widget.ImageView;
import android.widget.TextView;
import java.io.File;
import java.io.FileOutputStream;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

public final class RemainingTicketsInstrumentation extends Instrumentation {
    private MainActivity activity;
    private I18n language;
    private boolean baseline;
    private final StringBuilder log = new StringBuilder();

    @Override public void onCreate(Bundle arguments) {
        super.onCreate(arguments);
        baseline = arguments != null && "true".equals(arguments.getString("baseline"));
        start();
    }

    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            check(getTargetContext().getPackageName().endsWith(".tickets20261007"), "Isolated test package required");
            getTargetContext().getSharedPreferences("settings", 0).edit().clear()
                    .putBoolean("android_profile_v1", true).putString("legal_ack_version", "2026-09-16").commit();
            language = new I18n(getTargetContext());
            language.setLanguageMode(I18n.ZH_HANS);
            MeQrProfile fixture = new MeQrProfile();
            fixture.name = "Ticket regression";
            fixture.subtitle = "Initial introduction";
            fixture.qrItems.get(0).qrContent = "https://example.com/ticket-regression";
            Bitmap avatar = Bitmap.createBitmap(1200, 1200, Bitmap.Config.ARGB_8888);
            avatar.eraseColor(Color.BLUE);
            File image = new File(getTargetContext().getFilesDir(), "fixture-avatar.png");
            try (FileOutputStream output = new FileOutputStream(image)) {
                avatar.compress(Bitmap.CompressFormat.PNG, 100, output);
            }
            avatar.recycle();
            fixture.avatarPath = image.getAbsolutePath();
            new ProfileStore(getTargetContext()).save(Collections.singletonList(fixture));
            activity = (MainActivity) startActivitySync(new Intent().setClassName(getTargetContext(),
                    MainActivity.class.getName()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            waitForIdleSync();
            main(() -> invoke("showEditor", new Class<?>[]{MeQrProfile.class},
                    ((List<?>) field(activity, "profiles")).get(0)));
            waitForIdleSync();
            checkThemes();
            checkTyping();
            checkIntroduction(fixture);
            log.append("PASS all three remaining ticket regressions\n");
            result.putString("stream", log.toString());
            finish(Activity.RESULT_OK, result);
        } catch (Throwable error) {
            result.putString("stream", log + android.util.Log.getStackTraceString(error));
            finish(Activity.RESULT_CANCELED, result);
        }
    }

    private void checkThemes() throws Exception {
        for (boolean systemDark : new boolean[]{true, false}) {
            for (boolean appDark : new boolean[]{false, true}) {
                main(() -> {
                    Configuration configuration = new Configuration(activity.getResources().getConfiguration());
                    configuration.uiMode = (configuration.uiMode & ~Configuration.UI_MODE_NIGHT_MASK)
                            | (systemDark ? Configuration.UI_MODE_NIGHT_YES : Configuration.UI_MODE_NIGHT_NO);
                    activity.getResources().updateConfiguration(configuration, activity.getResources().getDisplayMetrics());
                    invoke("setDarkTheme", new Class<?>[]{boolean.class}, appDark);
                    invoke("showTagLibrary", new Class<?>[]{});
                });
                waitForIdleSync();
                main(() -> {
                    TextView title = find(language.t("tagLibrary"));
                    double ratio = contrast(title.getCurrentTextColor(), Ui.BG);
                    log.append("Tag library: systemDark=").append(systemDark).append(" appDark=")
                            .append(appDark).append(" contrast=").append(ratio).append('\n');
                    if (baseline) check(ratio < 4.5 || appDark, "Baseline light title defect should reproduce");
                    else check(ratio >= 4.5, "Readable Tag library title");
                    find(language.t("done")).performClick();
                    invoke("showTagColorEditor", new Class<?>[]{String.class}, "custom-color-fixture");
                });
                waitForIdleSync();
                main(() -> {
                    double ratio = contrast(find(language.t("editTagColors")).getCurrentTextColor(), Ui.BG);
                    log.append("Tag color editor contrast=").append(ratio).append('\n');
                    if (!baseline) check(ratio >= 4.5, "Readable Tag color title");
                });
                screenshot((baseline ? "before-" : "after-") + "dialog-" + systemDark + "-" + appDark);
                main(() -> find(language.t("cancel")).performClick());
                waitForIdleSync();
                if (baseline) return;
            }
        }
        main(() -> invoke("setDarkTheme", new Class<?>[]{boolean.class}, false));
        log.append("PASS dialog theme matrix: system dark/light x app dark/light\n");
    }

    private void checkTyping() {
        int[] redraws = {0};
        long[] elapsed = {0};
        main(() -> {
            EditText introduction = (EditText) field(session(), "subtitle");
            ImageView preview = (ImageView) field(session(), "preview");
            Bitmap previous = ((BitmapDrawable) preview.getDrawable()).getBitmap();
            long started = SystemClock.elapsedRealtime();
            for (int index = 0; index < 20; index++) {
                introduction.setText("输入性能测试 " + index + "\nEmoji 👩‍💻 multiline introduction");
                Bitmap current = ((BitmapDrawable) preview.getDrawable()).getBitmap();
                if (current != previous) redraws[0]++;
                previous = current;
            }
            elapsed[0] = SystemClock.elapsedRealtime() - started;
        });
        log.append("20 text updates: synchronous redraws=").append(redraws[0])
                .append(" elapsedMs=").append(elapsed[0]).append('\n');
        if (baseline) {
            check(redraws[0] == 20, "Baseline redraw-per-keystroke should reproduce");
            return;
        }
        check(redraws[0] == 0, "Typing must not synchronously render card or decode avatar");
        SystemClock.sleep(1000);
        waitForIdleSync();
        main(() -> {
            check(field(activity, "pendingPreview") == null, "Debounced preview completed");
            check(((MeQrProfile) field(session(), "profile")).subtitle.contains("19"), "Preview contains latest input");
            ((EditText) field(session(), "subtitle")).setText("Saved before preview delay 👩‍💻\nLast line");
            find(language.t("save")).performClick();
        });
        waitForIdleSync();
        main(() -> check(field(activity, "pendingPreview") == null, "Dismiss cancels queued work"));
        List<MeQrProfile> saved = new ProfileStore(getTargetContext()).load();
        check(saved.get(0).subtitle.equals("Saved before preview delay 👩‍💻\nLast line"), "Immediate save retains all input");
        SystemClock.sleep(300);
        main(() -> check(field(activity, "editSession") == null, "No stale editor update after dismissal"));
        log.append("PASS debounced input, latest preview, immediate save, callback cleanup\n");
    }

    private void checkIntroduction(MeQrProfile fixture) throws Exception {
        if (baseline) {
            TextPaint paint = new TextPaint();
            paint.setTextSize(15f);
            StaticLayout layout = StaticLayout.Builder.obtain(lines(30), 0, lines(30).length(), paint, 288)
                    .setMaxLines(10).setEllipsize(android.text.TextUtils.TruncateAt.END).build();
            log.append("Baseline intro text height=").append(layout.getHeight()).append(" content panel height=180\n");
            check(layout.getHeight() > 180, "Baseline introduction spills outside padded panel");
        } else {
            Class<?> helper = Class.forName("com.lucasli.meqr.BioTextLayout");
            Method create = helper.getDeclaredMethod("create", String.class, int.class, int.class, float.class, int.class);
            create.setAccessible(true);
            for (int width : new int[]{288, 576, 720}) {
                float density = width / 288f;
                for (String text : Arrays.asList("Short introduction", lines(10), lines(30), lines(400),
                        "Emoji 👩‍💻 🇨🇳 こんにちは 中文 English\n\n终行", "LongWordWithoutSpaces".repeat(600))) {
                    StaticLayout layout = (StaticLayout) create.invoke(null, text, width, (int) (158 * density), density, Color.BLACK);
                    check(layout.getHeight() <= (int) (158 * density), "Introduction stays within panel");
                    check(layout.getPaint().getTextSize() >= 12 * density, "Minimum readable font size");
                    if (text.equals(lines(400))) check(layout.getEllipsisCount(layout.getLineCount() - 1) > 0, "Overflow visibly ellipsized");
                }
            }
            fixture.subtitle = lines(400);
            main(() -> invoke("showFullBio", new Class<?>[]{MeQrProfile.class}, fixture));
            waitForIdleSync();
            main(() -> {
                TextView full = find(fixture.subtitle);
                check(full.isTextSelectable(), "Full introduction selectable");
                check(full.getParent() instanceof android.widget.ScrollView, "Full introduction scrollable");
                find(language.t("done")).performClick();
            });
            log.append("PASS short/10/30/400 lines, mixed scripts, emoji, long unbroken text; full text retained\n");
            checkBioTap(fixture.subtitle);
        }
        for (String template : new String[]{"standard", "rhodes"}) {
            fixture.template = template;
            fixture.subtitle = lines(30);
            Bitmap front = CardRenderer.render(fixture, language, 720);
            Bitmap back = CardRenderer.renderBack(fixture, language, 720);
            check(front.getHeight() == back.getHeight(), "Same front/back size");
            try (FileOutputStream output = getTargetContext().openFileOutput(
                    (baseline ? "before-" : "after-") + "intro-" + template + ".png", 0)) {
                back.compress(Bitmap.CompressFormat.PNG, 100, output);
            }
            front.recycle();
            back.recycle();
        }
    }

    private static String lines(int count) {
        StringBuilder text = new StringBuilder();
        for (int index = 0; index < count; index++) {
            if (index > 0) text.append('\n');
            text.append("介绍行 ").append(index).append(" / Introduction 👩‍💻");
        }
        return text.toString();
    }

    private void checkBioTap(String introduction) {
        main(() -> {
            MeQrProfile card = (MeQrProfile) ((List<?>) field(activity, "profiles")).get(0);
            card.subtitle = introduction;
            invoke("renderMain", new Class<?>[]{});
        });
        waitForIdleSync();
        SystemClock.sleep(300);
        tapCard(language.t("viewBack"), 180, 400);
        waitForIdleSync();
        SystemClock.sleep(200);
        tapCard(language.t("viewFront") + ". " + language.t("viewFullBio"), 180, 200);
        waitForIdleSync();
        main(() -> {
            TextView text = find(introduction);
            check(text.getText().toString().equals(introduction), "Card tap opens entire introduction");
            android.widget.ScrollView scroll = (android.widget.ScrollView) text.getParent();
            scroll.scrollTo(0, text.getHeight());
            find(language.t("done")).performClick();
        });
        waitForIdleSync();
        main(() -> check(image(language.t("viewFront") + ". " + language.t("viewFullBio")).performLongClick(),
                "Long-click introduction action available"));
        waitForIdleSync();
        main(() -> { find(introduction); find(language.t("done")).performClick(); });
        log.append("PASS real card flip, introduction-region touch, scrollable full text, accessibility long-click\n");
    }

    private void tapCard(String description, float horizontal, float vertical) {
        float[] point = {0, 0};
        main(() -> {
            ImageView card = image(description);
            float scale = card.getDrawable().getIntrinsicWidth() / 360f;
            point[0] = horizontal * scale;
            point[1] = vertical * scale;
            card.getImageMatrix().mapPoints(point);
            int[] location = new int[2];
            card.getLocationOnScreen(location);
            point[0] += location[0] + card.getPaddingLeft();
            point[1] += location[1] + card.getPaddingTop();
        });
        long started = SystemClock.uptimeMillis();
        sendPointerSync(MotionEvent.obtain(started, started, MotionEvent.ACTION_DOWN, point[0], point[1], 0));
        sendPointerSync(MotionEvent.obtain(started, started + 60, MotionEvent.ACTION_UP, point[0], point[1], 0));
    }

    private ImageView image(String description) {
        for (View root : WindowInspector.getGlobalWindowViews()) {
            ImageView result = imageIn(root, description);
            if (result != null) return result;
        }
        throw new AssertionError("Missing card image: " + description);
    }

    private ImageView imageIn(View view, String description) {
        if (view instanceof ImageView && description.contentEquals(view.getContentDescription() == null
                ? "" : view.getContentDescription())) return (ImageView) view;
        if (view instanceof ViewGroup) {
            ViewGroup group = (ViewGroup) view;
            for (int index = 0; index < group.getChildCount(); index++) {
                ImageView result = imageIn(group.getChildAt(index), description);
                if (result != null) return result;
            }
        }
        return null;
    }

    private Object session() { return field(activity, "editSession"); }
    private void main(Runnable action) {
        Throwable[] error = {null};
        runOnMainSync(() -> { try { action.run(); } catch (Throwable failure) { error[0] = failure; } });
        if (error[0] != null) throw new AssertionError(error[0]);
    }
    private Object invoke(String name, Class<?>[] types, Object... arguments) {
        try { Method method = MainActivity.class.getDeclaredMethod(name, types); method.setAccessible(true); return method.invoke(activity, arguments); }
        catch (Exception error) { throw new AssertionError(error); }
    }
    private Object field(Object object, String name) {
        try { Field field = object.getClass().getDeclaredField(name); field.setAccessible(true); return field.get(object); }
        catch (Exception error) { throw new AssertionError(error); }
    }
    private TextView find(String text) {
        List<View> roots = WindowInspector.getGlobalWindowViews();
        for (int index = roots.size() - 1; index >= 0; index--) {
            TextView match = findIn(roots.get(index), text);
            if (match != null) return match;
        }
        throw new AssertionError("Missing text: " + text);
    }
    private TextView findIn(View view, String text) {
        if (view instanceof TextView && ((TextView) view).getText().toString().equals(text)) return (TextView) view;
        if (view instanceof ViewGroup) {
            ViewGroup group = (ViewGroup) view;
            for (int index = 0; index < group.getChildCount(); index++) {
                TextView match = findIn(group.getChildAt(index), text);
                if (match != null) return match;
            }
        }
        return null;
    }
    private void screenshot(String name) throws Exception {
        SystemClock.sleep(200);
        Bitmap bitmap = getUiAutomation().takeScreenshot();
        try (FileOutputStream output = getTargetContext().openFileOutput(name + ".png", 0)) {
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, output);
        }
    }
    private static double contrast(int foreground, int background) {
        double first = luminance(foreground), second = luminance(background);
        return (Math.max(first, second) + .05) / (Math.min(first, second) + .05);
    }
    private static double luminance(int color) {
        double[] channels = {Color.red(color) / 255., Color.green(color) / 255., Color.blue(color) / 255.};
        for (int index = 0; index < channels.length; index++) channels[index] = channels[index] <= .04045
                ? channels[index] / 12.92 : Math.pow((channels[index] + .055) / 1.055, 2.4);
        return .2126 * channels[0] + .7152 * channels[1] + .0722 * channels[2];
    }
    private static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }
}
