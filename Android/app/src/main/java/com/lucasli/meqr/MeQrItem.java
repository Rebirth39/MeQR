package com.lucasli.meqr;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.UUID;

final class MeQrItem {
    String id = UUID.randomUUID().toString();
    String platform = "custom";
    String customPlatformName = "";
    String qrContent = "";

    String platformDisplayName(I18n i18n) {
        if ("custom".equals(platform) && customPlatformName != null && !customPlatformName.trim().isEmpty()) {
            return customPlatformName.trim();
        }
        return PlatformNames.displayName(platform, i18n);
    }

    JSONObject toJson() throws JSONException {
        JSONObject object = new JSONObject();
        object.put("id", id);
        object.put("platform", platform);
        object.put("customPlatformName", customPlatformName);
        object.put("qrContent", qrContent);
        return object;
    }

    static MeQrItem fromJson(JSONObject object) {
        MeQrItem item = new MeQrItem();
        item.id = object.optString("id", item.id);
        item.platform = object.optString("platform", "custom");
        item.customPlatformName = object.optString("customPlatformName", "");
        item.qrContent = object.optString("qrContent", "");
        return item;
    }

    MeQrItem copy() {
        MeQrItem copy = new MeQrItem();
        copy.id = id;
        copy.platform = platform;
        copy.customPlatformName = customPlatformName;
        copy.qrContent = qrContent;
        return copy;
    }
}
