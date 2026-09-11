package com.lucasli.meqr;

import android.app.Activity;
import android.app.AlertDialog;
import android.text.InputFilter;
import android.text.InputType;
import android.view.View;
import android.widget.ArrayAdapter;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.Spinner;
import android.widget.TextView;
import org.json.JSONObject;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.UUID;

final class TagReport {
    private static final String ENDPOINT = "https://report.meqrcode.cn/api/tag-reports";
    private static final String[] REASONS = {"name", "color", "duplicate", "other"};
    interface Submitter { String submit(JSONObject payload) throws Exception; }

    static void show(Activity activity, I18n i18n, String tag) {
        showForm(activity, i18n, tag, false, null);
    }

    static void show(Activity activity, I18n i18n, String tag, Submitter submitter) {
        showForm(activity, i18n, tag, false, submitter);
    }

    static void showNew(Activity activity, I18n i18n, String query) {
        showForm(activity, i18n, query, true, null);
    }

    static String submit(JSONObject payload) throws Exception {
        String token = request(ENDPOINT + "/token", null, null).getString("token");
        return request(ENDPOINT, token, payload).getString("ticket_id");
    }

    private static EditText field(Activity activity, LinearLayout content, I18n i18n, String key, int limit) {
        EditText field = new EditText(activity); field.setHint(i18n.t(key)); field.setSingleLine(true);
        field.setFilters(new InputFilter[]{new InputFilter.LengthFilter(limit)}); content.addView(field); return field;
    }

    private static void showForm(Activity activity, I18n i18n, String tag, boolean isNew, Submitter submitter) {
        int padding = Math.round(20 * activity.getResources().getDisplayMetrics().density);
        LinearLayout content = new LinearLayout(activity);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setPadding(padding, padding / 2, padding, padding / 2);
        TextView name = new TextView(activity);
        name.setText(tag);
        content.addView(name);
        Spinner reason = new Spinner(activity);
        ArrayAdapter<String> choices = new ArrayAdapter<>(activity, android.R.layout.simple_spinner_item,
                new String[]{i18n.t("tagReportName"), i18n.t("tagReportColor"), i18n.t("tagReportDuplicate"), i18n.t("tagReportOther")});
        choices.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        reason.setAdapter(choices);
        content.addView(reason);
        EditText requestedName = field(activity, content, i18n, "tagRequestName", 160);
        requestedName.setText(tag);
        EditText work = field(activity, content, i18n, "tagRequestIP", 160);
        EditText colors = field(activity, content, i18n, "tagRequestColors", 240);
        EditText reference = field(activity, content, i18n, "tagRequestSource", 1000);
        reference.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_URI);
        for (View view : new View[]{requestedName, work, colors, reference}) view.setVisibility(isNew ? View.VISIBLE : View.GONE);
        name.setVisibility(isNew ? View.GONE : View.VISIBLE);
        reason.setVisibility(isNew ? View.GONE : View.VISIBLE);
        EditText details = new EditText(activity);
        details.setHint(i18n.t("tagReportDescription"));
        details.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES);
        details.setMinLines(3);
        details.setFilters(new InputFilter[]{new InputFilter.LengthFilter(3000)});
        content.addView(details);
        EditText contact = new EditText(activity);
        contact.setHint(i18n.t("tagReportContact"));
        contact.setSingleLine(true);
        contact.setFilters(new InputFilter[]{new InputFilter.LengthFilter(120)});
        content.addView(contact);
        TextView error = new TextView(activity);
        error.setTextColor(0xFFB3261E);
        content.addView(error);
        ProgressBar progress = new ProgressBar(activity);
        progress.setVisibility(View.GONE);
        content.addView(progress);
        ScrollView scroll = new ScrollView(activity);
        scroll.addView(content);
        AlertDialog dialog = new AlertDialog.Builder(activity).setTitle(i18n.t(isNew ? "tagRequestNew" : "tagReport"))
                .setView(scroll).setNegativeButton(i18n.t("cancel"), null)
                .setPositiveButton(i18n.t("tagReportSubmit"), null).create();
        dialog.setCanceledOnTouchOutside(false);
        MainActivity.handleDialogBack(dialog, () -> {
            android.widget.Button cancel = dialog.getButton(AlertDialog.BUTTON_NEGATIVE);
            if (cancel != null && cancel.isEnabled()) cancel.performClick();
        });
        String[] lastBody = {""}, requestID = {UUID.randomUUID().toString()};
        dialog.setOnShowListener(ignored -> {
            dialog.getButton(AlertDialog.BUTTON_NEGATIVE).setOnClickListener(v -> {
                if (details.length() == 0 && contact.length() == 0 && work.length() == 0 && colors.length() == 0 && reference.length() == 0 && requestedName.getText().toString().equals(tag) && reason.getSelectedItemPosition() == 0) { dialog.dismiss(); return; }
                new AlertDialog.Builder(activity).setMessage(i18n.t("tagReportDiscard"))
                        .setNegativeButton(i18n.t("cancel"), null)
                        .setPositiveButton(i18n.t("delete"), (d, which) -> dialog.dismiss()).show();
            });
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(v -> {
                if (isNew && requestedName.getText().toString().trim().isEmpty()) { requestedName.setError(i18n.t("tagRequestName")); return; }
                if (isNew && work.getText().toString().trim().isEmpty()) { work.setError(i18n.t("tagRequestIP")); return; }
                if (isNew && reference.length() > 0) {
                    android.net.Uri uri = android.net.Uri.parse(reference.getText().toString().trim());
                    if (!("https".equals(uri.getScheme()) || "http".equals(uri.getScheme())) || uri.getHost() == null || uri.getUserInfo() != null) {
                        reference.setError(i18n.t("tagRequestSource")); return;
                    }
                }
                if (details.getText().toString().trim().isEmpty()) {
                    details.setError(i18n.t("tagReportDescription"));
                    return;
                }
                JSONObject payload = new JSONObject();
                try {
                    String tagID = "";
                    String key = RemoteTagCatalog.canonicalKey(tag);
                    for (RemoteTagCatalog.Entry entry : RemoteTagCatalog.entries()) {
                        if (entry.canonicalKey.equals(key)) { tagID = entry.id; break; }
                    }
                    payload.put("tag_name", tag).put("tag_id", tagID).put("reason", REASONS[reason.getSelectedItemPosition()])
                            .put("description", details.getText().toString()).put("contact", contact.getText().toString())
                            .put("platform", "android").put("revision", RemoteTagCatalog.revision())
                            .put("source", RemoteTagCatalog.sourceName(i18n))
                            .put("app_version", activity.getPackageManager().getPackageInfo(activity.getPackageName(), 0).versionName);
                    if (isNew) payload.put("tag_name", requestedName.getText().toString()).put("tag_id", "").put("reason", "request")
                            .put("work", work.getText().toString()).put("suggested_colors", colors.getText().toString()).put("reference_url", reference.getText().toString());
                    String body = payload.toString();
                    if (!body.equals(lastBody[0])) { requestID[0] = UUID.randomUUID().toString(); lastBody[0] = body; }
                    payload.put("request_id", requestID[0]);
                } catch (Exception failure) { error.setText(i18n.t("tagReportFailed")); return; }
                if (submitter == null) {
                    try {
                        TagReportOutbox outbox = TagReportOutbox.get(activity);
                        outbox.enqueue(payload); outbox.kick(); dialog.dismiss();
                        new AlertDialog.Builder(activity).setMessage(i18n.t("tagQueueSaved"))
                                .setPositiveButton(i18n.t("done"), null)
                                .setNeutralButton(i18n.t("tagOutbox"), (d, which) -> TagReportOutbox.show(activity, i18n)).show();
                    } catch (Exception failure) { error.setText(i18n.t("tagQueueSaveFailed")); }
                    return;
                }
                setBusy(dialog, progress, details, contact, reason, true);
                error.setText("");
                new Thread(() -> {
                    String ticket = null, failure = null;
                    try {
                        ticket = submitter.submit(payload);
                        if (!ticket.matches("MEQR-[0-9]{8}-[A-F0-9]{6}")) throw new IllegalStateException();
                    } catch (Exception exception) {
                        failure = i18n.t(exception instanceof RateLimited ? "tagReportLimited" : "tagReportFailed");
                    }
                    String receipt = ticket, message = failure;
                    activity.runOnUiThread(() -> {
                        if (activity.isFinishing() || activity.isDestroyed() || !dialog.isShowing()) return;
                        setBusy(dialog, progress, details, contact, reason, false);
                        if (message != null) { error.setText(message); return; }
                        dialog.dismiss();
                        TextView result = new TextView(activity);
                        result.setText(receipt);
                        result.setTextIsSelectable(true);
                        result.setPadding(padding, padding, padding, padding);
                        new AlertDialog.Builder(activity).setTitle(i18n.t("tagReportSent"))
                                .setView(result).setPositiveButton(i18n.t("done"), null).show();
                    });
                }, "tag-report").start();
            });
        });
        dialog.show();
    }

    private static void setBusy(AlertDialog dialog, ProgressBar progress, EditText details, EditText contact, Spinner reason, boolean busy) {
        dialog.getButton(AlertDialog.BUTTON_POSITIVE).setEnabled(!busy);
        dialog.getButton(AlertDialog.BUTTON_NEGATIVE).setEnabled(!busy);
        details.setEnabled(!busy);
        contact.setEnabled(!busy);
        reason.setEnabled(!busy);
        progress.setVisibility(busy ? View.VISIBLE : View.GONE);
    }

    static final class RateLimited extends Exception {}
    static final class Rejected extends Exception {}

    private static JSONObject request(String url, String token, JSONObject payload) throws Exception {
        HttpURLConnection connection = (HttpURLConnection) new URL(url).openConnection();
        connection.setConnectTimeout(15000);
        connection.setReadTimeout(20000);
        connection.setInstanceFollowRedirects(false);
        try {
            if (payload != null) {
                connection.setRequestMethod("POST");
                connection.setDoOutput(true);
                connection.setRequestProperty("Content-Type", "application/json");
                connection.setRequestProperty("Authorization", "Bearer " + token);
                byte[] body = payload.toString().getBytes(StandardCharsets.UTF_8);
                connection.setFixedLengthStreamingMode(body.length);
                try (java.io.OutputStream output = connection.getOutputStream()) { output.write(body); }
            }
            int status = connection.getResponseCode();
            if (status == 429) throw new RateLimited();
            if (status == 400 || status == 409 || status == 413 || status == 415) throw new Rejected();
            if (status < 200 || status > 299) throw new IllegalStateException("HTTP " + status);
            try (InputStream input = connection.getInputStream(); ByteArrayOutputStream output = new ByteArrayOutputStream()) {
                byte[] buffer = new byte[1024];
                int count;
                while ((count = input.read(buffer)) != -1) {
                    if (output.size() + count > 16384) throw new IllegalStateException("Response too large");
                    output.write(buffer, 0, count);
                }
                return new JSONObject(output.toString("UTF-8"));
            }
        } finally { connection.disconnect(); }
    }
}
