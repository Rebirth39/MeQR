package com.lucasli.meqr;

import org.json.JSONException;
import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.UUID;

final class MeQrProfile {
    String id = UUID.randomUUID().toString();
    String name = "";
    String subtitle = "";
    String platform = "custom";
    String customPlatformName = "";
    String qrContent = "";
    final List<MeQrItem> qrItems = new ArrayList<>();
    final List<String> tags = new ArrayList<>();
    final Map<String, String> tagColorOverrides = new HashMap<>();
    String template = "standard";
    String avatarPath = "";
    String backgroundPath = "";
    String bannerPath = "";
    String backgroundColor = "#FFFFFF";
    String borderColor = "#111111";
    String textColor = "#111111";
    String qrColor = "#111111";
    int cornerRadius = 28;
    float cardOpacity = 1.0f;
    long createdAt = System.currentTimeMillis();
    int sortOrder = 0;

    MeQrProfile() {
        qrItems.add(new MeQrItem());
    }

    MeQrItem firstItem() {
        if (qrItems.isEmpty()) {
            qrItems.add(new MeQrItem());
        }
        return qrItems.get(0);
    }

    void syncLegacyFields() {
        MeQrItem item = firstItem();
        platform = item.platform;
        customPlatformName = item.customPlatformName;
        qrContent = item.qrContent;
    }

    String platformDisplayName(I18n i18n) {
        return firstItem().platformDisplayName(i18n);
    }

    JSONObject toJson() throws JSONException {
        syncLegacyFields();
        JSONObject object = new JSONObject();
        object.put("id", id);
        object.put("name", name);
        object.put("subtitle", subtitle);
        object.put("platform", platform);
        object.put("customPlatformName", customPlatformName);
        object.put("qrContent", qrContent);
        JSONArray itemArray = new JSONArray();
        for (MeQrItem item : qrItems) {
            itemArray.put(item.toJson());
        }
        object.put("qrItems", itemArray);
        JSONArray tagArray = new JSONArray();
        for (String tag : tags) {
            tagArray.put(tag);
        }
        object.put("tags", tagArray);
        JSONObject tagColorObject = new JSONObject();
        for (Map.Entry<String, String> entry : tagColorOverrides.entrySet()) {
            tagColorObject.put(entry.getKey(), entry.getValue());
        }
        object.put("tagColorOverrides", tagColorObject);
        object.put("template", template);
        object.put("avatarPath", avatarPath);
        object.put("backgroundPath", backgroundPath);
        object.put("bannerPath", bannerPath);
        object.put("backgroundColor", backgroundColor);
        object.put("borderColor", borderColor);
        object.put("textColor", textColor);
        object.put("qrColor", qrColor);
        object.put("cornerRadius", cornerRadius);
        object.put("cardOpacity", cardOpacity);
        object.put("createdAt", createdAt);
        object.put("sortOrder", sortOrder);
        return object;
    }

    static MeQrProfile fromJson(JSONObject object) {
        MeQrProfile profile = new MeQrProfile();
        profile.id = object.optString("id", profile.id);
        profile.name = object.optString("name", "");
        profile.subtitle = object.optString("subtitle", "");
        profile.platform = object.optString("platform", "custom");
        profile.customPlatformName = object.optString("customPlatformName", "");
        profile.qrContent = object.optString("qrContent", "");
        profile.qrItems.clear();
        JSONArray itemArray = object.optJSONArray("qrItems");
        if (itemArray != null) {
            for (int i = 0; i < itemArray.length(); i++) {
                JSONObject item = itemArray.optJSONObject(i);
                if (item != null) {
                    profile.qrItems.add(MeQrItem.fromJson(item));
                }
            }
        }
        if (profile.qrItems.isEmpty()) {
            MeQrItem legacy = new MeQrItem();
            legacy.platform = profile.platform;
            legacy.customPlatformName = profile.customPlatformName;
            legacy.qrContent = profile.qrContent;
            profile.qrItems.add(legacy);
        }
        profile.tags.clear();
        profile.tagColorOverrides.clear();
        JSONArray tagArray = object.optJSONArray("tags");
        if (tagArray != null) {
            for (int i = 0; i < tagArray.length() && profile.tags.size() < 10; i++) {
                String tag = normalizeTag(tagArray.optString(i, ""));
                boolean duplicate = false;
                for (String existing : profile.tags) {
                    if (CardTagIndex.canonicalKey(existing).equals(CardTagIndex.canonicalKey(tag))) {
                        duplicate = true;
                        break;
                    }
                }
                if (!tag.isEmpty() && !duplicate) {
                    profile.tags.add(tag);
                }
            }
        }
        JSONObject tagColorObject = object.optJSONObject("tagColorOverrides");
        if (tagColorObject != null) {
            Iterator<String> keys = tagColorObject.keys();
            while (keys.hasNext()) {
                String key = keys.next();
                String color = tagColorObject.optString(key, "");
                if (profile.tags.contains(key) && !color.isEmpty()) {
                    profile.tagColorOverrides.put(key, color);
                }
            }
        }
        profile.template = "rhodes".equals(object.optString("template", "standard")) ? "rhodes" : "standard";
        profile.avatarPath = object.optString("avatarPath", "");
        profile.backgroundPath = object.optString("backgroundPath", "");
        profile.bannerPath = object.optString("bannerPath", "");
        profile.backgroundColor = object.optString("backgroundColor", "#FFFFFF");
        profile.borderColor = object.optString("borderColor", "#111111");
        profile.textColor = object.optString("textColor", "#111111");
        profile.qrColor = object.optString("qrColor", "#111111");
        profile.cornerRadius = object.optInt("cornerRadius", 28);
        profile.cardOpacity = (float) object.optDouble("cardOpacity", 1.0);
        profile.createdAt = object.optLong("createdAt", System.currentTimeMillis());
        profile.sortOrder = object.optInt("sortOrder", 0);
        profile.syncLegacyFields();
        return profile;
    }

    static String normalizeTag(String value) {
        String trimmed = value == null ? "" : value.trim();
        StringBuilder result = new StringBuilder();
        int units = 0;
        for (int offset = 0; offset < trimmed.length();) {
            int codePoint = trimmed.codePointAt(offset);
            int next = units + (codePoint <= 0x7f ? 1 : 2);
            if (next > 20) {
                break;
            }
            result.appendCodePoint(codePoint);
            units = next;
            offset += Character.charCount(codePoint);
        }
        return result.toString();
    }
}
