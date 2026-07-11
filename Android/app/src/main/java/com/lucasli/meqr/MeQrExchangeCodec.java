package com.lucasli.meqr;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.util.Base64;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.UUID;

final class MeQrExchangeCodec {
    private static final int ONLINE_AVATAR_TARGET_BYTES = 48 * 1024;

    private MeQrExchangeCodec() {
    }

    static String encode(MeQrProfile profile, I18n i18n) throws Exception {
        return "meqr://profile?data=" + offlinePayload(profile, i18n);
    }

    static String offlinePayload(MeQrProfile profile, I18n i18n) throws Exception {
        return encodePayload(profileJson(profile, i18n, 1, 0));
    }

    static JSONObject onlineProfile(MeQrProfile profile, I18n i18n) throws Exception {
        return profileJson(profile, i18n, 3, ONLINE_AVATAR_TARGET_BYTES);
    }

    static String hybridCode(String remoteUrl, String offlinePayload) {
        return remoteUrl + "#offline=" + offlinePayload;
    }

    private static JSONObject profileJson(MeQrProfile profile, I18n i18n, int maxProfiles, int avatarTargetBytes) throws Exception {
        JSONObject root = new JSONObject();
        root.put("i", safeUuid(profile.id));
        root.put("v", 1);
        root.put("n", safe(profile.name));
        root.put("s", maxProfiles == 1 ? shortSubtitle(profile.subtitle) : safe(profile.subtitle));

        String avatar = avatarTargetBytes > 0 ? tinyAvatarBase64(profile.avatarPath, avatarTargetBytes) : "";
        if (!avatar.isEmpty()) {
            root.put("a", avatar);
        }

        JSONArray platforms = new JSONArray();
        JSONObject platform = new JSONObject();
        platform.put("t", safe(profile.platform));
        platform.put("n", safe(profile.platformDisplayName(i18n)));
        platform.put("q", safe(profile.qrContent));
        platforms.put(platform);
        root.put("p", platforms);
        root.put("t", System.currentTimeMillis() / 1000L);
        return root;
    }

    private static String encodePayload(JSONObject object) {
        return base64Url(object.toString().getBytes(StandardCharsets.UTF_8));
    }

    private static String safe(String value) {
        return value == null ? "" : value.trim();
    }

    private static String safeUuid(String value) {
        try {
            return UUID.fromString(safe(value)).toString();
        } catch (Exception exception) {
            return UUID.randomUUID().toString();
        }
    }

    private static String shortSubtitle(String value) {
        String normalized = safe(value).replace("\r\n", "\n").replace('\r', '\n');
        String[] lines = normalized.split("\n", -1);
        StringBuilder builder = new StringBuilder();
        for (int i = 0; i < Math.min(2, lines.length); i++) {
            if (builder.length() > 0) {
                builder.append(' ');
            }
            builder.append(lines[i].trim());
        }
        String result = builder.toString().trim();
        return result.length() <= 25 ? result : result.substring(0, 25);
    }

    private static String tinyAvatarBase64(String path, int targetBytes) {
        if (path == null || path.trim().isEmpty()) {
            return "";
        }
        Bitmap source = BitmapFactory.decodeFile(path);
        if (source == null) {
            return "";
        }
        int size = Math.min(source.getWidth(), source.getHeight());
        if (size <= 0) {
            return "";
        }
        Bitmap square = Bitmap.createBitmap(source, (source.getWidth() - size) / 2, (source.getHeight() - size) / 2, size, size);
        int[] sizes = new int[]{256, 192, 144, 96, 72, 56};
        int[] qualities = new int[]{82, 72, 62, 52, 42, 32};
        byte[] smallest = null;
        for (int avatarSize : sizes) {
            Bitmap scaled = Bitmap.createScaledBitmap(square, avatarSize, avatarSize, true);
            for (int quality : qualities) {
                ByteArrayOutputStream output = new ByteArrayOutputStream();
                scaled.compress(Bitmap.CompressFormat.JPEG, quality, output);
                byte[] bytes = output.toByteArray();
                if (smallest == null || bytes.length < smallest.length) {
                    smallest = bytes;
                }
                if (bytes.length <= targetBytes) {
                    return Base64.encodeToString(bytes, Base64.NO_WRAP);
                }
            }
        }
        return smallest == null || smallest.length > targetBytes * 2 ? "" : Base64.encodeToString(smallest, Base64.NO_WRAP);
    }

    private static String base64Url(byte[] bytes) {
        return Base64.encodeToString(bytes, Base64.URL_SAFE | Base64.NO_PADDING | Base64.NO_WRAP);
    }
}
