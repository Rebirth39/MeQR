package com.lucasli.meqr;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.OutputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

final class MeQrRemoteService {
    private static final String API_BASE_URL = "https://api.meqrcode.cn";
    static final String API_HOST = "api.meqrcode.cn";
    static final String PROFILE_HOST = "profile.meqrcode.cn";

    private MeQrRemoteService() {
    }

    static boolean isMeQrHost(String host) {
        return API_HOST.equalsIgnoreCase(host) || PROFILE_HOST.equalsIgnoreCase(host);
    }

    static String uploadProfile(JSONObject profile) throws Exception {
        URL url = new URL(API_BASE_URL + "/profiles");
        HttpURLConnection connection = (HttpURLConnection) url.openConnection();
        connection.setRequestMethod("POST");
        connection.setConnectTimeout(10000);
        connection.setReadTimeout(15000);
        connection.setDoOutput(true);
        connection.setRequestProperty("Content-Type", "application/json; charset=utf-8");
        connection.setRequestProperty("Accept", "application/json");
        connection.setRequestProperty("User-Agent", "MeQR Android");

        JSONObject body = new JSONObject();
        body.put("profile", profile);
        byte[] bytes = body.toString().getBytes(StandardCharsets.UTF_8);
        connection.setFixedLengthStreamingMode(bytes.length);

        try (OutputStream output = connection.getOutputStream()) {
            output.write(bytes);
        }

        int status = connection.getResponseCode();
        StringBuilder response = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(
            status >= 200 && status < 300 ? connection.getInputStream() : connection.getErrorStream(),
            StandardCharsets.UTF_8
        ))) {
            String line;
            while ((line = reader.readLine()) != null) {
                response.append(line);
            }
        }
        connection.disconnect();

        JSONObject json = new JSONObject(response.toString());
        if (status < 200 || status >= 300) {
            throw new IllegalStateException(json.optString("error", "MeQR upload failed."));
        }
        String uploadedUrl = json.optString("url", "");
        if (uploadedUrl.trim().isEmpty()) {
            throw new IllegalStateException("MeQR upload did not return a URL.");
        }
        return uploadedUrl;
    }

    static MeQrExchangeProfile fetchProfile(String url) throws Exception {
        HttpURLConnection connection = (HttpURLConnection) new URL(url).openConnection();
        connection.setRequestMethod("GET");
        connection.setConnectTimeout(10000);
        connection.setReadTimeout(15000);
        connection.setRequestProperty("Accept", "application/json");
        connection.setRequestProperty("User-Agent", "MeQR Android");

        int status = connection.getResponseCode();
        StringBuilder response = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(
            status >= 200 && status < 300 ? connection.getInputStream() : connection.getErrorStream(),
            StandardCharsets.UTF_8
        ))) {
            String line;
            while ((line = reader.readLine()) != null) {
                response.append(line);
            }
        }
        connection.disconnect();

        JSONObject json = new JSONObject(response.toString());
        if (status < 200 || status >= 300) {
            throw new IllegalStateException(json.optString("error", "MeQR fetch failed."));
        }
        JSONObject profileJson = json.has("profile") ? json.optJSONObject("profile") : json;
        if (profileJson == null) {
            throw new IllegalStateException("MeQR fetch returned an empty profile.");
        }
        return MeQrExchangeProfile.fromJson(profileJson);
    }

    static void publishExchangeCode(MeQrExchangeCodeStore.Record record) throws Exception {
        JSONObject body = new JSONObject().put("creatorProfile", record.onlineProfile)
                .put("eventId", record.eventId == null ? JSONObject.NULL : record.eventId);
        requestJson("POST", API_BASE_URL + "/encounter-sessions/" + record.sessionId, body, record.ownerToken);
    }

    static boolean isEncounterSessionUrl(String raw) {
        if (raw == null || !(raw.startsWith("http://") || raw.startsWith("https://"))) {
            return false;
        }
        try {
            URL url = new URL(raw);
            return MeQrRemoteService.isMeQrHost(url.getHost())
                    && url.getPath().startsWith("/encounter-sessions/");
        } catch (Exception exception) {
            return false;
        }
    }

    static EncounterSession createEncounterSession(JSONObject creatorProfile, String eventId) throws Exception {
        JSONObject body = new JSONObject();
        body.put("creatorProfile", creatorProfile);
        if (eventId != null && !eventId.trim().isEmpty()) {
            body.put("eventId", eventId);
        } else {
            body.put("eventId", JSONObject.NULL);
        }
        JSONObject json = requestJson("POST", API_BASE_URL + "/encounter-sessions", body);
        String sessionId = json.optString("sessionId", "");
        String url = json.optString("url", "");
        if (sessionId.trim().isEmpty() || url.trim().isEmpty()) {
            throw new IllegalStateException("Encounter session response was incomplete.");
        }
        return new EncounterSession(sessionId, url, null, null, "waiting", json.optString("eventId", null));
    }

    static EncounterSession fetchEncounterSession(String url) throws Exception {
        return fetchEncounterSession(url, null);
    }

    static EncounterSession fetchEncounterSession(String url, String ownerToken) throws Exception {
        if (!isEncounterSessionUrl(url)) {
            throw new IllegalArgumentException("Unsupported encounter session URL.");
        }
        JSONObject json = requestJson("GET", url, null, ownerToken);
        JSONObject creatorJson = json.optJSONObject("creatorProfile");
        JSONObject peerJson = json.optJSONObject("peerProfile");
        EncounterSession session = new EncounterSession(
                json.optString("sessionId", ""),
                url,
                creatorJson == null ? null : MeQrExchangeProfile.fromJson(creatorJson),
                peerJson == null ? null : MeQrExchangeProfile.fromJson(peerJson),
                json.optString("status", "waiting"),
                json.isNull("eventId") ? null : json.optString("eventId", null)
        );
        session.reusable = json.optBoolean("reusable");
        org.json.JSONArray confirmations = json.optJSONArray("confirmations");
        if (confirmations != null) {
            for (int index = 0; index < confirmations.length(); index++) {
                JSONObject confirmation = confirmations.getJSONObject(index);
                session.confirmations.add(new Confirmation(confirmation.getString("id"),
                        MeQrExchangeProfile.fromJson(confirmation.getJSONObject("profile")), confirmation.getLong("confirmedAt")));
            }
        }
        return session;
    }

    static void confirmEncounterSession(String sessionId, JSONObject peerProfile) throws Exception {
        if (sessionId == null || sessionId.trim().isEmpty()) {
            throw new IllegalArgumentException("Missing encounter session ID.");
        }
        JSONObject body = new JSONObject();
        body.put("peerProfile", peerProfile);
        requestJson("POST", API_BASE_URL + "/encounter-sessions/" + sessionId + "/confirm", body);
    }

    private static JSONObject requestJson(String method, String rawUrl, JSONObject body) throws Exception {
        return requestJson(method, rawUrl, body, null);
    }

    private static JSONObject requestJson(String method, String rawUrl, JSONObject body, String ownerToken) throws Exception {
        HttpURLConnection connection = (HttpURLConnection) new URL(rawUrl).openConnection();
        connection.setRequestMethod(method);
        connection.setConnectTimeout(10000);
        connection.setReadTimeout(15000);
        connection.setRequestProperty("Accept", "application/json");
        connection.setRequestProperty("User-Agent", "MeQR Android");
        if (ownerToken != null) connection.setRequestProperty("X-MeQR-Owner", ownerToken);
        if (body != null) {
            connection.setDoOutput(true);
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8");
            byte[] bytes = body.toString().getBytes(StandardCharsets.UTF_8);
            connection.setFixedLengthStreamingMode(bytes.length);
            try (OutputStream output = connection.getOutputStream()) {
                output.write(bytes);
            }
        }
        int status = connection.getResponseCode();
        StringBuilder response = new StringBuilder();
        java.io.InputStream stream = status >= 200 && status < 300
                ? connection.getInputStream() : connection.getErrorStream();
        if (stream != null) {
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(stream, StandardCharsets.UTF_8))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    response.append(line);
                }
            }
        }
        connection.disconnect();
        JSONObject json = response.length() == 0 ? new JSONObject() : new JSONObject(response.toString());
        if (status < 200 || status >= 300) {
            throw new IllegalStateException(json.optString("error", "MeQR request failed (HTTP " + status + ")."));
        }
        return json;
    }

    static final class EncounterSession {
        final String sessionId;
        final String url;
        final MeQrExchangeProfile creatorProfile;
        final MeQrExchangeProfile peerProfile;
        final String status;
        final String eventId;
        boolean reusable;
        final java.util.List<Confirmation> confirmations = new java.util.ArrayList<>();

        EncounterSession(String sessionId, String url, MeQrExchangeProfile creatorProfile,
                         MeQrExchangeProfile peerProfile, String status, String eventId) {
            this.sessionId = sessionId;
            this.url = url;
            this.creatorProfile = creatorProfile;
            this.peerProfile = peerProfile;
            this.status = status;
            this.eventId = eventId;
        }
    }

    static final class Confirmation {
        final String id;
        final MeQrExchangeProfile profile;
        final long confirmedAt;
        Confirmation(String id, MeQrExchangeProfile profile, long confirmedAt) {
            this.id = id;
            this.profile = profile;
            this.confirmedAt = confirmedAt;
        }
    }
}
