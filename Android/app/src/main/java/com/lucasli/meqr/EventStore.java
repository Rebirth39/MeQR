package com.lucasli.meqr;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CopyOnWriteArrayList;

final class EventStore {
    private static final String REMOTE_EVENTS_URL = "https://api.meqrcode.cn/events";
    private static final String ACTIVE_EVENT_KEY = "meqr_active_event_id_v1";

    private final Context context;
    private final SharedPreferences preferences;
    private final File dataFile;
    private final List<MeQrEvent> events = new CopyOnWriteArrayList<>();
    private String activeEventId;
    private boolean loadError;

    EventStore(Context context) {
        this.context = context.getApplicationContext();
        this.preferences = this.context.getSharedPreferences("settings", Context.MODE_PRIVATE);
        this.dataFile = new File(this.context.getFilesDir(), "events.json");
        this.activeEventId = preferences.getString(ACTIVE_EVENT_KEY, null);
        load();
    }

    List<MeQrEvent> events() {
        return events;
    }

    MeQrEvent activeEvent() {
        if (activeEventId == null) {
            return null;
        }
        for (MeQrEvent event : events) {
            if (event.id.equals(activeEventId)) {
                return event;
            }
        }
        return null;
    }

    void setActiveEvent(MeQrEvent event) {
        activeEventId = event == null ? null : event.id;
        preferences.edit().putString(ACTIVE_EVENT_KEY, activeEventId).apply();
    }

    MeQrEvent addCustomEvent(String title, String venue, String details) {
        MeQrEvent event = new MeQrEvent();
        event.title = title == null ? "" : title.trim();
        event.venue = venue == null ? "" : venue.trim();
        event.details = details == null ? "" : details.trim();
        event.startDate = System.currentTimeMillis();
        event.isCustom = true;
        events.add(0, event);
        save();
        return event;
    }

    void deleteCustomEvent(MeQrEvent event) {
        if (event == null || !event.isCustom) {
            return;
        }
        events.remove(event);
        if (event.id.equals(activeEventId)) {
            setActiveEvent(null);
        }
        save();
    }

    void refreshRemoteEvents() {
        new Thread(() -> {
            try {
                HttpURLConnection connection = (HttpURLConnection) new URL(REMOTE_EVENTS_URL).openConnection();
                connection.setRequestMethod("GET");
                connection.setConnectTimeout(10000);
                connection.setReadTimeout(15000);
                connection.setRequestProperty("Accept", "application/json");
                int status = connection.getResponseCode();
                java.io.InputStream stream = status >= 200 && status < 300
                        ? connection.getInputStream() : connection.getErrorStream();
                if (stream == null) {
                    connection.disconnect();
                    return;
                }
                StringBuilder response = new StringBuilder();
                try (BufferedReader reader = new BufferedReader(new InputStreamReader(stream, StandardCharsets.UTF_8))) {
                    String line;
                    while ((line = reader.readLine()) != null) {
                        response.append(line);
                    }
                }
                connection.disconnect();
                if (status >= 200 && status < 300) {
                    JSONArray remote = new JSONArray(response.toString());
                    if (remote.length() > 0) {
                        mergeRemoteEvents(remote);
                        save();
                    }
                }
            } catch (Exception ignored) {
                if (events.isEmpty()) {
                    events.add(MeQrEvent.defaultEvent());
                }
            }
        }).start();
    }

    private void mergeRemoteEvents(JSONArray remoteArray) {
        List<String> remoteIds = new ArrayList<>();
        List<MeQrEvent> remoteEvents = new ArrayList<>();
        for (int i = 0; i < remoteArray.length(); i++) {
            JSONObject object = remoteArray.optJSONObject(i);
            if (object != null) {
                MeQrEvent event = MeQrEvent.fromJson(object);
                remoteIds.add(event.id);
                remoteEvents.add(event);
            }
        }
        List<MeQrEvent> keptCustom = new ArrayList<>();
        for (MeQrEvent event : events) {
            if (event.isCustom && !remoteIds.contains(event.id)) {
                keptCustom.add(event);
            }
        }
        events.clear();
        events.addAll(keptCustom);
        events.addAll(remoteEvents);
        events.sort(Comparator.comparingLong(event -> event.startDate));
    }

    private void load() {
        events.clear();
        loadError = false;
        if (!dataFile.exists()) {
            events.add(MeQrEvent.defaultEvent());
            return;
        }
        try {
            String json = new String(Files.readAllBytes(dataFile.toPath()), StandardCharsets.UTF_8);
            JSONArray array = new JSONArray(json);
            for (int i = 0; i < array.length(); i++) {
                events.add(MeQrEvent.fromJson(array.getJSONObject(i)));
            }
        } catch (Exception ignored) {
            loadError = true;
        }
        if (events.isEmpty()) {
            events.add(MeQrEvent.defaultEvent());
        }
        if (activeEventId != null && activeEvent() == null) {
            setActiveEvent(null);
        }
    }

    private void save() {
        if (loadError && dataFile.exists() && dataFile.length() > 2) {
            return;
        }
        JSONArray array = new JSONArray();
        try {
            for (MeQrEvent event : events) {
                array.put(event.toJson());
            }
            android.util.AtomicFile atomic = new android.util.AtomicFile(dataFile);
            FileOutputStream output = null;
            try {
                output = atomic.startWrite();
                output.write(array.toString(2).getBytes(StandardCharsets.UTF_8));
                atomic.finishWrite(output);
            } catch (Exception failure) {
                if (output != null) atomic.failWrite(output);
                throw failure;
            }
            loadError = false;
        } catch (Exception ignored) {
        }
    }
}
