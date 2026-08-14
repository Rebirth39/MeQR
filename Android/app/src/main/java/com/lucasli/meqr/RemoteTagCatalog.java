package com.lucasli.meqr;

import android.os.Handler;
import android.os.Looper;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedInputStream;
import java.io.ByteArrayOutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

final class RemoteTagCatalog {
    private static final String CATALOG_URL = "https://meqrcode.cn/config/tags-v1.json";
    private static final Handler MAIN = new Handler(Looper.getMainLooper());
    private static volatile List<Entry> entries = Collections.emptyList();
    private static volatile boolean loading;
    private static volatile String errorMessage;
    private static volatile String revision = "";

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

    static void refresh(boolean force, Runnable completion) {
        if (loading || (!force && !entries.isEmpty())) {
            if (completion != null) {
                MAIN.post(completion);
            }
            return;
        }

        loading = true;
        errorMessage = null;
        new Thread(() -> {
            try {
                HttpURLConnection connection = (HttpURLConnection) new URL(CATALOG_URL).openConnection();
                connection.setConnectTimeout(10000);
                connection.setReadTimeout(12000);
                connection.setRequestProperty("Accept", "application/json");
                connection.setRequestProperty("Cache-Control", "no-cache");
                connection.connect();
                if (connection.getResponseCode() < 200 || connection.getResponseCode() >= 300) {
                    throw new IllegalStateException("HTTP " + connection.getResponseCode());
                }

                byte[] data;
                try (BufferedInputStream input = new BufferedInputStream(connection.getInputStream());
                     ByteArrayOutputStream output = new ByteArrayOutputStream()) {
                    byte[] buffer = new byte[8192];
                    int read;
                    while ((read = input.read(buffer)) >= 0) {
                        output.write(buffer, 0, read);
                    }
                    data = output.toByteArray();
                } finally {
                    connection.disconnect();
                }

                JSONObject document = new JSONObject(new String(data, StandardCharsets.UTF_8));
                if (document.optInt("schemaVersion") != 1) {
                    throw new IllegalStateException("Unsupported Tag catalog");
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

                entries = Collections.unmodifiableList(parsed);
                revision = document.optString("revision", "");
            } catch (Exception exception) {
                errorMessage = exception.getMessage() == null ? exception.getClass().getSimpleName() : exception.getMessage();
            } finally {
                loading = false;
                if (completion != null) {
                    MAIN.post(completion);
                }
            }
        }, "MeQR-TagCatalog").start();
    }

    static List<String> suggestions(String query, I18n i18n, List<String> excluding, int limit) {
        String key = CardTagIndex.normalizedKey(query);
        Set<String> existing = new HashSet<>();
        for (String tag : excluding) {
            existing.add(canonicalKey(tag));
        }

        List<String> result = new ArrayList<>();
        for (Entry entry : entries) {
            String display = entry.display(i18n.resolvedLanguage());
            String canonical = CardTagIndex.normalizedKey(entry.names.zhHans);
            if (existing.contains(canonical) || !entry.matches(key)) {
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
        for (Entry entry : entries) {
            if (entry.exactlyMatches(key)) {
                return CardTagIndex.normalizedKey(entry.names.zhHans);
            }
        }
        return key;
    }

    static int[] colorsFor(String tag) {
        String key = CardTagIndex.normalizedKey(tag);
        for (Entry entry : entries) {
            if (!entry.exactlyMatches(key) || entry.colors.isEmpty()) {
                continue;
            }
            int[] result = new int[Math.min(entry.colors.size(), 6)];
            int count = 0;
            for (String color : entry.colors) {
                String normalized = CardTagColorPalette.normalizedHex(color);
                if (normalized != null && count < result.length) {
                    result[count++] = android.graphics.Color.parseColor(normalized);
                }
            }
            if (count == result.length) {
                return result;
            }
            int[] trimmed = new int[count];
            System.arraycopy(result, 0, trimmed, 0, count);
            return trimmed;
        }
        return new int[0];
    }

    private static final class Entry {
        final Names names;
        final List<String> aliases;
        final List<String> colors;

        Entry(Names names, List<String> aliases, List<String> colors) {
            this.names = names;
            this.aliases = aliases;
            this.colors = colors;
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
            return new Entry(names, strings(object.optJSONArray("aliases")), strings(object.optJSONArray("colors")));
        }

        boolean matches(String query) {
            if (query.isEmpty()) {
                return true;
            }
            for (String value : searchableValues()) {
                if (CardTagIndex.normalizedKey(value).contains(query)) {
                    return true;
                }
            }
            return false;
        }

        boolean exactlyMatches(String query) {
            for (String value : searchableValues()) {
                if (CardTagIndex.normalizedKey(value).equals(query)) {
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
