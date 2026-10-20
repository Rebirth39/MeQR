package com.lucasli.meqr;

import android.app.Activity;
import android.app.Instrumentation;
import android.os.Bundle;
import org.json.JSONObject;
import org.json.JSONArray;

public final class SupportTicketInstrumentation extends Instrumentation {
    @Override public void onCreate(Bundle arguments) { super.onCreate(arguments); start(); }

    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            // Draft fingerprint: stable for identical drafts, changes with any field.
            String fp = SupportTickets.draftFingerprint("hello", "a.png", 69, "image/png");
            check(fp.equals(SupportTickets.draftFingerprint("hello", "a.png", 69, "image/png")), "fingerprint unstable");
            check(!fp.equals(SupportTickets.draftFingerprint("hello!", "a.png", 69, "image/png")), "text change kept fingerprint");
            check(!fp.equals(SupportTickets.draftFingerprint("hello", "b.png", 69, "image/png")), "name change kept fingerprint");
            check(!fp.equals(SupportTickets.draftFingerprint("hello", "a.png", 70, "image/png")), "size change kept fingerprint");
            check(!fp.equals(SupportTickets.draftFingerprint("hello", "", -1, "")), "attachment absence kept fingerprint");
            check(fp.matches("[0-9a-f]{64}"), "fingerprint not sha-256 hex");

            // Alert state: legacy snapshots carried user_messages in a 4th segment.
            check("open|false|note".equals(SupportTickets.normalizeAlertState("open|false|note")), "new format altered");
            check("open|false|note".equals(SupportTickets.normalizeAlertState("open|false|note|[{\"text\":\"hi\"}]")), "legacy user_messages not stripped");
            check("resolved|true|".equals(SupportTickets.normalizeAlertState("resolved|true||null")), "legacy null tail not stripped");
            check(SupportTickets.normalizeAlertState(null) == null, "null state not preserved");
            check("open|false".equals(SupportTickets.normalizeAlertState("open|false")), "two-segment state altered");

            // Attachment rendering accepts both response shapes.
            JSONObject message = new JSONObject().put("attachments", new JSONArray().put(
                    new JSONObject().put("name", "a.png").put("mime_type", "image/png").put("byte_size", 69)));
            check(SupportTickets.attachmentLines(message).get(0).contains("a.png"), "attachments[] name missing");
            check(SupportTickets.attachmentLines(message).get(0).contains("69 B"), "attachments[] size missing");
            JSONObject legacy = new JSONObject().put("attachment",
                    new JSONObject().put("name", "b.mp4").put("mime", "video/mp4").put("size", 5 * 1024 * 1024));
            check(SupportTickets.attachmentLines(legacy).get(0).contains("b.mp4"), "single attachment name missing");
            check(SupportTickets.attachmentLines(legacy).get(0).contains("5.0 MB"), "single attachment size missing");
            check(SupportTickets.attachmentLines(new JSONObject()).isEmpty(), "empty message produced attachment lines");

            check("69 B".equals(SupportTickets.formatSize(69)), "formatSize bytes");
            check("2.0 KB".equals(SupportTickets.formatSize(2048)), "formatSize KB");
            check("50.0 MB".equals(SupportTickets.formatSize(50L * 1024 * 1024)), "formatSize MB");

            result.putString("stream", "Support ticket logic: fingerprint stability, legacy alert-state normalization, dual attachment formats, size formatting passed\n");
            finish(Activity.RESULT_OK, result);
        } catch (Throwable error) {
            result.putString("stream", "FAIL: " + error + "\n");
            finish(Activity.RESULT_CANCELED, result);
        }
    }

    private static void check(boolean value, String message) { if (!value) throw new AssertionError(message); }
}
