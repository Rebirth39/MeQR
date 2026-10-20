package com.lucasli.meqr;

import java.nio.charset.StandardCharsets;
import java.util.Collections;
import org.json.JSONArray;
import org.json.JSONObject;

/** Also runnable on a host JVM with Android platform stubs (no network or user storage). */
final class TagCatalogIntegrityChecks {
    static void check(boolean value, String message) {
        if (!value) throw new AssertionError(message);
    }

    static void run(byte[] data, I18n i18n) throws Exception {
        RemoteTagCatalog.install(data, RemoteTagCatalog.Source.BUNDLED);
        int count = RemoteTagCatalog.entries().size();
        String revision = RemoteTagCatalog.revision();
        check(CardTagIndex.normalizedKey("X").equals("x"), "X remains searchable");
        check(!CardTagIndex.canonicalKey("WX").equals(CardTagIndex.canonicalKey("W")), "WX must not select W");
        check(!CardTagIndex.canonicalKey("FateX").equals(CardTagIndex.canonicalKey("Fate")), "Distinct custom names");
        check(RemoteTagCatalog.suggestions("灰姑娘 千早", i18n, Collections.emptyList(), 20).isEmpty(), "No cross-work Chihaya");
        check(RemoteTagCatalog.suggestions("闪耀 春香", i18n, Collections.emptyList(), 20).isEmpty(), "No cross-work Haruka");
        check(RemoteTagCatalog.entryByID("tag-0376").searchScore("Star Rail 饮月") < 99, "Grandparent search");
        check(RemoteTagCatalog.entryByID("tag-0376").searchScore("Dan Heng 饮月") < 99, "Parent search");
        MeQrProfile profile = new MeQrProfile();
        profile.tags.add("初音未来");
        profile.tagColorOverrides.put("初音未来", "#FF0000");
        check(profile.tagLibraryColors("Hatsune Miku")[0] == 0xFFFF0000, "Library respects custom color through localized identity");
        profile.reconcileTags("ja");
        check(profile.tagLibraryColors("Hatsune Miku")[0] == 0xFFFF0000, "Library respects migrated reference override");
        for (String scenario : new String[]{"old", "categories", "color", "duplicate", "cycle", "orphan", "name", "range"}) {
            JSONObject invalid = new JSONObject(new String(data, StandardCharsets.UTF_8));
            JSONArray entries = invalid.getJSONArray("entries");
            switch (scenario) {
                case "old": invalid.put("revision", "2000.01.01.1"); break;
                case "categories": invalid.put("categories", new JSONArray()); break;
                case "color": entries.getJSONObject(0).put("colors", new JSONArray().put("bad")); break;
                case "duplicate": entries.put(entries.getJSONObject(0)); break;
                case "cycle": entries.getJSONObject(0).put("parentID", entries.getJSONObject(0).getString("id")); break;
                case "orphan": entries.getJSONObject(0).put("parentID", "tag-missing"); break;
                case "name": entries.getJSONObject(0).getJSONObject("names").remove("ja"); break;
                case "range": invalid.getJSONArray("categories").getJSONObject(0).getJSONArray("ranges").getJSONObject(0).put("end", ""); break;
            }
            for (RemoteTagCatalog.Source origin : new RemoteTagCatalog.Source[]{RemoteTagCatalog.Source.CACHED, RemoteTagCatalog.Source.ONLINE}) {
                boolean rejected = false;
                try { RemoteTagCatalog.install(invalid.toString().getBytes(StandardCharsets.UTF_8), origin); }
                catch (Exception expected) { rejected = true; }
                check(rejected, "Reject " + scenario + " from " + origin);
                check(RemoteTagCatalog.revision().equals(revision) && RemoteTagCatalog.entries().size() == count, "Preserve healthy catalog");
                check(RemoteTagCatalog.entryByID("tag-0480") != null, "Preserve newest entry");
            }
        }
        JSONObject valid = new JSONObject(new String(data, StandardCharsets.UTF_8));
        valid.put("revision", "2099.10.02.10");
        RemoteTagCatalog.install(valid.toString().getBytes(StandardCharsets.UTF_8), RemoteTagCatalog.Source.ONLINE);
        valid.put("revision", "2099.10.02.9");
        boolean rejected = false;
        try { RemoteTagCatalog.install(valid.toString().getBytes(StandardCharsets.UTF_8), RemoteTagCatalog.Source.ONLINE); }
        catch (Exception expected) { rejected = true; }
        check(rejected && RemoteTagCatalog.revision().equals("2099.10.02.10"), "Numeric revision ordering");
    }
}
