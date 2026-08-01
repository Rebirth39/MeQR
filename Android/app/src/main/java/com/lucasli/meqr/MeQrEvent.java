package com.lucasli.meqr;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.UUID;

final class MeQrEvent {
    static final String DEFAULT_EVENT_ID = "26F92A33-1F9E-45A4-83F8-59B9170D0726";

    String id = UUID.randomUUID().toString();
    String title = "";
    String venue = "";
    String address = "";
    String details = "";
    long startDate = System.currentTimeMillis();
    long endDate;
    String sourceUrl = "";
    boolean isCustom;

    MeQrEvent() {
    }

    JSONObject toJson() throws JSONException {
        JSONObject object = new JSONObject();
        object.put("id", id);
        object.put("title", title);
        object.put("venue", venue);
        object.put("address", address);
        object.put("details", details);
        object.put("startDate", startDate);
        object.put("endDate", endDate);
        object.put("sourceUrl", sourceUrl);
        object.put("isCustom", isCustom);
        return object;
    }

    static MeQrEvent fromJson(JSONObject object) {
        MeQrEvent event = new MeQrEvent();
        event.id = object.optString("id", event.id);
        event.title = object.optString("title", "");
        event.venue = object.optString("venue", "");
        event.address = object.optString("address", "");
        event.details = object.optString("details", "");
        event.startDate = object.optLong("startDate", System.currentTimeMillis());
        event.endDate = object.optLong("endDate", 0);
        event.sourceUrl = object.optString("sourceUrl", "");
        event.isCustom = object.optBoolean("isCustom", false);
        return event;
    }

    static MeQrEvent defaultEvent() {
        MeQrEvent event = new MeQrEvent();
        event.id = DEFAULT_EVENT_ID;
        event.title = "自定义线下扩列";
        event.venue = "现场";
        event.startDate = System.currentTimeMillis();
        return event;
    }
}
