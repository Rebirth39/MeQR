package com.lucasli.meqr;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

final class EncounterRecord {
    String id = UUID.randomUUID().toString();
    String name = "";
    String subtitle = "";
    String avatarBase64 = "";
    String backgroundBase64 = "";
    final List<MeQrExchangeProfile.Platform> profiles = new ArrayList<>();
    long metAt = System.currentTimeMillis();
    long sourceSharedAt;
    String note = "";
    final List<String> tags = new ArrayList<>();
    String eventId;
    String eventTitle;
    String eventVenue;
    boolean needsPhotoReturn;
    boolean exchangedFreebie;
    String followStatus;

    EncounterRecord() {
    }

    static EncounterRecord fromExchangeProfile(MeQrExchangeProfile profile, MeQrEvent event) {
        EncounterRecord record = new EncounterRecord();
        record.name = profile.name;
        record.subtitle = profile.subtitle;
        record.avatarBase64 = profile.avatarBase64;
        record.backgroundBase64 = profile.backgroundBase64;
        for (MeQrExchangeProfile.Platform platform : profile.platforms) {
            record.profiles.add(platform);
        }
        record.metAt = System.currentTimeMillis();
        record.sourceSharedAt = profile.sharedAt * 1000L;
        if (event != null) {
            record.eventId = event.id;
            record.eventTitle = event.title;
            record.eventVenue = event.venue;
        }
        return record;
    }

    JSONObject toJson() throws JSONException {
        JSONObject object = new JSONObject();
        object.put("id", id);
        object.put("name", name);
        object.put("subtitle", subtitle);
        object.put("avatarBase64", avatarBase64);
        object.put("backgroundBase64", backgroundBase64);
        JSONArray profileArray = new JSONArray();
        for (MeQrExchangeProfile.Platform platform : profiles) {
            JSONObject platformJson = new JSONObject();
            platformJson.put("t", platform.type);
            platformJson.put("n", platform.name);
            platformJson.put("q", platform.qrContent);
            profileArray.put(platformJson);
        }
        object.put("p", profileArray);
        object.put("metAt", metAt);
        object.put("sourceSharedAt", sourceSharedAt);
        object.put("note", note);
        JSONArray tagArray = new JSONArray();
        for (String tag : tags) {
            tagArray.put(tag);
        }
        object.put("tags", tagArray);
        object.put("eventId", eventId == null ? JSONObject.NULL : eventId);
        object.put("eventTitle", eventTitle == null ? JSONObject.NULL : eventTitle);
        object.put("eventVenue", eventVenue == null ? JSONObject.NULL : eventVenue);
        object.put("needsPhotoReturn", needsPhotoReturn);
        object.put("exchangedFreebie", exchangedFreebie);
        object.put("followStatus", followStatus == null ? JSONObject.NULL : followStatus);
        return object;
    }

    static EncounterRecord fromJson(JSONObject object) {
        EncounterRecord record = new EncounterRecord();
        record.id = object.optString("id", record.id);
        record.name = object.optString("name", "");
        record.subtitle = object.optString("subtitle", "");
        record.avatarBase64 = object.optString("avatarBase64", "");
        record.backgroundBase64 = object.optString("backgroundBase64", "");
        JSONArray profileArray = object.optJSONArray("p");
        if (profileArray != null) {
            for (int i = 0; i < profileArray.length(); i++) {
                JSONObject platformJson = profileArray.optJSONObject(i);
                if (platformJson == null) {
                    continue;
                }
                MeQrExchangeProfile.Platform platform = new MeQrExchangeProfile.Platform();
                platform.type = platformJson.optString("t", "custom");
                platform.name = platformJson.optString("n", "");
                platform.qrContent = platformJson.optString("q", "");
                record.profiles.add(platform);
            }
        }
        record.metAt = object.optLong("metAt", System.currentTimeMillis());
        record.sourceSharedAt = object.optLong("sourceSharedAt", 0);
        record.note = object.optString("note", "");
        JSONArray tagArray = object.optJSONArray("tags");
        if (tagArray != null) {
            for (int i = 0; i < tagArray.length() && record.tags.size() < 10; i++) {
                String tag = tagArray.optString(i, "");
                if (!tag.isEmpty() && !record.tags.contains(tag)) {
                    record.tags.add(tag);
                }
            }
        }
        record.eventId = object.isNull("eventId") ? null : object.optString("eventId", null);
        record.eventTitle = object.isNull("eventTitle") ? null : object.optString("eventTitle", null);
        record.eventVenue = object.isNull("eventVenue") ? null : object.optString("eventVenue", null);
        record.needsPhotoReturn = object.optBoolean("needsPhotoReturn", false);
        record.exchangedFreebie = object.optBoolean("exchangedFreebie", false);
        record.followStatus = object.isNull("followStatus") ? null : object.optString("followStatus", null);
        return record;
    }
}
