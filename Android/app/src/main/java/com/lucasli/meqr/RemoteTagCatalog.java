package com.lucasli.meqr;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedInputStream;
import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.HashMap;
import java.util.IdentityHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

final class RemoteTagCatalog {
    // Enabled in the 1.2.0 release: online catalog maintenance is complete.
    static final boolean ONLINE_ENABLED = true;
    private static final String CATALOG_URL = "https://meqrcode.cn/config/tags-v1.json";
    enum Source { BUNDLED, CACHED, ONLINE }
    private static volatile Source source = Source.BUNDLED;
    private static volatile String statusKey;
    private static long lastAttempt;
    private static final List<Runnable> completions = new ArrayList<>();
    private static final Handler MAIN = new Handler(Looper.getMainLooper());
    private static volatile List<Entry> entries = Collections.emptyList();
    private static volatile List<Category> categories = Collections.emptyList();
    private static volatile List<Group> groups = Collections.emptyList();
    private static volatile Map<String, Entry> entriesByKey = Collections.emptyMap();
    private static volatile Set<String> ambiguousKeys = Collections.emptySet();
    private static volatile Map<Category, List<Entry>> entriesByCategory = Collections.emptyMap();
    private static volatile boolean loading;
    private static volatile String errorMessage;
    private static volatile String revision = "";
    private static volatile List<Change> changelog = Collections.emptyList();

    static List<Change> changelog() { return changelog; }
    static String statusKey() { return statusKey; }
    static String sourceName(I18n i18n) {
        return i18n.t(source == Source.ONLINE ? "tagCatalogRemote" : source == Source.CACHED ? "tagCatalogCache" : "tagCatalogSource");
    }

    static final class Change {
        final String revision;
        final String date;
        final Names summary;

        Change(JSONObject value) throws org.json.JSONException {
            revision = value.getString("revision");
            date = value.getString("date");
            summary = Names.from(value.getJSONObject("summary"));
        }

        String display(String language) { return summary.display(language); }
    }

    private RemoteTagCatalog() {
    }

    static boolean isLoading() {
        return loading;
    }

    static String errorMessage() {
        return errorMessage;
    }

    static String revision() {
        return revision;
    }
    static List<Group> groups(String categoryID) { List<Group> out=new ArrayList<>(); for(Group g:groups) if(g.categoryID.equals(categoryID)) out.add(g); return out; }

    static Group groupFor(String entryID) { for(Group g:groups) if(g.contains(entryID)) return g; return null; }

    static synchronized void refresh(Context context, boolean force, Runnable completion) {
        if (loading) {
            if (completion != null) completions.add(completion);
            return;
        }
        if (!force && !entries.isEmpty() && android.os.SystemClock.elapsedRealtime() - lastAttempt < 5000) {
            if (completion != null) {
                MAIN.post(completion);
            }
            return;
        }

        loading = true;
        errorMessage = null;
        statusKey = null;
        lastAttempt = android.os.SystemClock.elapsedRealtime();
        if (completion != null) completions.add(completion);
        Context applicationContext = context.getApplicationContext();
        new Thread(() -> {
            android.util.AtomicFile cache = new android.util.AtomicFile(new java.io.File(applicationContext.getCacheDir(), "meqr-tags-v1.json"));
            if (entries.isEmpty()) {
                try {
                    install(readData(applicationContext.getAssets().open("tags-v1.json")), Source.BUNDLED);
                } catch (Exception exception) {
                    errorMessage = exception.getMessage();
                }
                if (ONLINE_ENABLED) {
                    try { install(readData(cache.openRead()), Source.CACHED); }
                    catch (Exception ignored) { /* The bundled catalog remains available. */ }
                }
            }
            try {
                if (ONLINE_ENABLED) {
                    byte[] data = download();
                    if (install(data, Source.ONLINE)) {
                        java.io.FileOutputStream output = null;
                        try {
                            output = cache.startWrite();
                            output.write(data);
                            cache.finishWrite(output);
                        } catch (java.io.IOException ignored) {
                            if (output != null) cache.failWrite(output);
                        }
                    } else {
                        statusKey = "tagCatalogMaintenance";
                    }
                }
            } catch (Exception exception) {
                if (entries.isEmpty()) errorMessage = exception.getMessage();
                else statusKey = "tagCatalogFallback";
            } finally {
                synchronized (RemoteTagCatalog.class) {
                    loading = false;
                    for (Runnable callback : completions) MAIN.post(callback);
                    completions.clear();
                }
            }
        }, "MeQR-TagCatalog").start();
    }

    private static byte[] download() throws java.io.IOException {
        java.net.HttpURLConnection connection = (java.net.HttpURLConnection) new java.net.URL(CATALOG_URL).openConnection();
        connection.setConnectTimeout(12000);
        connection.setReadTimeout(12000);
        connection.setUseCaches(false);
        connection.setRequestProperty("Accept", "application/json");
        try {
            if (connection.getResponseCode() != 200) throw new java.io.IOException("Tag catalog HTTP " + connection.getResponseCode());
            return readData(connection.getInputStream());
        } finally { connection.disconnect(); }
    }

    private static byte[] readData(java.io.InputStream stream) throws java.io.IOException {
        try (BufferedInputStream input = new BufferedInputStream(stream);
             ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[8192];
            int count;
            while ((count = input.read(buffer)) != -1) {
                if (output.size() + count > 2 * 1024 * 1024) throw new java.io.IOException("Tag catalog too large");
                output.write(buffer, 0, count);
            }
            return output.toByteArray();
        }
    }

    static boolean install(byte[] data, Source origin) throws Exception {
        JSONObject document = new JSONObject(new String(data, StandardCharsets.UTF_8));
        if (document.optInt("schemaVersion") != 1) {
            throw new IllegalStateException("Unsupported Tag catalog");
        }
        if (document.optString("revision").toLowerCase(java.util.Locale.ROOT).startsWith("maintenance")) return false;
        validate(document);
        if (!revision.isEmpty() && compareRevisions(document.getString("revision"), revision) < 0) {
            throw new IllegalStateException("Older Tag catalog");
        }
        JSONArray rawEntries = document.optJSONArray("entries");
        if (rawEntries == null || rawEntries.length() == 0) {
            throw new IllegalStateException("Empty Tag catalog");
        }

        List<Entry> parsed = new ArrayList<>();
        for (int index = 0; index < rawEntries.length(); index++) {
            JSONObject rawEntry = rawEntries.optJSONObject(index);
            if (rawEntry == null) {
                continue;
            }
            Entry entry = Entry.from(rawEntry);
            if (entry != null) {
                parsed.add(entry);
            }
        }
        if (parsed.isEmpty()) {
            throw new IllegalStateException("Invalid Tag catalog");
        }

        List<Category> parsedCategories = new ArrayList<>();
        JSONArray rawCategories = document.optJSONArray("categories");
        if (rawCategories != null) {
            for (int index = 0; index < rawCategories.length(); index++) {
                JSONObject rawCategory = rawCategories.optJSONObject(index);
                if (rawCategory != null) {
                    Category category = Category.from(rawCategory);
                    if (category != null) {
                        parsedCategories.add(category);
                    }
                }
            }
        }

        Map<String, Entry> parsedByKey = new HashMap<>();
        List<Group> parsedGroups = new ArrayList<>();
        JSONArray rawGroups = document.optJSONArray("groups");
        if (rawGroups != null) for (int i=0;i<rawGroups.length();i++) { Group g=Group.from(rawGroups.optJSONObject(i)); if(g!=null) parsedGroups.add(g); }
        Set<String> displayKeys = new HashSet<>();
        Set<String> parsedAmbiguous = new HashSet<>();
        // Full names take priority; shared nicknames remain search-only.
        for (Entry entry : parsed) {
            for (String name : entry.names.all()) {
                String key = CardTagIndex.normalizedKey(name);
                displayKeys.add(key);
                addExactKey(parsedByKey, parsedAmbiguous, key, entry);
            }
        }
        for (Entry entry : parsed) {
            for (String alias : entry.aliases) {
                String key = CardTagIndex.normalizedKey(alias);
                if (!displayKeys.contains(key)) {
                    addExactKey(parsedByKey, parsedAmbiguous, key, entry);
                }
            }
        }
        Map<Category, List<Entry>> parsedByCategory = new IdentityHashMap<>();
        for (Category category : parsedCategories) {
            List<Entry> categoryEntries = new ArrayList<>();
            for (Entry entry : parsed) {
                if (category.contains(entry.id)) {
                    categoryEntries.add(entry);
                }
            }
            parsedByCategory.put(category, Collections.unmodifiableList(categoryEntries));
        }
        for (Entry entry : parsed) {
            List<String> context = new ArrayList<>();
            Set<String> visited = new HashSet<>();
            String parentID = entry.parentID;
            while (!parentID.isEmpty() && visited.add(parentID)) {
                Entry parent = null;
                for (Entry candidate : parsed) if (candidate.id.equals(parentID)) { parent = candidate; break; }
                if (parent == null) break;
                context.addAll(parent.searchableValues());
                parentID = parent.parentID;
            }
            for (Category category : parsedCategories) {
                if (!category.contains(entry.id)) continue;
                context.addAll(category.names.all());
                List<Entry> works = new ArrayList<>();
                for (Entry work : parsedByCategory.get(category)) {
                    if (work.kind.equals("work")) works.add(work);
                }
                if (visited.isEmpty() && works.size() == 1) context.addAll(works.get(0).searchableValues());
            }
            for (String value : context) entry.contextKeys.add(CardTagIndex.normalizedKey(value));
        }

        List<Change> parsedChanges = new ArrayList<>();
        JSONArray changes = document.optJSONArray("changelog");
        if (changes != null) {
            for (int i = 0; i < changes.length(); i++) {
                parsedChanges.add(new Change(changes.getJSONObject(i)));
            }
        }
        changelog = Collections.unmodifiableList(parsedChanges);
        entries = Collections.unmodifiableList(parsed);
        categories = Collections.unmodifiableList(parsedCategories);
        groups = Collections.unmodifiableList(parsedGroups);
        entriesByKey = Collections.unmodifiableMap(parsedByKey);
        ambiguousKeys = Collections.unmodifiableSet(parsedAmbiguous);
        entriesByCategory = Collections.unmodifiableMap(parsedByCategory);
        revision = document.optString("revision", "");
        source = origin;
        errorMessage = null;
        return true;
    }

    // Validate raw values before forgiving display parsers can skip or repair them.
    private static void validate(JSONObject document) throws Exception {
        require(document.getString("revision").matches("[0-9]+(?:\\.[0-9]+)+"));
        JSONArray raw = document.getJSONArray("entries");
        require(raw.length() > 0);
        Map<String, JSONObject> byID = new HashMap<>();
        for (int i = 0; i < raw.length(); i++) {
            JSONObject entry = raw.getJSONObject(i);
            String id = entry.getString("id");
            require(!id.trim().isEmpty() && !byID.containsKey(id));
            byID.put(id, entry);
            validateNames(entry.getJSONObject("names"));
            JSONArray colors = entry.getJSONArray("colors");
            require(colors.length() >= 1 && colors.length() <= 6);
            Set<String> palette = new HashSet<>();
            for (int j = 0; j < colors.length(); j++) {
                String color = colors.getString(j);
                require(color.matches("#[0-9a-fA-F]{6}"));
                palette.add(color.toUpperCase(java.util.Locale.ROOT));
            }
            if (entry.has("solidColor") && !entry.isNull("solidColor"))
                require(palette.contains(entry.getString("solidColor").toUpperCase(java.util.Locale.ROOT)));
        }
        JSONArray categoryArray = document.getJSONArray("categories");
        require(categoryArray.length() > 0);
        Map<String, Category> categoryMap = new HashMap<>();
        for (int i = 0; i < categoryArray.length(); i++) {
            JSONObject rawCategory = categoryArray.getJSONObject(i);
            validateNames(rawCategory.getJSONObject("names"));
            validateRanges(rawCategory.getJSONArray("ranges"));
            Category category = Category.from(rawCategory);
            require(category != null && !category.id.trim().isEmpty() && !categoryMap.containsKey(category.id));
            categoryMap.put(category.id, category);
        }
        for (String id : byID.keySet()) {
            int coverage = 0;
            for (Category category : categoryMap.values()) if (category.contains(id)) coverage++;
            require(coverage == 1);
            Set<String> visited = new HashSet<>();
            String cursor = id;
            while (!cursor.isEmpty()) {
                require(visited.add(cursor) && byID.containsKey(cursor));
                cursor = byID.get(cursor).optString("parentID", "");
            }
        }
        Set<String> groupIDs = new HashSet<>();
        JSONArray groupArray = document.optJSONArray("groups");
        if (document.has("groups")) require(groupArray != null);
        if (groupArray != null) for (int i = 0; i < groupArray.length(); i++) {
            JSONObject rawGroup = groupArray.getJSONObject(i);
            validateNames(rawGroup.getJSONObject("names"));
            validateRanges(rawGroup.getJSONArray("ranges"));
            Group group = Group.from(rawGroup);
            require(group != null && !group.id.trim().isEmpty() && groupIDs.add(group.id));
            Category category = categoryMap.get(group.categoryID);
            require(category != null);
            for (String id : byID.keySet()) if (group.contains(id)) require(category.contains(id));
        }
    }

    private static void validateNames(JSONObject names) throws Exception {
        for (String key : new String[]{"zhHans", "zhHantHK", "zhHantTW", "en", "ja"})
            require(!names.getString(key).trim().isEmpty());
    }

    private static void validateRanges(JSONArray ranges) throws Exception {
        require(ranges.length() > 0);
        for (int i = 0; i < ranges.length(); i++) {
            JSONObject range = ranges.getJSONObject(i);
            String start = range.getString("start"), end = range.getString("end");
            require(!start.trim().isEmpty() && start.compareTo(end) <= 0);
        }
    }

    private static void require(boolean valid) {
        if (!valid) throw new IllegalStateException("Invalid Tag catalog");
    }

    private static int compareRevisions(String left, String right) {
        String[] a = left.split("\\."), b = right.split("\\.");
        for (int i = 0; i < Math.max(a.length, b.length); i++) {
            java.math.BigInteger x = new java.math.BigInteger(i < a.length ? a[i] : "0");
            java.math.BigInteger y = new java.math.BigInteger(i < b.length ? b[i] : "0");
            int result = x.compareTo(y);
            if (result != 0) return result;
        }
        return 0;
    }

    static final class Group {
        final String id, categoryID; final Names names; final List<Category.Range> ranges;
        Group(String i,String c,Names n,List<Category.Range> r){id=i;categoryID=c;names=n;ranges=r;}
        static Group from(JSONObject o){if(o==null)return null; String i=o.optString("id",""),c=o.optString("categoryID",""); JSONObject n=o.optJSONObject("names"); JSONArray a=o.optJSONArray("ranges"); if(i.isEmpty()||c.isEmpty()||n==null||a==null)return null; List<Category.Range> r=new ArrayList<>();for(int j=0;j<a.length();j++){Category.Range x=Category.Range.from(a.optJSONObject(j));if(x!=null)r.add(x);}return r.isEmpty()?null:new Group(i,c,Names.from(n),r);}
        boolean contains(String id){for(Category.Range r:ranges)if(r.contains(id))return true;return false;}
        String display(String l){return names.display(l);}
    }

    private static void addExactKey(Map<String, Entry> index, Set<String> ambiguous, String key, Entry entry) {
        if (key.isEmpty() || ambiguous.contains(key)) return;
        Entry previous = index.get(key);
        if (previous != null && !previous.id.equals(entry.id)) {
            index.remove(key);
            ambiguous.add(key);
        } else {
            index.put(key, entry);
        }
    }

    static List<String> suggestions(String query, I18n i18n, List<String> excluding, int limit) {
        String key = CardTagIndex.normalizedKey(query);
        Set<String> existing = new HashSet<>();
        for (String tag : excluding) {
            existing.add(canonicalKey(tag));
        }

        List<String> result = new ArrayList<>();
        List<Entry> ranked = new ArrayList<>();
        for (Entry entry : entries) if (entry.searchScore(query) < 99) ranked.add(entry);
        ranked.sort((a, b) -> {
            int score = Integer.compare(a.searchScore(query), b.searchScore(query));
            return score == 0 ? a.id.compareTo(b.id) : score;
        });
        for (Entry entry : ranked) {
            String display = entry.display(i18n.resolvedLanguage());
            String canonical = CardTagIndex.normalizedKey(entry.names.zhHans);
            if (existing.contains(canonical)) {
                continue;
            }
            result.add(display);
            if (result.size() >= limit) {
                break;
            }
        }
        return result;
    }

    static String canonicalKey(String value) {
        String key = CardTagIndex.normalizedKey(value);
        Entry entry = entriesByKey.get(key);
        return entry == null ? key : entry.canonicalKey;
    }

    static Entry entryFor(String value) { return entriesByKey.get(CardTagIndex.normalizedKey(value)); }
    static Entry entryByID(String id) {
        for (Entry entry : entries) if (entry.id.equals(id)) return entry;
        return null;
    }

    static String subtitle(Entry entry, I18n i18n) {
        String categoryName = "";
        for (Category category : categories) {
            if (category.contains(entry.id)) { categoryName = category.display(i18n.resolvedLanguage()); break; }
        }
        Entry parent = entryByID(entry.parentID);
        Group group = groupFor(entry.id);
        String kind = i18n.t(entry.kind.equals("work") ? "tagKindWork" : entry.kind.equals("group") ? "tagKindGroup" : entry.kind.equals("rating") ? "tagKindRating" : "tagKindCharacter");
        String detail = group != null ? group.display(i18n.resolvedLanguage()) : parent == null ? kind : parent.display(i18n.resolvedLanguage());
        return entry.kind.equals("work") ? kind : categoryName + " · " + detail;
    }

    static int[] colorsFor(String tag) {
        String key = CardTagIndex.normalizedKey(tag);
        if (ambiguousKeys.contains(key)) return new int[]{0xFF6F7582};
        Entry entry = entriesByKey.get(key);
        return entry == null ? new int[0] : entry.colors.clone();
    }

    static Integer solidColorFor(String tag) {
        if (ambiguousKeys.contains(CardTagIndex.normalizedKey(tag))) return 0xFF6F7582;
        Entry entry = entriesByKey.get(CardTagIndex.normalizedKey(tag));
        return entry == null ? null : entry.solidColor;
    }

    static List<Entry> featuredEntries(int limit) {
        List<Entry> result = new ArrayList<>();
        for (Entry entry : entries) {
            result.add(entry);
            if (result.size() >= limit) {
                break;
            }
        }
        return result;
    }

    static List<Category> categories() {
        return categories;
    }

    static List<Entry> entriesIn(Category category) {
        List<Entry> result = entriesByCategory.get(category);
        return result == null ? Collections.emptyList() : result;
    }

    static List<Entry> entries() {
        return entries;
    }

    static final class Category {
        final String id;
        final Names names;
        final List<Category.Range> ranges;

        Category(String id, Names names, List<Category.Range> ranges) {
            this.id = id;
            this.names = names;
            this.ranges = ranges;
        }

        static Category from(JSONObject object) {
            String id = object.optString("id", "");
            JSONObject rawNames = object.optJSONObject("names");
            if (id.isEmpty() || rawNames == null) {
                return null;
            }
            Names names = Names.from(rawNames);
            if (names.zhHans.isEmpty()) {
                return null;
            }
            List<Category.Range> ranges = new ArrayList<>();
            JSONArray rawRanges = object.optJSONArray("ranges");
            if (rawRanges != null) {
                for (int index = 0; index < rawRanges.length(); index++) {
                    JSONObject rawRange = rawRanges.optJSONObject(index);
                    if (rawRange != null) {
                        Range range = Range.from(rawRange);
                        if (range != null) {
                            ranges.add(range);
                        }
                    }
                }
            }
            if (ranges.isEmpty()) {
                return null;
            }
            return new Category(id, names, ranges);
        }

        boolean contains(String entryId) {
            for (Range range : ranges) {
                if (range.contains(entryId)) {
                    return true;
                }
            }
            return false;
        }

        String display(String language) {
            return names.display(language);
        }

        private static final class Range {
            final String start;
            final String end;

            Range(String start, String end) {
                this.start = start;
                this.end = end;
            }

            static Range from(JSONObject object) {
                String start = object.optString("start", "");
                String end = object.optString("end", "");
                if (start.isEmpty() || end.isEmpty()) {
                    return null;
                }
                return new Range(start, end);
            }

            boolean contains(String entryId) {
                return entryId != null && entryId.compareTo(start) >= 0 && entryId.compareTo(end) <= 0;
            }
        }
    }

    static final class Entry {
        final String id;
        final Names names;
        final List<String> aliases;
        final List<String> searchableKeys;
        final String canonicalKey;
        final int[] colors;
        Integer solidColor;
        String kind = "character";
        String parentID = "";
        final List<String> contextKeys = new ArrayList<>();

        Entry(String id, Names names, List<String> aliases, List<String> rawColors) {
            this.id = id;
            this.names = names;
            this.aliases = aliases;
            this.canonicalKey = CardTagIndex.normalizedKey(names.zhHans);
            List<String> keys = new ArrayList<>();
            for (String value : searchableValues()) {
                String key = CardTagIndex.normalizedKey(value);
                if (!key.isEmpty() && !keys.contains(key)) {
                    keys.add(key);
                }
            }
            this.searchableKeys = Collections.unmodifiableList(keys);
            List<Integer> parsedColors = new ArrayList<>();
            for (String color : rawColors) {
                String normalized = CardTagColorPalette.normalizedHex(color);
                if (normalized != null && parsedColors.size() < 6) {
                    parsedColors.add(android.graphics.Color.parseColor(normalized));
                }
            }
            if (parsedColors.isEmpty()) {
                parsedColors.add(0xFF6F7582);
            }
            this.colors = new int[parsedColors.size()];
            for (int index = 0; index < parsedColors.size(); index++) {
                this.colors[index] = parsedColors.get(index);
            }
        }

        static Entry from(JSONObject object) {
            JSONObject rawNames = object.optJSONObject("names");
            if (rawNames == null) {
                return null;
            }
            Names names = Names.from(rawNames);
            if (names.zhHans.isEmpty()) {
                return null;
            }
            Entry entry = new Entry(object.optString("id", ""), names, strings(object.optJSONArray("aliases")), strings(object.optJSONArray("colors")));
            String solid = CardTagColorPalette.normalizedHex(object.optString("solidColor", ""));
            if (solid != null) entry.solidColor = android.graphics.Color.parseColor(solid);
            entry.kind = object.optString("kind", "character");
            entry.parentID = object.optString("parentID", "");
            return entry;
        }

        int searchScore(String query) {
            String key = CardTagIndex.normalizedKey(query);
            if (key.isEmpty()) return 5;
            for (String name : names.all()) if (CardTagIndex.normalizedKey(name).equals(key)) return 0;
            for (String alias : aliases) if (CardTagIndex.normalizedKey(alias).equals(key)) return 1;
            for (String name : names.all()) if (CardTagIndex.normalizedKey(name).startsWith(key)) return 2;
            for (String alias : aliases) if (CardTagIndex.normalizedKey(alias).startsWith(key)) return 3;
            if (matches(key)) return 4;
            for (String token : query.trim().split("\\s+")) {
                String normalized = CardTagIndex.normalizedKey(token);
                boolean found = false;
                for (String candidate : searchableKeys) if (candidate.contains(normalized)) found = true;
                for (String candidate : contextKeys) if (candidate.contains(normalized)) found = true;
                if (!found) return 99;
            }
            return 5;
        }

        boolean matches(String query) {
            if (query.isEmpty()) {
                return true;
            }
            for (String key : searchableKeys) {
                if (key.contains(query)) {
                    return true;
                }
            }
            return false;
        }

        List<String> searchableValues() {
            List<String> values = new ArrayList<>(names.all());
            values.addAll(aliases);
            return values;
        }

        String display(String language) {
            if (I18n.EN.equals(language)) {
                return names.en;
            }
            if (I18n.JA.equals(language)) {
                return names.ja;
            }
            if (I18n.ZH_HANT_HK.equals(language)) {
                return names.zhHantHK;
            }
            if (I18n.ZH_HANT_TW.equals(language)) {
                return names.zhHantTW;
            }
            return names.zhHans;
        }
    }

    private static final class Names {
        final String zhHans;
        final String zhHantHK;
        final String zhHantTW;
        final String en;
        final String ja;

        Names(String zhHans, String zhHantHK, String zhHantTW, String en, String ja) {
            this.zhHans = zhHans;
            this.zhHantHK = zhHantHK;
            this.zhHantTW = zhHantTW;
            this.en = en;
            this.ja = ja;
        }

        static Names from(JSONObject object) {
            return new Names(
                    object.optString("zhHans", ""),
                    object.optString("zhHantHK", object.optString("zhHans", "")),
                    object.optString("zhHantTW", object.optString("zhHans", "")),
                    object.optString("en", object.optString("zhHans", "")),
                    object.optString("ja", object.optString("zhHans", ""))
            );
        }

        List<String> all() {
            List<String> values = new ArrayList<>();
            values.add(zhHans);
            values.add(zhHantHK);
            values.add(zhHantTW);
            values.add(en);
            values.add(ja);
            return values;
        }

        String display(String language) {
            if (I18n.EN.equals(language)) {
                return en;
            }
            if (I18n.JA.equals(language)) {
                return ja;
            }
            if (I18n.ZH_HANT_HK.equals(language)) {
                return zhHantHK;
            }
            if (I18n.ZH_HANT_TW.equals(language)) {
                return zhHantTW;
            }
            return zhHans;
        }
    }

    private static List<String> strings(JSONArray array) {
        if (array == null) {
            return Collections.emptyList();
        }
        List<String> values = new ArrayList<>();
        for (int index = 0; index < array.length(); index++) {
            String value = array.optString(index, "").trim();
            if (!value.isEmpty()) {
                values.add(value);
            }
        }
        return values;
    }
}
