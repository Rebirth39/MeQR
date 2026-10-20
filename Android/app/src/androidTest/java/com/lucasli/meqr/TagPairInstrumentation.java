package com.lucasli.meqr;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Intent;
import android.graphics.Bitmap;
import android.os.Bundle;
import android.os.SystemClock;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.inspector.WindowInspector;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import org.json.JSONArray;
import org.json.JSONObject;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

public final class TagPairInstrumentation extends Instrumentation {
    private Activity activity;
    private I18n i18n;

    @Override public void onCreate(Bundle args) { super.onCreate(args); start(); }

    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            check(getTargetContext().getPackageName().endsWith(".tagpaircheck"), "Isolated package required");
            byte[] catalog;
            try (java.io.InputStream input = getTargetContext().getAssets().open("tags-v1.json");
                 java.io.ByteArrayOutputStream output = new java.io.ByteArrayOutputStream()) {
                byte[] buffer = new byte[8192];
                int count;
                while ((count = input.read(buffer)) != -1) output.write(buffer, 0, count);
                catalog = output.toByteArray();
            }
            RemoteTagCatalog.install(catalog, RemoteTagCatalog.Source.BUNDLED);
            modelChecks(catalog);
            i18n = new I18n(getTargetContext());
            i18n.setLanguageMode(I18n.ZH_HANS);
            getTargetContext().getSharedPreferences("settings", 0).edit().putBoolean("android_profile_v1", true).commit();
            activity = startActivitySync(new Intent().setClassName(getTargetContext(), "com.lucasli.meqr.MainActivity").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            waitForIdleSync();
            SystemClock.sleep(700);
            if (find(i18n.t("later"), null) != null) click(i18n.t("later"));
            onMain(() -> {
                invoke("showEditor", new Class<?>[]{MeQrProfile.class}, new Object[]{null});
                invoke("appendTag", new Class<?>[]{String.class}, new Object[]{"星乃一歌"});
                invoke("appendTag", new Class<?>[]{String.class}, new Object[]{"天马咲希"});
            });
            waitForIdleSync();
            drag(0, 1);
            check(find(i18n.t("tagPairTitle"), null) != null, "Drag opens CP/CB dialog");
            click(i18n.t("cancel"));
            onMain(() -> check(profile().tags.equals(Arrays.asList("星乃一歌", "天马咲希")), "Cancel retains original tags and order"));
            drag(0, 1);
            click("CB");
            onMain(() -> {
                check(profile().tags.equals(Collections.singletonList("一歌&咲希")), "Source is on left");
                check(profile().tagPair("一歌&咲希").isCB(), "CB creation");
                TextView label = (TextView) ((LinearLayout) chips().getChildAt(0)).getChildAt(0);
                check(label.getText() instanceof android.text.Spanned, "CB uses per-character ink");
                profile().setTagTextWeight("一歌&咲希", 900);
                invoke("rebuildTagColorPanel", new Class<?>[]{}, new Object[]{});
                View swap = find(null, i18n.t("tagPairSwap") + " 一歌&咲希");
                check(swap != null && swap.isEnabled(), "Swap available");
                ViewGroup row = (ViewGroup) swap.getParent();
                check(row.indexOfChild(swap) == 2 && ((TextView) row.getChildAt(1)).getText().toString().equals("B"), "Swap follows B");
                scrollTo(row);
            });
            screenshot("cb-settings");
            onMain(() -> invoke("showTagColorEditor", new Class<?>[]{String.class}, new Object[]{"一歌&咲希"}));
            waitForIdleSync();
            screenshot("cb-editor");
            click("CP"); click(i18n.t("save"));
            onMain(() -> {
                check(!profile().tagPair("一歌&咲希").isCB(), "Changed CB to CP");
                check(profile().tagTextWeight("一歌&咲希") == 900, "Type change preserves weight");
                find(null, i18n.t("tagPairSwap") + " 一歌&咲希").performClick();
                check(profile().tags.equals(Collections.singletonList("咲希&一歌")), "Swap updates name");
                check(profile().tagTextWeight("咲希&一歌") == 900, "Swap preserves weight");
                check(Arrays.equals(profile().tagColors("咲希&一歌"), new int[]{0xFFFFDD44, 0xFF33AAEE}), "Swap updates colors");
                check((Boolean) invoke("saveEdit", new Class<?>[]{}, new Object[]{}), "Save succeeds");
            });
            MeQrProfile saved = new ProfileStore(getTargetContext()).load().stream().filter(value -> value.tags.contains("咲希&一歌")).findFirst().orElseThrow(() -> new AssertionError("Pair not persisted"));
            check(saved.tagPair("咲希&一歌").kind.equals(TagPair.CP), "Persisted kind");
            onMain(() -> {
                invoke("showEditor", new Class<?>[]{MeQrProfile.class}, new Object[]{saved});
                check(profile().tagPair("咲希&一歌") != null, "Reopened editor retains pair");
                invoke("writeTags", new Class<?>[]{List.class}, new Object[]{Arrays.asList("星乃一歌", "天马咲希")});
            });
            waitForIdleSync();
            drag(1, 0); click("CP");
            onMain(() -> check(profile().tags.equals(Collections.singletonList("咲希&一歌")), "Reverse drag order"));
            screenshot("reverse-cp");
            renderChecks(saved);
            onMain(() -> invoke("writeTags", new Class<?>[]{List.class}, new Object[]{Arrays.asList("高松灯", "星乃一歌")}));
            waitForIdleSync();
            drag(0, 1);
            onMain(() -> check(profile().tags.equals(Arrays.asList("星乃一歌", "高松灯")), "Other IP only reorders"));
            result.putString("stream", "PASS: 760 ordered pairs, language/offline/JSON/sync/collision/legacy checks; real drag cancel/CB/CP/reverse/order, swap beside B, weight preservation, save/reopen, both card templates and back\n");
            finish(Activity.RESULT_OK, result);
        } catch (Throwable failure) {
            try { screenshot("failure"); } catch (Exception ignored) { }
            result.putString("stream", android.util.Log.getStackTraceString(failure));
            finish(Activity.RESULT_CANCELED, result);
        } finally {
            if (activity != null) onMain(activity::finish);
        }
    }

    private void modelChecks(byte[] catalog) throws Exception {
        int combinations = 0;
        for (RemoteTagCatalog.Entry first : RemoteTagCatalog.entries()) {
            if (TagPair.character(first.display(I18n.ZH_HANS)) == null) continue;
            for (RemoteTagCatalog.Entry second : RemoteTagCatalog.entries()) {
                if (first == second || TagPair.character(second.display(I18n.ZH_HANS)) == null) continue;
                for (String kind : new String[]{TagPair.CP, TagPair.CB}) {
                    MeQrProfile profile = new MeQrProfile();
                    String source = first.display(I18n.ZH_HANS), target = second.display(I18n.EN);
                    profile.tags.addAll(Arrays.asList("Before", target, "Middle", source, "After"));
                    check(profile.combineTags(source, target, kind, I18n.ZH_HANS), "Valid pair");
                    String name = profile.tags.get(1);
                    TagPair pair = profile.tagPair(name);
                    check(pair.left.catalogID.equals(first.id) && pair.right.catalogID.equals(second.id), "Ordered IDs");
                    check(profile.tags.equals(Arrays.asList("Before", name, "Middle", "After")), "List order preserved");
                    profile.setTagTextWeight(name, 900);
                    check(profile.swapTag(name, I18n.ZH_HANS), "Swap succeeds");
                    String reversed = profile.tags.get(1);
                    check(profile.tagTextWeight(reversed) == 900 && profile.tagPair(reversed).kind.equals(kind), "Swap retains style");
                    MeQrProfile restored = MeQrProfile.fromJson(profile.toJson());
                    check(restored.tagPair(reversed).identity().equals(pair.swapped().identity()), "Local JSON retains pairing");
                    combinations++;
                }
            }
        }
        check(combinations == 760, "20 characters, 760 ordered kinds");
        for (String[] invalid : new String[][]{{"星乃一歌", "Ichika Hoshino"}, {"星乃一歌", "高松灯"}, {"世界计划", "天马咲希"}, {"Leo/need", "天马咲希"}, {"Unknown", "天马咲希"}})
            check(TagPair.make(invalid[0], invalid[1], TagPair.CP) == null, "Unsupported pair rejected");
        MeQrProfile profile = new MeQrProfile();
        profile.tags.addAll(Arrays.asList("星乃一歌", "天马咲希", "一歌&咲希"));
        check(!profile.combineTags("星乃一歌", "天马咲希", TagPair.CP, I18n.ZH_HANS), "Name collision rejected");
        profile.tags.remove("一歌&咲希");
        check(profile.combineTags("星乃一歌", "天马咲希", TagPair.CB, I18n.ZH_HANS), "CB pair");
        profile.tags.add("咲希&一歌");
        check(!profile.canSwapTag("一歌&咲希", I18n.ZH_HANS), "Reverse name collision rejected");
        profile.tags.remove("咲希&一歌");
        String[] languages = {I18n.ZH_HANS, I18n.ZH_HANT_HK, I18n.ZH_HANT_TW, I18n.EN, I18n.JA};
        for (String language : languages) {
            profile.reconcileTags(language);
            check(profile.tags.get(0).equals(I18n.EN.equals(language) ? "Ichika&Saki" : "一歌&咲希"), "Localized given names");
        }
        JSONObject doc = ProfileSyncClient.document(profile, Collections.emptyMap());
        TagPair pair = profile.tagPair(profile.tags.get(0));
        check(doc.getJSONArray("tags").getJSONObject(0).getJSONObject("pairing").getJSONArray("members").getJSONObject(0).getString("catalogID").equals("tag-0008"), "iOS-compatible sync IDs");
        MeQrProfile imported = new ProfileSyncClient(getTargetContext()).apply(new JSONObject().put("document", doc), new MeQrProfile(), "unused");
        check(imported.tagPair(imported.tags.get(0)).isCB(), "Sync import preserves CB");
        imported.tagColorOverrides.put(imported.tags.get(0), "@solid");
        check(imported.tagColors(imported.tags.get(0)).length == 2 && imported.tagPair(imported.tags.get(0)).isCB(), "Ordinary override cannot change pair style");
        java.lang.reflect.Field entries = RemoteTagCatalog.class.getDeclaredField("entries");
        entries.setAccessible(true);
        Object previous = entries.get(null);
        try {
            entries.set(null, Collections.emptyList());
            TagPair offline = TagPair.fromJson(pair.toJson());
            for (String language : languages) check(offline.display(language).equals(pair.display(language)), "Offline names retain snapshots");
            check(Arrays.equals(offline.colors(), new int[]{0xFF33AAEE, 0xFFFFDD44}), "Offline colors retain snapshots");
        } finally { entries.set(null, previous); }
        JSONObject invalid = pair.toJson(); invalid.put("kind", "invalid");
        check(TagPair.fromJson(invalid) == null, "Invalid pair kind falls back");
        invalid = pair.toJson(); invalid.getJSONArray("members").put(1, invalid.getJSONArray("members").getJSONObject(0));
        check(TagPair.fromJson(invalid) == null, "Same member rejected");
        check(MeQrProfile.fromJson(new JSONObject().put("tags", new JSONArray().put("旧标签"))).tagPair("旧标签") == null, "Legacy data remains ordinary");
    }

    private void renderChecks(MeQrProfile profile) throws Exception {
        TagPair pair = profile.tagPair(profile.tags.get(0));
        Bitmap white = Bitmap.createBitmap(240, 60, Bitmap.Config.ARGB_8888);
        TagSegmentDrawable drawable = new TagSegmentDrawable(pair.colors(), 30, 4);
        drawable.setBounds(0, 0, 240, 60); drawable.draw(new android.graphics.Canvas(white));
        check(white.getPixel(60, 15) == android.graphics.Color.WHITE, "CB interior is opaque white");
        check(white.getPixel(60, 1) == pair.colors()[0] && white.getPixel(180, 1) == pair.colors()[1], "CB two-color outline");
        white.recycle();
        for (String template : new String[]{"standard", "rhodes"}) {
            profile.template = template;
            profile.referenceFor(profile.tags.get(0)).pairing = pair.withKind(TagPair.CP);
            Bitmap cp = CardRenderer.render(profile, i18n, 720);
            profile.referenceFor(profile.tags.get(0)).pairing = pair.withKind(TagPair.CB);
            Bitmap cb = CardRenderer.render(profile, i18n, 720);
            check(!cp.sameAs(cb), "Card templates distinguish CP from CB");
            save(cp, template + "-cp"); save(cb, template + "-cb");
            cp.recycle(); cb.recycle();
            Bitmap back = CardRenderer.renderBack(profile, i18n, 720); save(back, template + "-cb-back"); back.recycle();
        }
    }

    private void drag(int from, int to) throws Exception {
        int[][] points = {new int[2], new int[2]};
        onMain(() -> scrollTo(chips()));
        waitForIdleSync(); SystemClock.sleep(200);
        onMain(() -> {
            View first = chips().getChildAt(from), last = chips().getChildAt(to);
            first.getLocationOnScreen(points[0]); last.getLocationOnScreen(points[1]);
            points[0][0] += first.getWidth() / 3; points[0][1] += first.getHeight() / 2;
            points[1][0] += last.getWidth() / 2; points[1][1] += last.getHeight() / 2;
        });
        long down = SystemClock.uptimeMillis();
        pointer(down, MotionEvent.ACTION_DOWN, points[0][0], points[0][1]); SystemClock.sleep(800);
        for (int index = 1; index <= 20; index++) {
            pointer(down, MotionEvent.ACTION_MOVE, points[0][0] + (points[1][0] - points[0][0]) * index / 20f,
                    points[0][1] + (points[1][1] - points[0][1]) * index / 20f);
            SystemClock.sleep(30);
        }
        pointer(down, MotionEvent.ACTION_UP, points[1][0], points[1][1]);
        waitForIdleSync(); SystemClock.sleep(300);
    }

    private void pointer(long down, int action, float x, float y) {
        MotionEvent event = MotionEvent.obtain(down, SystemClock.uptimeMillis(), action, x, y, 0);
        event.setSource(android.view.InputDevice.SOURCE_TOUCHSCREEN);
        check(getUiAutomation().injectInputEvent(event, true), "Pointer injection"); event.recycle();
    }

    private void scrollTo(View view) {
        android.view.ViewParent parent = view.getParent();
        while (parent instanceof View && !(parent instanceof ScrollView)) parent = parent.getParent();
        check(parent instanceof ScrollView, "Scrollable form");
        ScrollView scroll = (ScrollView) parent;
        android.graphics.Rect rect = new android.graphics.Rect(0, 0, view.getWidth(), view.getHeight());
        scroll.offsetDescendantRectToMyCoords(view, rect);
        scroll.scrollTo(0, Math.max(0, rect.top - scroll.getHeight() / 3));
    }

    private MeQrProfile profile() { return (MeQrProfile) field(field(activity, "editSession"), "profile"); }
    private LinearLayout chips() { return (LinearLayout) field(field(activity, "editSession"), "tagChips"); }
    private Object field(Object target, String name) {
        try { java.lang.reflect.Field field = target.getClass().getDeclaredField(name); field.setAccessible(true); return field.get(target); }
        catch (Exception error) { throw new RuntimeException(error); }
    }
    private Object invoke(String name, Class<?>[] types, Object[] args) {
        try { java.lang.reflect.Method method = MainActivity.class.getDeclaredMethod(name, types); method.setAccessible(true); return method.invoke(activity, args); }
        catch (Exception error) { throw new RuntimeException(error); }
    }
    private void onMain(Runnable action) {
        Throwable[] failure = {null};
        runOnMainSync(() -> { try { action.run(); } catch (Throwable error) { failure[0] = error; } });
        if (failure[0] != null) throw new AssertionError(failure[0]);
    }
    private View find(String text, String description) {
        List<View> windows = WindowInspector.getGlobalWindowViews();
        for (int index = windows.size() - 1; index >= 0; index--) { View found = find(windows.get(index), text, description); if (found != null) return found; }
        return null;
    }
    private View find(View view, String text, String description) {
        if (view.getVisibility() != View.VISIBLE) return null;
        if (text != null && view instanceof TextView && text.contentEquals(((TextView) view).getText())) return view;
        if (description != null && view.getContentDescription() != null && description.contentEquals(view.getContentDescription())) return view;
        if (view instanceof ViewGroup) for (int index = 0; index < ((ViewGroup) view).getChildCount(); index++) {
            View found = find(((ViewGroup) view).getChildAt(index), text, description); if (found != null) return found;
        }
        return null;
    }
    private void click(String text) {
        onMain(() -> {
            View view = find(text, null); check(view != null, "Missing " + text);
            android.view.ViewParent parent = view.getParent();
            while (parent instanceof View && !(parent instanceof android.widget.AdapterView)) parent = parent.getParent();
            if (parent instanceof android.widget.AdapterView) {
                android.widget.AdapterView<?> list = (android.widget.AdapterView<?>) parent;
                int position = list.getPositionForView(view);
                list.performItemClick(view, position, list.getItemIdAtPosition(position));
            } else view.performClick();
        });
        waitForIdleSync();
    }
    private void screenshot(String name) throws Exception { waitForIdleSync(); SystemClock.sleep(200); Bitmap bitmap = getUiAutomation().takeScreenshot(); if (bitmap != null) { save(bitmap, name); bitmap.recycle(); } }
    private void save(Bitmap bitmap, String name) throws Exception {
        try (java.io.FileOutputStream output = new java.io.FileOutputStream(new java.io.File(getTargetContext().getExternalFilesDir(null), "pair-" + name + ".png"))) { bitmap.compress(Bitmap.CompressFormat.PNG, 100, output); }
    }
    private static void check(boolean valid, String message) { if (!valid) throw new AssertionError(message); }
}
