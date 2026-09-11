package com.lucasli.meqr;

import android.content.Context;
import android.content.SharedPreferences;
import org.json.JSONArray;
import org.json.JSONObject;
import java.util.ArrayList;
import java.util.List;

final class CardTagUsageStore {
    private final SharedPreferences preferences;

    CardTagUsageStore(Context context) {
        this(context.getSharedPreferences("tag_usage_v1", Context.MODE_PRIVATE));
    }

    CardTagUsageStore(SharedPreferences preferences) {
        this.preferences = preferences;
    }

    static final class Record {
        String id;
        String name;
        int count;
        long lastUsed;

        String display(I18n i18n) {
            for (RemoteTagCatalog.Entry entry : RemoteTagCatalog.entries()) {
                if (id.equals("catalog:" + entry.id)) return entry.display(i18n.resolvedLanguage());
            }
            return name;
        }
    }

    List<Record> records(boolean frequent) {
        List<Record> result = new ArrayList<>();
        try {
            JSONArray stored = new JSONArray(preferences.getString("records", "[]"));
            for (int i = 0; i < stored.length(); i++) {
                JSONObject value = stored.getJSONObject(i);
                Record record = new Record();
                record.id = value.getString("id");
                record.name = value.getString("name");
                record.count = value.getInt("count");
                record.lastUsed = value.getLong("lastUsed");
                result.add(record);
            }
        } catch (Exception ignored) {
            result.clear();
        }
        result.sort((a, b) -> {
            if (frequent && a.count != b.count) return Integer.compare(b.count, a.count);
            int dateOrder = Long.compare(b.lastUsed, a.lastUsed);
            return dateOrder == 0 ? a.id.compareTo(b.id) : dateOrder;
        });
        return result;
    }

    void record(String tag) {
        String key = CardTagIndex.normalizedKey(tag);
        if (key.isEmpty()) return;
        String id = "custom:" + key;
        RemoteTagCatalog.Entry matched = RemoteTagCatalog.entryFor(tag);
        if (matched != null) id = "catalog:" + matched.id;
        List<Record> records = records(false);
        Record selected = null;
        for (Record record : records) {
            if (record.id.equals(id)) { selected = record; break; }
        }
        if (selected != null) records.remove(selected);
        else {
            selected = new Record();
            selected.id = id;
            selected.name = tag;
        }
        selected.count = Math.min(selected.count, 999999) + 1;
        selected.lastUsed = System.currentTimeMillis();
        records.add(0, selected);
        JSONArray data = new JSONArray();
        try {
            for (Record record : records.subList(0, Math.min(100, records.size()))) {
                JSONObject value = new JSONObject();
                value.put("id", record.id);
                value.put("name", record.name);
                value.put("count", record.count);
                value.put("lastUsed", record.lastUsed);
                data.put(value);
            }
            preferences.edit().putString("records", data.toString()).apply();
        } catch (org.json.JSONException exception) {
            throw new IllegalStateException(exception);
        }
    }

    void clear() { preferences.edit().remove("records").apply(); }

    List<Record> favorites() {
        List<Record> result = new ArrayList<>();
        try {
            JSONArray stored = new JSONArray(preferences.getString("favorites", "[]"));
            for (int i = 0; i < stored.length(); i++) {
                JSONObject value = stored.getJSONObject(i);
                Record record = new Record();
                record.id = value.getString("id"); record.name = value.getString("name");
                result.add(record);
            }
        } catch (Exception ignored) { }
        return result;
    }

    private String favoriteKey(String tag) {
        RemoteTagCatalog.Entry entry = RemoteTagCatalog.entryFor(tag);
        return entry == null ? "custom:" + CardTagIndex.normalizedKey(tag) : "catalog:" + entry.id;
    }

    boolean isFavorite(String tag) {
        for (Record record : favorites()) if (matches(record, tag)) return true;
        return false;
    }

    private boolean matches(Record record, String tag) {
        return record.id.equals(favoriteKey(tag)) || (record.id.startsWith("catalog:") && RemoteTagCatalog.entryByID(record.id.substring(8)) == null
                && CardTagIndex.normalizedKey(record.name).equals(CardTagIndex.normalizedKey(tag)));
    }

    void toggleFavorite(String tag) {
        List<Record> records = favorites();
        String key = favoriteKey(tag);
        boolean removed = records.removeIf(r -> matches(r, tag));
        if (!removed) { Record r = new Record(); r.id = key; r.name = tag; records.add(r); }
        JSONArray data = new JSONArray();
        try {
            for (Record record : records) data.put(new JSONObject().put("id", record.id).put("name", record.name));
            preferences.edit().putString("favorites", data.toString()).apply();
        } catch (org.json.JSONException error) { throw new IllegalStateException(error); }
    }
}
