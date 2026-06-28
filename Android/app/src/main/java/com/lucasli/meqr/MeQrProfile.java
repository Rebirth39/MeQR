package com.lucasli.meqr;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.UUID;

final class MeQrProfile {
    String id = UUID.randomUUID().toString();
    String name = "";
    String subtitle = "";
    String platform = "custom";
    String customPlatformName = "";
    String qrContent = "";
    String avatarPath = "";
    String backgroundPath = "";
    String backgroundColor = "#FFFFFF";
    String borderColor = "#111111";
    String textColor = "#111111";
    String qrColor = "#111111";
    int cornerRadius = 28;
    float cardOpacity = 1.0f;
    long createdAt = System.currentTimeMillis();
    int sortOrder = 0;

    String platformDisplayName(I18n i18n) {
        if ("custom".equals(platform) && customPlatformName != null && !customPlatformName.trim().isEmpty()) {
            return customPlatformName.trim();
        }
        return PlatformNames.displayName(platform, i18n);
    }

    JSONObject toJson() throws JSONException {
        JSONObject object = new JSONObject();
        object.put("id", id);
        object.put("name", name);
        object.put("subtitle", subtitle);
        object.put("platform", platform);
        object.put("customPlatformName", customPlatformName);
        object.put("qrContent", qrContent);
        object.put("avatarPath", avatarPath);
        object.put("backgroundPath", backgroundPath);
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
        profile.avatarPath = object.optString("avatarPath", "");
        profile.backgroundPath = object.optString("backgroundPath", "");
        profile.backgroundColor = object.optString("backgroundColor", "#FFFFFF");
        profile.borderColor = object.optString("borderColor", "#111111");
        profile.textColor = object.optString("textColor", "#111111");
        profile.qrColor = object.optString("qrColor", "#111111");
        profile.cornerRadius = object.optInt("cornerRadius", 28);
        profile.cardOpacity = (float) object.optDouble("cardOpacity", 1.0);
        profile.createdAt = object.optLong("createdAt", System.currentTimeMillis());
        profile.sortOrder = object.optInt("sortOrder", 0);
        return profile;
    }
}
