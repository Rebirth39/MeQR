package com.lucasli.meqr;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.AtomicFile;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

final class TagReportOutbox {
    private static TagReportOutbox instance;
    private final AtomicFile file;
    private JSONArray jobs = new JSONArray();
    private final ScheduledExecutorService worker = Executors.newSingleThreadScheduledExecutor();
    private final Handler main = new Handler(Looper.getMainLooper());
    private final List<Runnable> listeners = new ArrayList<>();
    private final TagReport.Submitter sender;
    private boolean draining;

    static synchronized TagReportOutbox get(Context context) {
        if (instance == null) instance = new TagReportOutbox(new File(context.getFilesDir(), "tag-report-outbox.json"), TagReport::submit);
        return instance;
    }

    TagReportOutbox(File path, TagReport.Submitter sender) {
        file = new AtomicFile(path); this.sender = sender;
        try {
            jobs = new JSONArray(new String(file.readFully(), StandardCharsets.UTF_8));
            for (int i = 0; i < jobs.length(); i++) {
                JSONObject job = jobs.getJSONObject(i);
                if (job.optString("status").equals("sending")) job.put("status", "pending");
            }
        } catch (java.io.FileNotFoundException absent) {
            // The queue is created on the first submission.
        } catch (Exception invalid) { throw new IllegalStateException("Cannot read report outbox", invalid); }
    }

    private synchronized void save(JSONArray updated) throws Exception {
        FileOutputStream output = null;
        try {
            output = file.startWrite();
            output.write(updated.toString().getBytes(StandardCharsets.UTF_8));
            file.finishWrite(output);
        } catch (Exception error) { if (output != null) file.failWrite(output); throw error; }
        jobs = updated;
        for (Runnable listener : listeners) main.post(listener);
    }

    synchronized JSONArray snapshot() throws Exception { return new JSONArray(jobs.toString()); }

    synchronized String enqueue(JSONObject payload) throws Exception {
        String id = payload.getString("request_id");
        java.util.UUID.fromString(id);
        for (int i = 0; i < jobs.length(); i++) {
            JSONObject old = jobs.getJSONObject(i);
            if (old.getString("id").equals(id)) {
                JSONObject previous = old.getJSONObject("payload");
                if (previous.length() != payload.length()) throw new IllegalArgumentException("Request ID conflict");
                java.util.Iterator<String> keys = previous.keys();
                while (keys.hasNext()) { String key = keys.next(); if (!previous.getString(key).equals(payload.optString(key, null))) throw new IllegalArgumentException("Request ID conflict"); }
                return id;
            }
        }
        JSONArray updated = snapshot();
        updated.put(new JSONObject().put("id", id).put("payload", new JSONObject(payload.toString()))
                .put("status", "pending").put("attempts", 0).put("next", 0).put("created", System.currentTimeMillis()));
        save(updated);
        return id;
    }

    synchronized void cancel(String id) throws Exception {
        JSONArray updated = new JSONArray();
        for (int i = 0; i < jobs.length(); i++) {
            JSONObject job = jobs.getJSONObject(i);
            if (!job.getString("id").equals(id) || job.optString("status").equals("sending")) updated.put(job);
        }
        save(updated);
    }

    synchronized void retry(String id) throws Exception {
        JSONArray updated = snapshot();
        for (int i = 0; i < updated.length(); i++) {
            JSONObject job = updated.getJSONObject(i);
            if (job.getString("id").equals(id) && !job.optString("status").equals("sending") && !job.has("ticket"))
                job.put("status", "pending").put("next", 0);
        }
        save(updated); kick();
    }

    void kick() { worker.execute(this::drain); }

    private void drain() {
        synchronized (this) { if (draining) return; draining = true; }
        try {
            while (true) {
                JSONObject active = null;
                synchronized (this) {
                    JSONArray updated = snapshot();
                    long next = Long.MAX_VALUE;
                    for (int i = 0; i < updated.length(); i++) {
                        JSONObject job = updated.getJSONObject(i);
                        if (!job.optString("status").equals("pending")) continue;
                        if (job.optLong("next") > System.currentTimeMillis()) { next = Math.min(next, job.optLong("next")); continue; }
                        active = job;
                        job.put("status", "sending").put("attempts", job.optInt("attempts") + 1);
                        save(updated); break;
                    }
                    if (active == null) {
                        if (next != Long.MAX_VALUE) worker.schedule(this::drain, Math.max(1000, next - System.currentTimeMillis()), TimeUnit.MILLISECONDS);
                        return;
                    }
                }
                String ticket = null; Exception failure = null;
                try {
                    ticket = sender.submit(active.getJSONObject("payload"));
                    if (ticket == null || !ticket.matches("MEQR-[0-9]{8}-[A-F0-9]{6}")) throw new IllegalStateException("Invalid receipt");
                } catch (Exception error) { failure = error; ticket = null; }
                synchronized (this) {
                    JSONArray updated = snapshot();
                    for (int i = 0; i < updated.length(); i++) {
                        JSONObject job = updated.getJSONObject(i);
                        if (!job.getString("id").equals(active.getString("id"))) continue;
                        if (ticket != null) job.put("status", "sent").put("ticket", ticket);
                        else {
                            long seconds = failure instanceof TagReport.RateLimited ? 600 : Math.min(3600, 30L << Math.min(7, job.optInt("attempts")));
                            job.put("status", failure instanceof TagReport.Rejected ? "failed" : "pending")
                                    .put("next", System.currentTimeMillis() + seconds * 1000);
                        }
                    }
                    if (failure instanceof TagReport.RateLimited) {
                        for (int i = 0; i < updated.length(); i++) {
                            JSONObject job = updated.getJSONObject(i);
                            if (job.optString("status").equals("pending")) job.put("next", Math.max(job.optLong("next"), System.currentTimeMillis() + 600000));
                        }
                    }
                    save(updated);
                }
            }
        } catch (Exception storageFailure) {
            synchronized (this) {
                for (int i = 0; i < jobs.length(); i++) {
                    JSONObject job = jobs.optJSONObject(i);
                    if (job != null && job.optString("status").equals("sending")) {
                        try { job.put("status", "pending").put("next", System.currentTimeMillis() + 60000); } catch (Exception ignored) { }
                    }
                }
            }
            worker.schedule(this::drain, 60, TimeUnit.SECONDS);
        } finally { synchronized (this) { draining = false; } }
    }

    void close() { worker.shutdownNow(); }

    static void show(Activity activity, I18n i18n) {
        final TagReportOutbox outbox;
        try { outbox = get(activity); } catch (Exception error) { Toast.makeText(activity, i18n.t("tagQueueSaveFailed"), Toast.LENGTH_LONG).show(); return; }
        LinearLayout rows = new LinearLayout(activity); rows.setOrientation(LinearLayout.VERTICAL);
        int padding = Math.round(16 * activity.getResources().getDisplayMetrics().density);
        rows.setPadding(padding, padding, padding, padding);
        ScrollView scroll = new ScrollView(activity); scroll.addView(rows);
        AlertDialog dialog = new AlertDialog.Builder(activity).setTitle(i18n.t("tagOutbox"))
                .setView(scroll).setPositiveButton(i18n.t("done"), null).create();
        Runnable refresh = () -> {
            if (activity.isDestroyed()) return;
            rows.removeAllViews();
            try {
                JSONArray jobs = outbox.snapshot();
                if (jobs.length() == 0) { TextView empty = new TextView(activity); empty.setText(i18n.t("tagQueueEmpty")); rows.addView(empty); }
                for (int i = jobs.length() - 1; i >= 0; i--) {
                    JSONObject job = jobs.getJSONObject(i);
                    String id = job.getString("id"), state = job.optString("status");
                    TextView label = new TextView(activity);
                    label.setText(job.getJSONObject("payload").optString("tag_name") + "\n" +
                            (job.has("ticket") ? job.getString("ticket") : i18n.t(state.equals("sending") ? "tagSending" : state.equals("failed") ? "tagReportFailed" : "tagQueued")));
                    label.setTextIsSelectable(true); rows.addView(label);
                    LinearLayout actions = new LinearLayout(activity);
                    if (!job.has("ticket")) {
                        Button retry = new Button(activity); retry.setText(i18n.t("tagRetry")); retry.setEnabled(!state.equals("sending"));
                        retry.setOnClickListener(v -> { try { outbox.retry(id); } catch (Exception error) { Toast.makeText(activity, i18n.t("tagQueueSaveFailed"), Toast.LENGTH_LONG).show(); } });
                        actions.addView(retry);
                    }
                    Button cancel = new Button(activity); cancel.setText(i18n.t(job.has("ticket") ? "delete" : "tagCancelPending")); cancel.setEnabled(!state.equals("sending"));
                    cancel.setOnClickListener(v -> { try { outbox.cancel(id); } catch (Exception error) { Toast.makeText(activity, i18n.t("tagQueueSaveFailed"), Toast.LENGTH_LONG).show(); } });
                    actions.addView(cancel); rows.addView(actions);
                }
            } catch (Exception error) { Toast.makeText(activity, i18n.t("tagQueueSaveFailed"), Toast.LENGTH_LONG).show(); }
        };
        synchronized (outbox) { outbox.listeners.add(refresh); }
        dialog.setOnDismissListener(d -> { synchronized (outbox) { outbox.listeners.remove(refresh); } });
        dialog.show(); refresh.run(); outbox.kick();
    }
}
