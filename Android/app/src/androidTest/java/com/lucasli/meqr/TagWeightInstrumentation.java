package com.lucasli.meqr;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Intent;
import android.graphics.Bitmap;
import android.os.Bundle;
import android.view.View;
import android.view.ViewGroup;
import android.view.inspector.WindowInspector;
import android.widget.TextView;
import org.json.JSONObject;

public final class TagWeightInstrumentation extends Instrumentation {
    private Activity activity;
    private static final String TAG = "世界计划";

    @Override public void onCreate(Bundle args) { super.onCreate(args); start(); }
    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            check(getTargetContext().getPackageName().endsWith(".tagweightcheck"), "Isolated package required");
            I18n i18n = new I18n(getTargetContext()); i18n.setLanguageMode(I18n.ZH_HANS);
            activity = startActivitySync(new Intent().setClassName(getTargetContext(), "com.lucasli.meqr.MainActivity").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            waitForIdleSync();
            onMain(() -> {
                invoke("showEditor", new Class<?>[]{MeQrProfile.class}, new Object[]{null});
                invoke("appendTag", new Class<?>[]{String.class}, new Object[]{TAG});
                invoke("appendTag", new Class<?>[]{String.class}, new Object[]{"初音未来"});
            });
            waitForIdleSync();
            for (int expected : new int[]{600, 900, 400}) {
                onMain(() -> {
                    View button = weightButton(); check(button != null, "Weight button visible in hierarchy");
                    button.performClick();
                    check(profile().tagTextWeight(TAG) == expected, "B cycles weight to " + expected);
                    check(profile().tagTextWeight("初音未来") == 400, "Other Tag weight unchanged");
                });
                waitForIdleSync();
                onMain(() -> {
                    View next = weightButton();
                    android.view.ViewParent parent = next.getParent();
                    while (parent instanceof View && !(parent instanceof android.widget.ScrollView)) parent = parent.getParent();
                    check(parent instanceof android.widget.ScrollView, "Scrollable weight row");
                    android.widget.ScrollView scroll = (android.widget.ScrollView) parent;
                    android.graphics.Rect rect = new android.graphics.Rect(0, 0, next.getWidth(), next.getHeight());
                    scroll.offsetDescendantRectToMyCoords(next, rect);
                    scroll.scrollTo(0, Math.max(0, rect.top - scroll.getHeight() / 2));
                });
                screenshot("weight-" + expected);
            }
            onMain(() -> {
                weightButton().performClick(); weightButton().performClick();
                invoke("showTagColorEditor", new Class<?>[]{String.class}, new Object[]{TAG});
            });
            waitForIdleSync();
            click(i18n.t("solidColor")); click(i18n.t("save"));
            onMain(() -> {
                check(profile().tagTextWeight(TAG) == 900, "Color mode preserves weight");
                MeQrProfile original = profile();
                try {
                    MeQrProfile saved = MeQrProfile.fromJson(original.toJson());
                    saved.reconcileTags("en");
                    check(saved.tagTextWeight("Project Sekai") == 900, "Language retains weight by stable ID");
                    MeQrProfile copied = (MeQrProfile) invoke("copy", new Class<?>[]{MeQrProfile.class}, new Object[]{saved});
                    copied.setTagTextWeight("Project Sekai", 600);
                    check(saved.tagTextWeight("Project Sekai") == 900, "Editor draft independent");
                    check(!copied.tagReferences.isEmpty() && copied.tagReferences.get(0) != saved.tagReferences.get(0), "References copied independently");
                    saved.reconcileTags("zh-Hans");
                    check(MeQrProfile.fromJson(saved.toJson()).tagTextWeight(TAG) == 900, "Backup round trip");
                    JSONObject legacy = new JSONObject().put("tags", new org.json.JSONArray().put(TAG));
                    check(MeQrProfile.fromJson(legacy).tagTextWeight(TAG) == 400, "Legacy weight defaults regular");
                    check(TagTextWeight.normalize(123) == 400, "Invalid weight normalized");
                    saved.tags.clear();
                    check(MeQrProfile.fromJson(saved.toJson()).tagTextWeights.isEmpty(), "Deleted Tag weight pruned");
                } catch (Exception e) { throw new RuntimeException(e); }
            });
            MeQrProfile render = new MeQrProfile(); render.tags.add(TAG);
            render.tagColorOverrides.put(TAG, "#FFFFFF");
            Bitmap[] images = new Bitmap[3];
            int[] weights = {400,600,900};
            for (int i=0;i<3;i++) {
                render.setTagTextWeight(TAG, weights[i]);
                images[i] = CardRenderer.renderBack(render, i18n, 720);
                save(images[i], "card-weight-" + weights[i]);
            }
            check(!images[0].sameAs(images[1]) && !images[1].sameAs(images[2]), "Chinese exported glyphs differ across all three weights");
            result.putString("stream", "PASS: three B states, per-Tag isolation, palette preservation, language/backup/draft/deletion, distinct Chinese export pixels\n");
            finish(Activity.RESULT_OK, result);
        } catch (Throwable error) {
            result.putString("stream", android.util.Log.getStackTraceString(error)); finish(Activity.RESULT_CANCELED, result);
        }
    }

    private MeQrProfile profile() {
        try {
            java.lang.reflect.Field f = MainActivity.class.getDeclaredField("editSession"); f.setAccessible(true);
            Object session = f.get(activity); f = session.getClass().getDeclaredField("profile"); f.setAccessible(true);
            return (MeQrProfile) f.get(session);
        } catch (Exception e) { throw new RuntimeException(e); }
    }
    private Object invoke(String method, Class<?>[] types, Object[] args) {
        try { java.lang.reflect.Method m = MainActivity.class.getDeclaredMethod(method, types); m.setAccessible(true); return m.invoke(activity, args); }
        catch (Exception e) { throw new RuntimeException(e); }
    }
    private void onMain(Runnable block) {
        Throwable[] failure = {null}; runOnMainSync(() -> { try { block.run(); } catch(Throwable e) { failure[0]=e; } });
        if(failure[0]!=null) throw new AssertionError(failure[0]);
    }
    private View weightButton() { return find(null, TAG + ", 字重: "); }
    private View find(String text, String descriptionPrefix) {
        java.util.List<View> windows = WindowInspector.getGlobalWindowViews();
        for(int i=windows.size()-1;i>=0;i--) { View v=find(windows.get(i),text,descriptionPrefix); if(v!=null)return v; }
        return null;
    }
    private View find(View view, String text, String prefix) {
        if(view.getVisibility()!=View.VISIBLE)return null;
        if(text!=null && view instanceof TextView && text.contentEquals(((TextView)view).getText()))return view;
        if(prefix!=null && view.getContentDescription()!=null && view.getContentDescription().toString().startsWith(prefix))return view;
        if(view instanceof ViewGroup)for(int i=0;i<((ViewGroup)view).getChildCount();i++) {
            View v=find(((ViewGroup)view).getChildAt(i),text,prefix); if(v!=null)return v;
        }
        return null;
    }
    private void click(String label) { onMain(() -> { View v=find(label,null); check(v!=null,"Missing " + label); v.performClick(); }); waitForIdleSync(); }
    private void screenshot(String name) throws Exception { waitForIdleSync(); Thread.sleep(350); save(getUiAutomation().takeScreenshot(),name); }
    private void save(Bitmap bitmap,String name) throws Exception {
        try(java.io.FileOutputStream out=new java.io.FileOutputStream(new java.io.File(getTargetContext().getExternalFilesDir(null),name+".png"))) { bitmap.compress(Bitmap.CompressFormat.PNG,100,out); }
    }
    private static void check(boolean value,String message) { if(!value)throw new AssertionError(message); }
}
