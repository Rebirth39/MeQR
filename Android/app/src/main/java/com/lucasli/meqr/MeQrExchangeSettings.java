package com.lucasli.meqr;

import android.content.Context;
import android.content.SharedPreferences;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

final class MeQrExchangeSettings {
    private static final String PREFS = "exchange-settings-v1";

    String shortIntroduction;
    final List<String> onlineItemIds = new ArrayList<>();
    String offlineItemId;

    static MeQrExchangeSettings load(Context context, MeQrProfile profile) {
        SharedPreferences preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        String prefix = profile.id + ".";
        MeQrExchangeSettings settings = new MeQrExchangeSettings();
        settings.shortIntroduction = preferences.getString(prefix + "shortIntroduction", defaultShortIntroduction(profile.subtitle));
        Set<String> saved = preferences.getStringSet(prefix + "onlineItems", null);
        if (saved != null) settings.onlineItemIds.addAll(saved);
        settings.onlineItemIds.removeIf(id -> find(profile, id) == null);
        if (settings.onlineItemIds.isEmpty()) {
            for (int index = 0; index < Math.min(3, profile.qrItems.size()); index++) {
                settings.onlineItemIds.add(profile.qrItems.get(index).id);
            }
        }
        settings.offlineItemId = preferences.getString(prefix + "offlineItem", null);
        if (find(profile, settings.offlineItemId) == null || !settings.onlineItemIds.contains(settings.offlineItemId)) {
            settings.offlineItemId = settings.onlineItemIds.isEmpty() ? null : settings.onlineItemIds.get(0);
        }
        return settings;
    }

    void save(Context context, MeQrProfile profile) {
        String prefix = profile.id + ".";
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString(prefix + "shortIntroduction", limitedShortIntroduction(shortIntroduction))
                .putStringSet(prefix + "onlineItems", new HashSet<>(onlineItemIds))
                .putString(prefix + "offlineItem", offlineItemId)
                .apply();
    }

    List<MeQrItem> onlineItems(MeQrProfile profile) {
        List<MeQrItem> items = new ArrayList<>();
        for (MeQrItem item : profile.qrItems) {
            if (onlineItemIds.contains(item.id) && items.size() < 3) items.add(item);
        }
        return items;
    }

    MeQrItem offlineItem(MeQrProfile profile) {
        MeQrItem selected = find(profile, offlineItemId);
        if (selected != null && onlineItemIds.contains(selected.id)) return selected;
        List<MeQrItem> online = onlineItems(profile);
        return online.isEmpty() ? null : online.get(0);
    }

    static String limitedShortIntroduction(String value) {
        String normalized = value == null ? "" : value.replace("\r\n", "\n").replace('\r', '\n');
        String[] lines = normalized.split("\n", -1);
        StringBuilder builder = new StringBuilder();
        for (int index = 0; index < Math.min(2, lines.length); index++) {
            if (builder.length() > 0) builder.append(' ');
            builder.append(lines[index].trim());
        }
        String result = builder.toString().trim();
        return result.length() <= 25 ? result : result.substring(0, 25);
    }

    private static String defaultShortIntroduction(String value) {
        return limitedShortIntroduction(value);
    }

    private static MeQrItem find(MeQrProfile profile, String id) {
        if (id == null) return null;
        for (MeQrItem item : profile.qrItems) if (id.equals(item.id)) return item;
        return null;
    }
}
