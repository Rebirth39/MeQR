package com.lucasli.meqr;

import android.content.Context;

import org.json.JSONArray;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

final class EncounterStore {
    interface SessionFetcher {
        MeQrRemoteService.EncounterSession fetch(String url, String ownerToken) throws Exception;
    }
    private final Context context;
    private final SessionFetcher sessionFetcher;
    private final File dataFile;
    private final File pendingFile;
    private final List<EncounterRecord> records = new ArrayList<>();
    private final List<String> pendingSessionIds = new ArrayList<>();
    private final android.content.SharedPreferences sessionState;
    private boolean syncing;

    EncounterStore(Context context) {
        this(context, MeQrRemoteService::fetchEncounterSession);
    }

    EncounterStore(Context context, SessionFetcher sessionFetcher) {
        this.context = context.getApplicationContext();
        this.sessionFetcher = sessionFetcher;
        sessionState = context.getApplicationContext().getSharedPreferences("exchange-session-state", Context.MODE_PRIVATE);
        this.dataFile = new File(context.getApplicationContext().getFilesDir(), "encounters.json");
        this.pendingFile = new File(context.getApplicationContext().getFilesDir(), "encounter-pending.json");
        load();
    }

    List<EncounterRecord> records() {
        return records;
    }

    synchronized int pendingCount() {
        return pendingSessionIds.size();
    }

    void add(MeQrExchangeProfile profile, MeQrEvent event) {
        add(profile, event, null);
    }

    void add(MeQrExchangeProfile profile, MeQrEvent event, String sessionID) {
        if (sessionID != null && !sessionID.isEmpty()) {
            for (EncounterRecord record : records) {
                if (sessionID.equals(record.sessionID)) {
                    return;
                }
            }
        }
        records.add(0, EncounterRecord.fromExchangeProfile(profile, event, sessionID));
        save();
    }

    synchronized void registerOutgoingSession(String sessionID) {
        if (sessionID == null || sessionID.trim().isEmpty() || pendingSessionIds.contains(sessionID)) {
            return;
        }
        pendingSessionIds.add(0, sessionID);
        savePending();
    }

    synchronized void registerOutgoingSession(String sessionID, String ownerToken) {
        sessionState.edit().putString("owner:" + sessionID, ownerToken).apply();
        registerOutgoingSession(sessionID);
    }

    synchronized void syncPendingSessions(Runnable completion) {
        if (syncing) {
            if (completion != null) completion.run();
            return;
        }
        final List<String> pending = new ArrayList<>(pendingSessionIds);
        if (pending.isEmpty()) {
            if (completion != null) completion.run();
            return;
        }
        syncing = true;
        new Thread(() -> {
            List<String> completed = new ArrayList<>();
            for (String sessionId : pending) {
                try {
                    MeQrRemoteService.EncounterSession session = sessionFetcher.fetch(
                            "https://api.meqrcode.cn/encounter-sessions/" + sessionId, sessionState.getString("owner:" + sessionId, null));
                    MeQrEvent sessionEvent = null;
                    for (MeQrEvent event : new EventStore(context).events()) {
                        if (event.id.equals(session.eventId)) { sessionEvent = event; break; }
                    }
                    if (session.reusable) {
                        java.util.Set<String> received = new java.util.HashSet<>(sessionState.getStringSet("received:" + sessionId, java.util.Collections.emptySet()));
                        for (MeQrRemoteService.Confirmation confirmation : session.confirmations) {
                            if (!received.contains(confirmation.id)) {
                                add(confirmation.profile, sessionEvent, sessionId + ":" + confirmation.id);
                                for (EncounterRecord record : records) {
                                    if ((sessionId + ":" + confirmation.id).equals(record.sessionID)) {
                                        record.metAt = confirmation.confirmedAt;
                                        record.eventId = session.eventId;
                                    }
                                }
                                received.add(confirmation.id);
                            }
                        }
                        records.sort(Comparator.comparingLong(record -> -record.metAt));
                        save();
                        sessionState.edit().putStringSet("received:" + sessionId, received).apply();
                    } else if ("confirmed".equalsIgnoreCase(session.status) && session.peerProfile != null) {
                        add(session.peerProfile, sessionEvent, sessionId);
                        for (EncounterRecord record : records) {
                            if (sessionId.equals(record.sessionID)) record.eventId = session.eventId;
                        }
                        save();
                        completed.add(sessionId);
                    }
                } catch (Exception ignored) {}
            }
            synchronized (this) {
                pendingSessionIds.removeAll(completed);
                syncing = false;
                savePending();
            }
            if (completion != null) completion.run();
        }).start();
    }

    void update(EncounterRecord record) {
        for (int i = 0; i < records.size(); i++) {
            if (records.get(i).id.equals(record.id)) {
                records.set(i, record);
                break;
            }
        }
        records.sort(Comparator.comparingLong(recordItem -> -recordItem.metAt));
        save();
    }

    void delete(EncounterRecord record) {
        records.removeIf(item -> item.id.equals(record.id));
        save();
    }

    private void load() {
        records.clear();
        if (dataFile.exists()) try {
            String json = new String(Files.readAllBytes(dataFile.toPath()), StandardCharsets.UTF_8);
            JSONArray array = new JSONArray(json);
            for (int i = 0; i < array.length(); i++) {
                records.add(EncounterRecord.fromJson(array.getJSONObject(i)));
            }
        } catch (Exception ignored) {
            records.clear();
        }
        records.sort(Comparator.comparingLong(record -> -record.metAt));
        pendingSessionIds.clear();
        if (pendingFile.exists()) {
            try {
                JSONArray pending = new JSONArray(new String(Files.readAllBytes(pendingFile.toPath()), StandardCharsets.UTF_8));
                for (int i = 0; i < pending.length(); i++) {
                    String sessionId = pending.optString(i, "");
                    if (!sessionId.isEmpty() && !pendingSessionIds.contains(sessionId)) {
                        pendingSessionIds.add(sessionId);
                    }
                }
            } catch (Exception ignored) {
                pendingSessionIds.clear();
            }
        }
    }

    private void save() {
        JSONArray array = new JSONArray();
        try {
            for (EncounterRecord record : records) {
                array.put(record.toJson());
            }
            try (FileOutputStream output = new FileOutputStream(dataFile, false)) {
                output.write(array.toString(2).getBytes(StandardCharsets.UTF_8));
            }
        } catch (Exception ignored) {
        }
    }

    private synchronized void savePending() {
        JSONArray array = new JSONArray();
        for (String sessionId : pendingSessionIds) {
            array.put(sessionId);
        }
        try (FileOutputStream output = new FileOutputStream(pendingFile, false)) {
            output.write(array.toString(2).getBytes(StandardCharsets.UTF_8));
        } catch (Exception ignored) {
        }
    }
}
