package com.lucasli.meqr;

import android.content.Context;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

final class EncounterStore {
    interface SessionFetcher {
        MeQrRemoteService.EncounterSession fetch(String url, String ownerToken) throws Exception;
    }
    interface ConfirmationSender {
        void send(String sessionID, JSONObject profile) throws Exception;
    }
    private final Context context;
    private final SessionFetcher sessionFetcher;
    private final ConfirmationSender confirmationSender;
    private final File dataFile;
    private final File pendingFile;
    private final List<EncounterRecord> records = new CopyOnWriteArrayList<>();
    private final List<String> pendingSessionIds = new ArrayList<>();
    private final android.content.SharedPreferences sessionState;
    private boolean syncing;
    private final List<Runnable> syncCompletions = new ArrayList<>();
    private boolean loadError;

    EncounterStore(Context context) {
        this(context, MeQrRemoteService::fetchEncounterSession);
    }

    EncounterStore(Context context, SessionFetcher sessionFetcher) {
        this(context, sessionFetcher, MeQrRemoteService::confirmEncounterSession);
    }

    EncounterStore(Context context, SessionFetcher sessionFetcher, ConfirmationSender confirmationSender) {
        this.context = context.getApplicationContext();
        this.sessionFetcher = sessionFetcher;
        this.confirmationSender = confirmationSender;
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

    boolean add(MeQrExchangeProfile profile, MeQrEvent event) {
        return add(profile, event, null);
    }

    synchronized boolean add(MeQrExchangeProfile profile, MeQrEvent event, String sessionID) {
        if (sessionID != null && !sessionID.isEmpty()) {
            for (EncounterRecord record : records) {
                if (sessionID.equals(record.sessionID)) {
                    record.upgradeFrom(profile, event);
                    return save();
                }
            }
        }
        records.add(0, EncounterRecord.fromExchangeProfile(profile, event, sessionID));
        return save();
    }

    synchronized void saveScannedProfile(MeQrExchangeProfile profile, MeQrEvent event, String sessionID, JSONObject reply) throws java.io.IOException {
        EncounterRecord existing = null;
        if (sessionID != null) for (EncounterRecord record : records) {
            if (sessionID.equals(record.sessionID)) { existing = record; break; }
        }
        EncounterRecord record = existing == null ? EncounterRecord.fromExchangeProfile(profile, event, sessionID) : existing;
        if (existing != null) record.upgradeFrom(profile, event);
        JSONObject previousReply = record.pendingConfirmationProfile;
        if (sessionID != null && record.confirmationSentAt == 0 && previousReply == null) record.pendingConfirmationProfile = reply;
        if (existing == null) records.add(0, record);
        if (!save()) {
            if (existing == null) records.remove(record);
            else record.pendingConfirmationProfile = previousReply;
            throw new java.io.IOException("Could not save encounter.");
        }
    }

    private void syncConfirmations() {
        for (EncounterRecord record : new ArrayList<>(records)) {
            JSONObject reply;
            synchronized (this) {
                if (!records.contains(record) || record.sessionID == null || record.pendingConfirmationProfile == null) continue;
                reply = record.pendingConfirmationProfile;
            }
            try {
                confirmationSender.send(record.sessionID, reply);
                synchronized (this) {
                    if (!records.contains(record) || record.pendingConfirmationProfile != reply) continue;
                    record.pendingConfirmationProfile = null;
                    record.confirmationSentAt = System.currentTimeMillis();
                    if (!save()) {
                        record.pendingConfirmationProfile = reply;
                        record.confirmationSentAt = 0;
                    }
                }
            } catch (Exception ignored) {
            }
        }
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
        if (loadError) {
            if (completion != null) completion.run();
            return;
        }
        if (syncing) {
            if (completion != null) syncCompletions.add(completion);
            return;
        }
        final List<String> pending = new ArrayList<>(pendingSessionIds);
        if (pending.isEmpty() && records.stream().noneMatch(record -> record.pendingConfirmationProfile != null)) {
            if (completion != null) completion.run();
            return;
        }
        syncing = true;
        if (completion != null) syncCompletions.add(completion);
        new Thread(() -> {
            syncConfirmations();
            syncScannedRecordProfiles();
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
                        if (!save()) throw new java.io.IOException("Could not save received encounters.");
                        sessionState.edit().putStringSet("received:" + sessionId, received).apply();
                    } else if ("confirmed".equalsIgnoreCase(session.status) && session.peerProfile != null) {
                        add(session.peerProfile, sessionEvent, sessionId);
                        for (EncounterRecord record : records) {
                            if (sessionId.equals(record.sessionID)) {
                                record.eventId = session.eventId;
                                record.isOwnSession = true;
                            }
                        }
                        if (!save()) throw new java.io.IOException("Could not save received encounters.");
                        completed.add(sessionId);
                    }
                } catch (Exception ignored) {}
            }
            List<Runnable> completions;
            synchronized (this) {
                pendingSessionIds.removeAll(completed);
                for (String sessionId : completed) {
                    sessionState.edit().remove("owner:" + sessionId).remove("received:" + sessionId).apply();
                }
                syncing = false;
                savePending();
                completions = new ArrayList<>(syncCompletions);
                syncCompletions.clear();
            }
            for (Runnable callback : completions) callback.run();
        }).start();
    }

    private void syncScannedRecordProfiles() {
        java.util.Set<String> sessionIds = new java.util.HashSet<>();
        for (EncounterRecord record : records) {
            if (record.sessionID != null && !record.sessionID.isEmpty()) sessionIds.add(record.sessionID);
        }
        for (String sessionId : sessionIds) {
            // Composite ids ("sessionId:confirmationId") are not fetchable sessions;
            // skip them instead of issuing a request that always fails.
            if (sessionId.indexOf(':') >= 0) continue;
            try {
                MeQrRemoteService.EncounterSession session = sessionFetcher.fetch(
                        "https://api.meqrcode.cn/encounter-sessions/" + sessionId, null);
                if (session.creatorProfile == null) continue;
                synchronized (this) {
                    for (EncounterRecord record : records) {
                        if (sessionId.equals(record.sessionID) && !record.isOwnSession) record.upgradeFrom(session.creatorProfile, null);
                    }
                    save();
                }
            } catch (Exception ignored) {
            }
        }
    }

    synchronized boolean update(EncounterRecord record) {
        for (int i = 0; i < records.size(); i++) {
            if (records.get(i).id.equals(record.id)) {
                record.pendingConfirmationProfile = records.get(i).pendingConfirmationProfile;
                record.confirmationSentAt = records.get(i).confirmationSentAt;
                records.set(i, record);
                break;
            }
        }
        records.sort(Comparator.comparingLong(recordItem -> -recordItem.metAt));
        return save();
    }

    synchronized boolean delete(EncounterRecord record) {
        records.removeIf(item -> item.id.equals(record.id));
        return save();
    }

    private void load() {
        records.clear();
        loadError = false;
        if (dataFile.exists()) try {
            String json = new String(new android.util.AtomicFile(dataFile).readFully(), StandardCharsets.UTF_8);
            JSONArray array = new JSONArray(json);
            for (int i = 0; i < array.length(); i++) {
                records.add(EncounterRecord.fromJson(array.getJSONObject(i)));
            }
        } catch (Exception ignored) {
            loadError = true;
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
            }
        }
    }

    private synchronized boolean save() {
        if (loadError) {
            return false;
        }
        JSONArray array = new JSONArray();
        try {
            for (EncounterRecord record : records) {
                array.put(record.toJson());
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
            return true;
        } catch (Exception ignored) {
            return false;
        }
    }

    private synchronized void savePending() {
        JSONArray array = new JSONArray();
        for (String sessionId : pendingSessionIds) {
            array.put(sessionId);
        }
        android.util.AtomicFile atomic = new android.util.AtomicFile(pendingFile);
        FileOutputStream output = null;
        try {
            output = atomic.startWrite();
            output.write(array.toString(2).getBytes(StandardCharsets.UTF_8));
            atomic.finishWrite(output);
        } catch (Exception ignored) {
            if (output != null) atomic.failWrite(output);
        }
    }
}
