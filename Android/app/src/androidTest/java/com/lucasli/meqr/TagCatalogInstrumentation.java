package com.lucasli.meqr;

import android.app.Activity;
import android.app.Instrumentation;
import android.os.Bundle;
import java.io.InputStream;
import java.util.Arrays;
import org.json.JSONArray;
import org.json.JSONObject;

public final class TagCatalogInstrumentation extends Instrumentation {
    @Override public void onCreate(Bundle args) { super.onCreate(args); start(); }
    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            check(getTargetContext().getPackageName().endsWith(".tagcatalogcheck"), "Isolated package required");
            byte[] data;
            try (InputStream input = getTargetContext().getAssets().open("tags-v1.json")) {
                java.io.ByteArrayOutputStream output = new java.io.ByteArrayOutputStream();
                byte[] buffer = new byte[8192];
                int count;
                while ((count = input.read(buffer)) != -1) output.write(buffer, 0, count);
                data = output.toByteArray();
            }
            RemoteTagCatalog.install(data, RemoteTagCatalog.Source.BUNDLED);
            JSONArray entries = new JSONObject(new String(data, java.nio.charset.StandardCharsets.UTF_8)).getJSONArray("entries");
            check(entries.length() == 450, "Entry count");
            for (int i = 0; i < entries.length(); i++) {
                RemoteTagCatalog.Entry entry = RemoteTagCatalog.Entry.from(entries.getJSONObject(i));
                check(entry.colors.length > 0 && entry.colors.length <= 6, "Complete preset: " + entry.id);
                JSONObject names = entries.getJSONObject(i).getJSONObject("names");
                for (String language : Arrays.asList("zhHans", "zhHantHK", "zhHantTW", "en", "ja")) {
                    String name = names.getString(language);
                    check(RemoteTagCatalog.canonicalKey(name).equals(entry.canonicalKey), "Identity: " + name);
                    check(Arrays.equals(CardTagColorPalette.colorsFor(name, null), entry.colors), "Palette: " + name);
                    check(CardTagColorPalette.solidColorFor(name) == entry.solidColor, "Solid: " + name);
                    check(CardTagColorPalette.colorsFor(name, "#123456")[0] == 0xFF123456, "Custom precedence");
                }
            }
            check(RemoteTagCatalog.colorsFor("LoveLive!")[0] == 0xFFE4007F, "LoveLive pink");
            check(RemoteTagCatalog.solidColorFor("MEIKO") == 0xFFD80000, "MEIKO red");
            check(RemoteTagCatalog.solidColorFor("Kagamine Rin") == 0xFFFFB000, "Rin orange");
            check(RemoteTagCatalog.solidColorFor("Kagamine Len") == 0xFFFFE211, "Len yellow");
            check(RemoteTagCatalog.colorsFor("世界计划").length == 6, "Six-color preset");
            check(RemoteTagCatalog.solidColorFor("世界计划") == 0xFF00A0E9, "Sekai solid");
            check(RemoteTagCatalog.canonicalKey("Frieren").equals(CardTagIndex.normalizedKey("芙莉莲")), "Character beats IP alias");
            check(RemoteTagCatalog.canonicalKey("Saki").equals("saki"), "Ambiguous alias not canonicalized");
            check(RemoteTagCatalog.colorsFor("Saki")[0] == 0xFF6F7582, "Ambiguous neutral color");
            check(RemoteTagCatalog.entryFor("胡桃").display(I18n.EN).equals("Hu Tao"), "Hu Tao belongs to Genshin");
            check(RemoteTagCatalog.entryFor("妮可").display(I18n.EN).equals("Nico Yazawa"), "Nico belongs to LoveLive");
            check(RemoteTagCatalog.solidColorFor("Yukina Minato") == 0xFF881188, "Official Yukina purple");
            check(RemoteTagCatalog.solidColorFor("Misaki Okusawa") == 0xFF006699, "Human Misaki blue");
            check(RemoteTagCatalog.solidColorFor("Michelle") == 0xFFDD33CC, "Michelle costume pink");
            check(RemoteTagCatalog.colorsFor("wsmix").length == 5, "Removed test alias compatibility");
            check(RemoteTagCatalog.suggestions("世界计划 咲希", new I18n(getTargetContext()), java.util.Collections.emptyList(), 8).size() == 1, "Context search isolates Saki");
            migration(data);
            favorites();
            outbox();
            check(new TagTextContrast(new int[]{0xFF000000, 0xFFFFFFFF}).needsOutline, "Mixed extrema require outline");
            check(!new TagTextContrast(new int[]{0xFFFFFFFF, 0xFFFFFFAA}).needsOutline, "Light palette uses plain dark ink");
            result.putString("stream", "PASS: 450 entries x 5 names, palettes, identity, solid/custom modes, ambiguous aliases, six colors\n");
            finish(Activity.RESULT_OK, result);
        } catch (Throwable error) {
            result.putString("stream", android.util.Log.getStackTraceString(error));
            finish(Activity.RESULT_CANCELED, result);
        }
    }
    private static void check(boolean value, String message) {
        if (!value) throw new AssertionError(message);
    }

    private void migration(byte[] data) throws Exception {
        MeQrProfile profile = new MeQrProfile();
        profile.tags.add("世界计划"); profile.tags.add("Saki");
        profile.tagColorOverrides.put("世界计划", "#123456,#ABCDEF");
        profile.reconcileTags("en");
        check(profile.tagReferences.get(0).catalogID.equals("tag-0001"), "Stable ID migrated");
        check(profile.tagReferences.get(1).catalogID.isEmpty(), "Ambiguous legacy name stays custom");
        String english = profile.tags.get(0);
        check(profile.tagColorOverrides.get(english).equals("#123456,#ABCDEF"), "Override follows language");
        JSONObject serialized = profile.toJson();
        JSONObject document = new JSONObject(new String(data, java.nio.charset.StandardCharsets.UTF_8));
        JSONArray entries = document.getJSONArray("entries");
        for (int i = 0; i < entries.length(); i++) {
            JSONObject entry = entries.getJSONObject(i);
            if (!entry.getString("id").equals("tag-0001")) continue;
            entry.getJSONObject("names").put("en", "Renamed Sekai");
        }
        RemoteTagCatalog.install(document.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8), RemoteTagCatalog.Source.BUNDLED);
        MeQrProfile renamed = MeQrProfile.fromJson(serialized); renamed.reconcileTags("en");
        check(renamed.tags.get(0).equals("Renamed Sekai"), "Name resolved by ID");
        check(renamed.tagColors("Renamed Sekai")[0] == 0xFF123456, "Custom color survives rename");
        renamed.tagColorOverrides.remove("Renamed Sekai");
        serialized = renamed.toJson();
        for (int i = entries.length() - 1; i >= 0; i--) if (entries.getJSONObject(i).getString("id").equals("tag-0001")) entries.remove(i);
        RemoteTagCatalog.install(document.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8), RemoteTagCatalog.Source.BUNDLED);
        MeQrProfile removed = MeQrProfile.fromJson(serialized); removed.reconcileTags("ja");
        check(removed.tags.get(0).equals("Renamed Sekai"), "Removed name retained");
        check(removed.tagColors("Renamed Sekai").length == 6, "Removed preset retains six colors");
        check(removed.tagColors("Renamed Sekai", "@solid")[0] == 0xFF00A0E9, "Removed solid retained");
        removed.tags.remove(0); removed.tagColorOverrides.clear();
        check(MeQrProfile.fromJson(removed.toJson()).tagReferences.size() == 1, "Deletion persists");
        RemoteTagCatalog.install(data, RemoteTagCatalog.Source.BUNDLED);
    }

    private void favorites() {
        android.content.SharedPreferences prefs = getTargetContext().getSharedPreferences("ux-favorites-test", 0);
        prefs.edit().clear().commit();
        CardTagUsageStore usage = new CardTagUsageStore(prefs);
        usage.toggleFavorite("世界计划"); usage.record("世界计划"); usage.clear();
        check(new CardTagUsageStore(prefs).favorites().size() == 1, "Favorites independent of history");
        check(usage.isFavorite("Project Sekai"), "Favorite multilingual identity");
        usage.toggleFavorite("Project Sekai"); check(usage.favorites().isEmpty(), "Unfavorite by alias");
    }

    private void outbox() throws Exception {
        java.io.File file = new java.io.File(getTargetContext().getCacheDir(), "queue-" + java.util.UUID.randomUUID() + ".json");
        JSONObject payload = new JSONObject().put("request_id", java.util.UUID.randomUUID().toString()).put("tag_name", "Test");
        java.util.concurrent.atomic.AtomicInteger calls = new java.util.concurrent.atomic.AtomicInteger();
        TagReportOutbox offline = new TagReportOutbox(file, body -> { calls.incrementAndGet(); throw new java.io.IOException("offline"); });
        String id = offline.enqueue(payload);
        check(calls.get() == 0 && file.exists(), "Persist before sending");
        offline.enqueue(payload); check(offline.snapshot().length() == 1, "Deduplicate request ID");
        try { offline.enqueue(new JSONObject(payload.toString()).put("tag_name", "Changed")); throw new AssertionError("Conflict accepted"); }
        catch (IllegalArgumentException expected) { }
        offline.kick(); awaitState(offline, "pending", 1);
        check(offline.snapshot().getJSONObject(0).getLong("next") > System.currentTimeMillis(), "Retry backoff");
        offline.close();
        TagReportOutbox online = new TagReportOutbox(file, body -> {
            check(body.getString("request_id").equals(id), "Retry preserves ID");
            calls.incrementAndGet(); return "MEQR-20260908-ABCDEF";
        });
        online.retry(id); awaitState(online, "sent", 2);
        check(online.snapshot().getJSONObject(0).getString("ticket").endsWith("ABCDEF"), "Durable receipt");
        online.cancel(id); check(online.snapshot().length() == 0, "Delete receipt"); online.close();
        TagReportOutbox rejected = new TagReportOutbox(file, body -> { throw new TagReport.Rejected(); });
        rejected.enqueue(payload); rejected.kick(); awaitState(rejected, "failed", 1);
        rejected.cancel(id); check(rejected.snapshot().length() == 0, "Cancel failed job"); rejected.close();
        check(file.delete(), "Test queue cleanup");
    }

    private static void awaitState(TagReportOutbox queue, String state, int attempts) throws Exception {
        for (int i = 0; i < 100; i++) {
            JSONObject job = queue.snapshot().getJSONObject(0);
            if (job.optString("status").equals(state) && job.optInt("attempts") >= attempts) return;
            Thread.sleep(50);
        }
        throw new AssertionError("Queue did not reach " + state + ": " + queue.snapshot());
    }
}
