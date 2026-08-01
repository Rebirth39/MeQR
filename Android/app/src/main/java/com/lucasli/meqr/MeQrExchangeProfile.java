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
    String avatarBase64 = "";
    String backgroundBase64 = "";
    final List<Platform> platforms = new ArrayList<>();
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
        profile.avatarBase64 = object.optString("a", object.optString("avatarJPEGBase64", ""));
        profile.backgroundBase64 = object.optString("b", object.optString("backgroundJPEGBase64", ""));
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
        double timestamp = object.optDouble("t", object.optDouble("sharedAt", 0));
        if (timestamp > 0) {
            profile.sharedAt = (long) timestamp;
        }
        return profile;
    }
}
