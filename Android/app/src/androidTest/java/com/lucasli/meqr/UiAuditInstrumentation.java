package com.lucasli.meqr;

import android.app.Activity;
import android.app.Dialog;
import android.app.Instrumentation;
import android.content.Intent;
import android.os.Bundle;
import android.provider.MediaStore;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.inspector.WindowInspector;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;
import java.util.ArrayList;
import java.util.List;

public final class UiAuditInstrumentation extends Instrumentation {
    private MainActivity activity;
    private I18n language;

    @Override public void onCreate(Bundle args) { super.onCreate(args); start(); }

    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            check(getTargetContext().getPackageName().endsWith(".uxauditregression"), "Isolated test package required");
            language = new I18n(getTargetContext());
            language.setLanguageMode(I18n.ZH_HANS);
            getTargetContext().getSharedPreferences("settings", 0).edit()
                    .remove("android_profile_v1").remove("onboardingDraft").commit();
            new ProfileStore(getTargetContext()).save(new ArrayList<>());
            activity = (MainActivity) startActivitySync(new Intent().setClassName(getTargetContext(), MainActivity.class.getName())
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            waitForIdleSync();
            click("setupStart");
            onMain(() -> ((EditText) field(session(), "name")).setText("UI Audit"));
            galleryIntents();
            click("continue");
            click("continue");
            onMain(() -> {
                check(find(language.t("bannerImage") + " · " + language.t("chooseImage")) == null, "Standard hides banner");
                find(language.t("rhodesTemplate")).performClick();
                check(find(language.t("bannerImage") + " · " + language.t("chooseImage")) != null, "Rhodes offers banner");
                find(language.t("standardTemplate")).performClick();
                check(find(language.t("bannerImage") + " · " + language.t("chooseImage")) == null, "Switching back hides banner");
                find(language.t("rhodesTemplate")).performClick();
            });
            onMain(this::checkTemplateLayout);
            pass("Template selection toggles banner upload");
            click("continue");
            onMain(() -> {
                input().setText("miku");
                LinearLayout suggestions = suggestions();
                check(suggestions.getChildCount() > 0, "Typing searches the catalog");
                suggestions.getChildAt(0).performClick();
                check(profile().tags.contains("初音未来"), "Suggestion adds canonical tag");
                check(input().length() == 0 && suggestions.getChildCount() == 0, "Selection clears draft and suggestions");
                input().setText("audit-custom-unique");
                check(suggestions.getChildCount() == 0, "Custom tag has no false suggestion");
                input().onEditorAction(android.view.inputmethod.EditorInfo.IME_ACTION_DONE);
                check(profile().tags.contains("audit-custom-unique"), "Return adds custom tag");
            });
            pass("Live tag search, canonical selection and custom Return submission");
            onMain(() -> {
                input().setText("sekai");
                invoke("showTagLibrary", new Class<?>[]{});
            });
            waitForIdleSync();
            onMain(() -> check(find("sekai") instanceof EditText, "Library starts with draft query"));
            click("done");
            onMain(() -> {
                check(input().getText().toString().equals("sekai"), "Browsing retains draft");
                input().setText("tag1,tag2,tag3,tag4,tag5,tag6,tag7,tag8,overflow");
                check(profile().tags.size() == 10, "Tag limit enforced");
                check(input().getText().toString().equals("overflow"), "Overflow retained");
                LinearLayout chips = (LinearLayout) field(session(), "tagChips");
                ((LinearLayout) chips.getChildAt(0)).getChildAt(1).performClick();
                input().onEditorAction(android.view.inputmethod.EditorInfo.IME_ACTION_DONE);
                check(profile().tags.size() == 10 && input().length() == 0, "Removal allows overflow retry");
            });
            pass("Library query retention, ten-tag limit and overflow retry");
            click("continue");
            click("finishSetup");
            sendKeyDownUpSync(KeyEvent.KEYCODE_BACK);
            waitForIdleSync();
            onMain(() -> {
                check(session() == null, "Back closes completed onboarding");
                check(!(Boolean) field(activity, "showingCardList"), "Back shows card homepage");
                check(new ProfileStore(activity).load().size() == 1, "Card persists");
                invoke("showEditor", new Class<?>[]{MeQrProfile.class}, profiles().get(0));
            });
            pass("Completed onboarding Back opens saved card");
            onMain(this::checkTemplateLayout);
            onMain(this::checkSettingsLayout);
            pass("Narrow template controls and settings rows retain complete text");
            onMain(() -> ((EditText) field(session(), "name")).setText("Saved edit"));
            click("save");
            onMain(() -> {
                check(session() == null && !(Boolean) field(activity, "showingCardList"), "Save returns to card");
                check(new ProfileStore(activity).load().get(0).name.equals("Saved edit"), "Edit saved");
                invoke("showEditor", new Class<?>[]{MeQrProfile.class}, profiles().get(0));
                ((EditText) field(session(), "name")).setText("Discarded edit");
            });
            click("cancel");
            onMain(() -> {
                check(find(language.t("discardChanges")) != null, "Discard label present");
                check(find(language.t("delete")) == null, "No misleading Delete label");
            });
            click("discardChanges");
            onMain(() -> check(new ProfileStore(activity).load().get(0).name.equals("Saved edit"), "Discard preserves saved card"));
            pass("Save navigation and discard preserve correct card state");
            scannerImportCancellation();
            result.putString("stream", "PASS: all UI audit regressions\n");
            finish(Activity.RESULT_OK, result);
        } catch (Throwable error) {
            result.putString("stream", android.util.Log.getStackTraceString(error));
            finish(Activity.RESULT_CANCELED, result);
        }
    }

    private void galleryIntents() {
        List<Intent> requests = new ArrayList<>();
        ActivityMonitor monitor = new ActivityMonitor() {
            @Override public ActivityResult onStartActivity(Intent intent) {
                requests.add(intent);
                return new ActivityResult(Activity.RESULT_CANCELED, null);
            }
        };
        addMonitor(monitor);
        try {
            onMain(() -> {
                for (int request : new int[]{1001, 1002, 1003, 1004, 1005}) invoke("chooseImage", new Class<?>[]{int.class}, request);
            });
            check(requests.size() == 5, "All image entry points launch once");
            for (Intent request : requests) {
                check(Intent.ACTION_PICK.equals(request.getAction()), "Gallery picker used");
                check(!request.hasCategory(Intent.CATEGORY_OPENABLE), "Gallery not excluded by OPENABLE");
                check(MediaStore.Images.Media.EXTERNAL_CONTENT_URI.equals(request.getData()), "Image collection URI retained");
                check("image/*".equals(request.getType()), "Images only");
            }
            pass("Avatar, background, banner and QR gallery intents preserve URI and type");
        } finally { removeMonitor(monitor); }
    }

    private void checkTemplateLayout() {
        TextView standard = (TextView) find(language.t("standardTemplate"));
        TextView rhodes = (TextView) find(language.t("rhodesTemplate"));
        LinearLayout row = (LinearLayout) rhodes.getParent();
        float originalSize = rhodes.getTextSize();
        try {
            rhodes.setTextSize(24);
            measureAtWidth(row, 240);
            check(rhodes.getLineCount() > 1, "Template fixture wraps on narrow screens");
            checkTextFits(rhodes);
            check(standard.getTop() == rhodes.getTop(), "Template options stay top-aligned");
            check(rhodes.getBottom() <= row.getHeight() - row.getPaddingBottom(), "Template stays inside its row");
        } finally {
            rhodes.setTextSize(android.util.TypedValue.COMPLEX_UNIT_PX, originalSize);
            row.requestLayout();
        }
    }

    private void scannerImportCancellation() {
        getUiAutomation().grantRuntimePermission(getTargetContext().getPackageName(), android.Manifest.permission.CAMERA);
        ActivityMonitor monitor = new ActivityMonitor() {
            @Override public ActivityResult onStartActivity(Intent intent) {
                return new ActivityResult(Activity.RESULT_CANCELED, null);
            }
        };
        addMonitor(monitor);
        try {
            onMain(() -> invoke("showScan", new Class<?>[]{}));
            waitForIdleSync();
            for (int attempt = 0; attempt < 5; attempt++) {
                click("importFromPhoto");
                onMain(() -> {
                    check(find(language.t("importFromPhoto")) != null, "Canceling gallery returns to scanner");
                    check(!(Boolean) field(activity, "choosingScanImage"), "Picker state clears after cancel");
                    check(!(Boolean) field(activity, "scanningPhoto"), "Cancel does not leak scan mode into QR editing");
                });
            }
            sendKeyDownUpSync(KeyEvent.KEYCODE_BACK);
            waitForIdleSync();
            pass("Canceled scanner photo import returns to camera without leaking decode state");
        } finally { removeMonitor(monitor); }
    }

    private void checkSettingsLayout() {
        View row = (View) invoke("settingsRow", new Class<?>[]{Dialog.class, String.class, String.class, String.class, Runnable.class},
                null, "▦", language.t("scanMeQr"), language.t("scanMeQrHint"), (Runnable) () -> { });
        measureAtWidth(row, 220);
        TextView title = (TextView) find(row, language.t("scanMeQr"));
        TextView subtitle = (TextView) find(row, language.t("scanMeQrHint"));
        check(title.getLineCount() > 1, "Settings title wraps on narrow screens");
        check(subtitle.getLineCount() > 1, "Settings description wraps on narrow screens");
        checkTextFits(title);
        checkTextFits(subtitle);
    }

    private void measureAtWidth(View view, int widthDp) {
        int width = Math.round(widthDp * activity.getResources().getDisplayMetrics().density);
        view.measure(View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED));
        view.layout(0, 0, view.getMeasuredWidth(), view.getMeasuredHeight());
    }

    private void checkTextFits(TextView text) {
        android.text.Layout layout = text.getLayout();
        check(layout != null, "Text is laid out");
        for (int line = 0; line < layout.getLineCount(); line++) {
            check(layout.getEllipsisCount(line) == 0, "Text is not ellipsized");
        }
        check(layout.getHeight() <= text.getHeight() - text.getCompoundPaddingTop() - text.getCompoundPaddingBottom(),
                "Text fits vertically");
    }

    private Object session() { return field(activity, "editSession"); }
    private EditText input() { return (EditText) field(session(), "tags"); }
    private LinearLayout suggestions() { return (LinearLayout) field(session(), "tagSuggestions"); }
    private MeQrProfile profile() { return (MeQrProfile) field(session(), "profile"); }
    @SuppressWarnings("unchecked") private List<MeQrProfile> profiles() { return (List<MeQrProfile>) field(activity, "profiles"); }
    private Object field(Object target, String name) {
        try {
            java.lang.reflect.Field value = target.getClass().getDeclaredField(name);
            value.setAccessible(true);
            return value.get(target);
        } catch (Exception error) { throw new AssertionError(error); }
    }
    private Object invoke(String name, Class<?>[] types, Object... args) {
        try {
            java.lang.reflect.Method method = MainActivity.class.getDeclaredMethod(name, types);
            method.setAccessible(true);
            return method.invoke(activity, args);
        } catch (Exception error) { throw new AssertionError(error); }
    }
    private void click(String key) {
        onMain(() -> {
            View button = find(language.t(key));
            check(button != null && button.performClick(), "Click " + key);
        });
        waitForIdleSync();
    }
    private View find(String text) {
        List<View> windows = WindowInspector.getGlobalWindowViews();
        return windows.isEmpty() ? null : find(windows.get(windows.size() - 1), text);
    }
    private View find(View view, String text) {
        if (view.getVisibility() != View.VISIBLE) return null;
        if (view instanceof TextView && text.contentEquals(((TextView) view).getText())) return view;
        if (text.contentEquals(view.getContentDescription() == null ? "" : view.getContentDescription())) return view;
        if (view instanceof ViewGroup) {
            ViewGroup group = (ViewGroup) view;
            for (int index = 0; index < group.getChildCount(); index++) {
                View match = find(group.getChildAt(index), text);
                if (match != null) return match;
            }
        }
        return null;
    }
    private void onMain(Runnable action) {
        Throwable[] failure = {null};
        runOnMainSync(() -> { try { action.run(); } catch (Throwable error) { failure[0] = error; } });
        if (failure[0] != null) throw new AssertionError(failure[0]);
    }
    private void pass(String message) {
        Bundle status = new Bundle();
        status.putString("stream", "PASS: " + message + "\n");
        sendStatus(0, status);
    }
    private static void check(boolean condition, String message) { if (!condition) throw new AssertionError(message); }
}
