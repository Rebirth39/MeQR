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
    private final File dataFile;
    private final List<EncounterRecord> records = new ArrayList<>();

    EncounterStore(Context context) {
        this.dataFile = new File(context.getApplicationContext().getFilesDir(), "encounters.json");
        load();
    }

    List<EncounterRecord> records() {
        return records;
    }

    void add(MeQrExchangeProfile profile, MeQrEvent event) {
        records.add(0, EncounterRecord.fromExchangeProfile(profile, event));
        save();
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
        if (!dataFile.exists()) {
            return;
        }
        try {
            String json = new String(Files.readAllBytes(dataFile.toPath()), StandardCharsets.UTF_8);
            JSONArray array = new JSONArray(json);
            for (int i = 0; i < array.length(); i++) {
                records.add(EncounterRecord.fromJson(array.getJSONObject(i)));
            }
        } catch (Exception ignored) {
            records.clear();
        }
        records.sort(Comparator.comparingLong(record -> -record.metAt));
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
}
