package com.lucasli.meqr;

import android.content.Context;
import android.util.AtomicFile;
import android.util.Base64;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;

final class MeQrExchangeCodeStore {
    private final File directory;

    MeQrExchangeCodeStore(Context context) {
        directory = new File(context.getApplicationContext().getFilesDir(), "exchange-codes");
    }

    static final class Record {
        String fingerprint;
        String payload;
        byte[] avatar;
        String sessionId;
        String ownerToken;
        JSONObject onlineProfile;
        String eventId;
        boolean synced;

        JSONObject toJson() throws Exception {
            return new JSONObject().put("fingerprint", fingerprint).put("payload", payload)
                    .put("avatar", avatar == null ? "" : Base64.encodeToString(avatar, Base64.NO_WRAP))
                    .put("sessionId", sessionId).put("ownerToken", ownerToken)
                    .put("onlineProfile", onlineProfile).put("eventId", eventId == null ? JSONObject.NULL : eventId)
                    .put("synced", synced);
        }
    }

    static String fingerprint(MeQrProfile profile, I18n i18n, String eventId) throws Exception {
        String backgroundDigest = fileDigest(profile.backgroundPath);
        String bannerDigest = fileDigest(profile.bannerPath);
        JSONArray values = new JSONArray().put("exchange-v2").put(profile.id).put(profile.name).put(profile.subtitle)
                .put(profile.template).put(profile.textColor).put(profile.backgroundColor).put(profile.qrColor)
                .put(fileDigest(profile.avatarPath)).put(backgroundDigest).put(bannerDigest)
                .put(eventId == null ? "" : eventId);
        for (String tag : profile.tags) values.put(tag);
        for (MeQrItem item : profile.qrItems.subList(0, Math.min(3, profile.qrItems.size()))) {
            values.put(new JSONArray().put(item.platform).put(item.platformDisplayName(i18n)).put(item.qrContent));
        }
        // Published sessions are immutable; rebuild only old codes affected by the missing images.
        if (!backgroundDigest.isEmpty() || !bannerDigest.isEmpty()) values.put("online-images-v1");
        return digest(values.toString().getBytes(StandardCharsets.UTF_8));
    }

    static Record create(MeQrProfile profile, I18n i18n, String fingerprint, String eventId) throws Exception {
        Record record = new Record();
        record.fingerprint = fingerprint;
        byte[] secret = new byte[32];
        new SecureRandom().nextBytes(secret);
        record.ownerToken = hex(secret);
        record.sessionId = "v2-" + digest(record.ownerToken.getBytes(StandardCharsets.UTF_8));
        record.eventId = eventId;
        record.onlineProfile = MeQrExchangeCodec.onlineProfile(profile, i18n);
        record.payload = QrCodeGenerator.paddedForColorLayer(MeQrExchangeCodec.hybridCode(
                "https://profile.meqrcode.cn/encounter-sessions/" + record.sessionId,
                MeQrExchangeCodec.offlinePayload(profile, i18n)), 800);
        record.avatar = MeQrExchangeCodec.colorLayerAvatarJpeg(profile, QrCodeGenerator.colorLayerPayloadCapacity(record.payload));
        return record;
    }

    Record load(String profileId, String fingerprint) {
        synchronized (MeQrExchangeCodeStore.class) {
            try {
                JSONObject json = new JSONObject(new String(file(profileId).readFully(), StandardCharsets.UTF_8));
                if (!fingerprint.equals(json.getString("fingerprint"))) return null;
                Record record = new Record();
                record.fingerprint = fingerprint;
                record.payload = json.getString("payload");
                record.ownerToken = json.getString("ownerToken");
                record.sessionId = json.getString("sessionId");
                if (!record.sessionId.equals("v2-" + digest(record.ownerToken.getBytes(StandardCharsets.UTF_8)))
                        || MeQrExchangeCodec.offlineFallback(record.payload) == null) return null;
                String avatar = json.optString("avatar", "");
                record.avatar = avatar.isEmpty() ? null : Base64.decode(avatar, Base64.DEFAULT);
                record.onlineProfile = json.getJSONObject("onlineProfile");
                record.eventId = json.isNull("eventId") ? null : json.getString("eventId");
                record.synced = json.optBoolean("synced");
                return record;
            } catch (Exception exception) { return null; }
        }
    }

    void save(String profileId, Record record) throws Exception {
        synchronized (MeQrExchangeCodeStore.class) {
            if (!directory.isDirectory() && !directory.mkdirs()) throw new java.io.IOException("Cannot save exchange code");
            AtomicFile file = file(profileId);
            FileOutputStream output = file.startWrite();
            try {
                output.write(record.toJson().toString().getBytes(StandardCharsets.UTF_8));
                file.finishWrite(output);
            } catch (Exception exception) {
                file.failWrite(output);
                throw exception;
            }
        }
    }

    void markSynced(String profileId, Record record) throws Exception {
        synchronized (MeQrExchangeCodeStore.class) {
            Record current = load(profileId, record.fingerprint);
            if (current == null || !current.sessionId.equals(record.sessionId)) return;
            current.synced = true;
            save(profileId, current);
        }
    }

    private AtomicFile file(String profileId) throws Exception {
        return new AtomicFile(new File(directory, digest(profileId.getBytes(StandardCharsets.UTF_8)) + ".json"));
    }

    private static String fileDigest(String path) throws Exception {
        if (path == null || path.isEmpty() || !new File(path).isFile()) return "";
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        try (FileInputStream input = new FileInputStream(path)) {
            byte[] buffer = new byte[8192];
            int count;
            while ((count = input.read(buffer)) != -1) digest.update(buffer, 0, count);
        }
        return hex(digest.digest());
    }

    static String digest(byte[] bytes) throws Exception {
        return hex(MessageDigest.getInstance("SHA-256").digest(bytes));
    }

    private static String hex(byte[] bytes) {
        StringBuilder value = new StringBuilder();
        for (byte part : bytes) value.append(String.format(java.util.Locale.ROOT, "%02x", part & 0xff));
        return value.toString();
    }
}
