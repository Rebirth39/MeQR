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

    private MeQrRemoteService() {
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
}
