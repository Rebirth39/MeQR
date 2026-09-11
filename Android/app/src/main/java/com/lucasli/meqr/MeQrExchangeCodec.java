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
    private static final int ONLINE_AVATAR_TARGET_BYTES = 256 * 1024;
    private static final int ONLINE_JSON_TARGET_BYTES = 820_000;
    private static final String OFFLINE_FRAGMENT_PREFIX = "offline=";

    private MeQrExchangeCodec() {
    }

    static String encode(MeQrProfile profile, I18n i18n) throws Exception {
        return "meqr://profile?data=" + offlinePayload(profile, i18n);
    }

    static String offlinePayload(MeQrProfile profile, I18n i18n) throws Exception {
        return encodePayload(profileJson(profile, i18n, 1, 0));
    }

    static JSONObject onlineProfile(MeQrProfile profile, I18n i18n) throws Exception {
        JSONObject root = profileJson(profile, i18n, 3, ONLINE_AVATAR_TARGET_BYTES);
        String banner = imageBase64(profile.bannerPath, 80_000, 1280);
        if (!banner.isEmpty()) root.put("bn", banner);
        // Base64 expands image bytes; leave room below the server's 900 KiB limit.
        int remaining = ONLINE_JSON_TARGET_BYTES - root.toString().getBytes(StandardCharsets.UTF_8).length - 16_000;
        String background = imageBase64(profile.backgroundPath, Math.max(0, remaining) * 3 / 4, 2048);
        if (!background.isEmpty()) root.put("b", background);
        return root;
    }

    static byte[] colorLayerAvatarJpeg(MeQrProfile profile, int targetBytes) {
        if (profile == null || targetBytes <= 0) {
            return null;
        }
        return tinyAvatarJpeg(profile.avatarPath, targetBytes, true);
    }

    static String hybridCode(String remoteUrl, String offlinePayload) {
        return remoteUrl + "#offline=" + offlinePayload;
    }

    /** Decode a raw scanned string: meqr://profile?data=..., a bare payload, or a hybrid URL. */
    static MeQrExchangeProfile decode(String raw) throws Exception {
        String value = raw == null ? "" : raw.trim();
        if (value.isEmpty()) {
            throw new MeQrExchangeException();
        }
        if (value.startsWith("meqr://")) {
            int query = value.indexOf('?');
            if (query >= 0) {
                for (String pair : value.substring(query + 1).split("&")) {
                    String[] keyValue = pair.split("=", 2);
                    if (keyValue.length == 2 && "data".equals(keyValue[0])) {
                        return decodePayload(keyValue[1]);
                    }
                }
            }
            throw new MeQrExchangeException();
        }
        if (value.startsWith("http://") || value.startsWith("https://")) {
            MeQrExchangeProfile fallback = offlineFallback(value);
            if (fallback != null) {
                return fallback;
            }
            throw new MeQrExchangeException();
        }
        return decodePayload(value);
    }

    static MeQrExchangeProfile decodePayload(String payload) throws Exception {
        byte[] bytes = base64UrlDecode(payload);
        if (bytes == null) {
            throw new MeQrExchangeException();
        }
        return MeQrExchangeProfile.fromJson(new JSONObject(new String(bytes, StandardCharsets.UTF_8)));
    }

    static MeQrExchangeProfile offlineFallback(String raw) {
        if (raw == null) {
            return null;
        }
        int fragmentIndex = raw.indexOf('#');
        if (fragmentIndex < 0) {
            return null;
        }
        String fragment = raw.substring(fragmentIndex + 1);
        String payload = fragment.startsWith(OFFLINE_FRAGMENT_PREFIX)
                ? fragment.substring(OFFLINE_FRAGMENT_PREFIX.length())
                : fragment;
        try {
            return decodePayload(payload);
        } catch (Exception exception) {
            return null;
        }
    }

    static boolean isRemoteUrl(String raw) {
        if (raw == null || !(raw.startsWith("http://") || raw.startsWith("https://"))) {
            return false;
        }
        try {
            java.net.URL url = new java.net.URL(raw);
            String host = url.getHost();
            if (!MeQrRemoteService.isMeQrHost(host)) {
                return false;
            }
            return url.getPath().startsWith("/profiles/");
        } catch (Exception exception) {
            return false;
        }
    }

    /** True when a scanned string is a MeQR payload (local/offline, remote profile, or encounter URL). */
    static boolean isMeQrPayload(String raw) {
        try {
            decode(raw);
            return true;
        } catch (Exception ignored) {
        }
        return MeQrRemoteService.isEncounterSessionUrl(raw)
                || isRemoteUrl(raw)
                || offlineFallback(raw) != null;
    }

    static final class MeQrExchangeException extends Exception {
        private static final long serialVersionUID = 1L;

        MeQrExchangeException() {
        }
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
        int itemLimit = Math.min(maxProfiles, profile.qrItems.size());
        for (int i = 0; i < itemLimit; i++) {
            MeQrItem item = profile.qrItems.get(i);
            JSONObject platform = new JSONObject();
            platform.put("t", safe(item.platform));
            platform.put("n", safe(item.platformDisplayName(i18n)));
            platform.put("q", safe(item.qrContent));
            platforms.put(platform);
        }
        root.put("p", platforms);
        if (maxProfiles > 1) {
            if (!profile.tags.isEmpty()) {
                JSONArray tags = new JSONArray();
                for (String tag : profile.tags) {
                    tags.put(tag);
                }
                root.put("g", tags);
            }
            root.put("m", profile.template);
            root.put("tc", safe(profile.textColor));
            root.put("bc", safe(profile.backgroundColor));
            root.put("qc", safe(profile.qrColor));
        }
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
        byte[] jpeg = tinyAvatarJpeg(path, targetBytes, false);
        return jpeg == null ? "" : Base64.encodeToString(jpeg, Base64.NO_WRAP);
    }

    private static String imageBase64(String path, int targetBytes, int maxDimension) {
        if (path == null || path.trim().isEmpty() || targetBytes <= 0) return "";
        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inJustDecodeBounds = true;
        BitmapFactory.decodeFile(path, options);
        if (options.outWidth <= 0 || options.outHeight <= 0) return "";
        options.inSampleSize = 1;
        while (Math.max(options.outWidth, options.outHeight) / options.inSampleSize > maxDimension * 2) {
            options.inSampleSize *= 2;
        }
        options.inJustDecodeBounds = false;
        Bitmap bitmap = BitmapFactory.decodeFile(path, options);
        if (bitmap == null) return "";
        try {
            float scale = Math.min(1f, (float) maxDimension / Math.max(bitmap.getWidth(), bitmap.getHeight()));
            if (scale < 1f) {
                Bitmap resized = Bitmap.createScaledBitmap(bitmap, Math.max(1, Math.round(bitmap.getWidth() * scale)),
                        Math.max(1, Math.round(bitmap.getHeight() * scale)), true);
                if (resized != bitmap) bitmap.recycle();
                bitmap = resized;
            }
            while (true) {
                for (int quality : new int[]{88, 76, 64, 52, 40}) {
                    ByteArrayOutputStream output = new ByteArrayOutputStream();
                    if (bitmap.compress(Bitmap.CompressFormat.JPEG, quality, output) && output.size() <= targetBytes) {
                        return Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP);
                    }
                }
                if (Math.max(bitmap.getWidth(), bitmap.getHeight()) <= 32) return "";
                Bitmap resized = Bitmap.createScaledBitmap(bitmap, Math.max(1, bitmap.getWidth() * 3 / 4),
                        Math.max(1, bitmap.getHeight() * 3 / 4), true);
                bitmap.recycle();
                bitmap = resized;
            }
        } finally {
            bitmap.recycle();
        }
    }

    private static byte[] tinyAvatarJpeg(String path, int targetBytes, boolean strict) {
        if (path == null || path.trim().isEmpty()) {
            return null;
        }
        Bitmap source = BitmapFactory.decodeFile(path);
        if (source == null) {
            return null;
        }
        int size = Math.min(source.getWidth(), source.getHeight());
        if (size <= 0) {
            return null;
        }
        Bitmap square = Bitmap.createBitmap(source, (source.getWidth() - size) / 2, (source.getHeight() - size) / 2, size, size);
        int[] sizes = targetBytes >= 64 * 1024
                ? new int[]{1024, 768, 512, 384, 256, 192, 160, 144, 128, 112, 96, 80, 72, 64, 56, 48, 40, 32, 28, 24, 20, 16}
                : new int[]{256, 192, 160, 144, 128, 112, 96, 80, 72, 64, 56, 48, 40, 32, 28, 24, 20, 16};
        int[] qualities = new int[]{84, 74, 64, 54, 44, 34, 24, 16, 10};
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
                    return bytes;
                }
            }
        }
        if (strict) {
            return null;
        }
        return smallest == null || smallest.length > targetBytes * 2 ? null : smallest;
    }

    private static String base64Url(byte[] bytes) {
        return java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private static byte[] base64UrlDecode(String value) {
        return java.util.Base64.getUrlDecoder().decode(value);
    }
}
