package com.lucasli.meqr;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

/**
 * Decoded MeQR exchange profile. Mirrors the iOS MeQRExchangeProfile payload keys:
 * i (id), v (version), n (name), s (subtitle), a (avatar jpeg base64),
 * b (background jpeg base64), p (platforms), t (sharedAt epoch seconds).
 */
final class MeQrExchangeProfile {
    String id = "";
    int version = 1;
    String name = "";
    String subtitle = "";
    String intro = "";
    String avatarBase64 = "";
    String backgroundBase64 = "";
    String bannerBase64 = "";
    String textColorHex = "";
    String backgroundColorHex = "";
    String qrColorHex = "";
    String templateStyleRawValue = "standard";
    final List<Platform> platforms = new ArrayList<>();
    final List<String> tags = new ArrayList<>();
    long sharedAt = System.currentTimeMillis() / 1000L;

    static final class Platform {
        String type = "custom";
        String name = "";
        String qrContent = "";
    }

    static MeQrExchangeProfile fromJson(JSONObject object) {
        MeQrExchangeProfile profile = new MeQrExchangeProfile();
        if (object == null) {
            return profile;
        }
        profile.id = object.optString("i", object.optString("id", ""));
        profile.version = object.optInt("v", object.optInt("version", 1));
        profile.name = object.optString("n", object.optString("name", ""));
        profile.subtitle = object.optString("s", object.optString("subtitle", ""));
        profile.intro = object.optString("u", object.optString("intro", profile.subtitle));
        profile.avatarBase64 = object.optString("a", object.optString("avatarJPEGBase64", ""));
        profile.backgroundBase64 = object.optString("b", object.optString("backgroundJPEGBase64", ""));
        profile.bannerBase64 = object.optString("bn", object.optString("bannerJPEGBase64", ""));
        profile.textColorHex = object.optString("tc", object.optString("textColorHex", ""));
        profile.backgroundColorHex = object.optString("bc", object.optString("backgroundColorHex", ""));
        profile.qrColorHex = object.optString("qc", object.optString("qrColorHex", ""));
        profile.templateStyleRawValue = object.optString("ts", object.optString("templateStyleRawValue", object.optString("m", "standard")));
        JSONArray array = object.optJSONArray("p");
        if (array == null) {
            array = object.optJSONArray("profiles");
        }
        if (array != null) {
            for (int i = 0; i < array.length(); i++) {
                JSONObject platformJson = array.optJSONObject(i);
                if (platformJson == null) {
                    continue;
                }
                Platform platform = new Platform();
                platform.type = platformJson.optString("t", platformJson.optString("platformType", "custom"));
                platform.name = platformJson.optString("n", platformJson.optString("platformName", ""));
                platform.qrContent = platformJson.optString("q", platformJson.optString("qrContent", ""));
                profile.platforms.add(platform);
            }
        }
        JSONArray tagArray = object.optJSONArray("g");
        if (tagArray == null) {
            tagArray = object.optJSONArray("tags");
        }
        if (tagArray != null) {
            for (int i = 0; i < tagArray.length(); i++) {
                String tag = tagArray.optString(i, "").trim();
                if (!tag.isEmpty() && !profile.tags.contains(tag)) {
                    profile.tags.add(tag);
                }
            }
        }
        double timestamp = object.optDouble("t", object.optDouble("sharedAt", 0));
        if (timestamp > 0) {
            profile.sharedAt = (long) timestamp;
        }
        return profile;
    }
}
