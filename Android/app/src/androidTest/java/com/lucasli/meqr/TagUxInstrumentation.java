package com.lucasli.meqr;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Bundle;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

public final class TagUxInstrumentation extends Instrumentation {
    @Override public void onCreate(Bundle arguments) { super.onCreate(arguments); start(); }

    @Override public void onStart() {
        Bundle result = new Bundle();
        SharedPreferences preferences = getTargetContext().getSharedPreferences("tag_usage_tests", Context.MODE_PRIVATE);
        preferences.edit().clear().commit();
        try {
            CountDownLatch loaded = new CountDownLatch(1);
            RemoteTagCatalog.refresh(getTargetContext(), true, loaded::countDown);
            check(loaded.await(15, TimeUnit.SECONDS), "Catalog load timed out");
            check(RemoteTagCatalog.errorMessage() == null, "Catalog failed");
            check(!RemoteTagCatalog.changelog().isEmpty(), "Changelog missing");
            check(RemoteTagCatalog.revision().equals(RemoteTagCatalog.changelog().get(0).revision), "Changelog revision mismatch");
            String originalRevision = RemoteTagCatalog.revision();
            int originalCount = RemoteTagCatalog.entries().size();
            byte[] original;
            try (java.io.InputStream input = getTargetContext().getAssets().open("tags-v1.json");
                 java.io.ByteArrayOutputStream output = new java.io.ByteArrayOutputStream()) {
                byte[] buffer = new byte[8192];
                int count;
                while ((count = input.read(buffer)) != -1) output.write(buffer, 0, count);
                original = output.toByteArray();
            }
            byte[] maintenance = "{\"schemaVersion\":1,\"revision\":\"maintenance-2026.09.06\",\"entries\":[]}".getBytes(java.nio.charset.StandardCharsets.UTF_8);
            check(!RemoteTagCatalog.install(maintenance, RemoteTagCatalog.Source.ONLINE), "Maintenance library accepted");
            check(RemoteTagCatalog.revision().equals(originalRevision) && RemoteTagCatalog.entries().size() == originalCount, "Maintenance replaced valid data");
            org.json.JSONObject online = new org.json.JSONObject(new String(original, java.nio.charset.StandardCharsets.UTF_8));
            online.put("revision", "test-online");
            online.remove("changelog");
            check(RemoteTagCatalog.install(online.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8), RemoteTagCatalog.Source.ONLINE), "Online library rejected");
            I18n i18n = new I18n(getTargetContext());
            check(RemoteTagCatalog.sourceName(i18n).equals(i18n.t("tagCatalogRemote")), "Online source incorrect");
            check(RemoteTagCatalog.changelog().isEmpty(), "Old changelog leaked into new revision");
            RemoteTagCatalog.install(original, RemoteTagCatalog.Source.CACHED);
            check(RemoteTagCatalog.sourceName(i18n).equals(i18n.t("tagCatalogCache")), "Cache source incorrect");
            try {
                RemoteTagCatalog.install("{}".getBytes(java.nio.charset.StandardCharsets.UTF_8), RemoteTagCatalog.Source.ONLINE);
                throw new AssertionError("Invalid schema accepted");
            } catch (IllegalStateException expected) {
                check(RemoteTagCatalog.revision().equals(originalRevision), "Invalid data replaced cache");
            }
            RemoteTagCatalog.install(original, RemoteTagCatalog.Source.BUNDLED);
            RemoteTagCatalog.Entry entry = RemoteTagCatalog.entries().get(0);
            CardTagUsageStore store = new CardTagUsageStore(preferences);
            store.record(entry.display(I18n.EN));
            store.record(entry.display(I18n.JA));
            Thread.sleep(5);
            store.record("Custom test tag");
            check(store.records(false).size() == 2, "Language aliases duplicated history");
            check(store.records(true).get(0).count == 2, "Frequency order failed");
            check(store.records(false).get(0).name.equals("Custom test tag"), "Recency order failed");
            store = new CardTagUsageStore(preferences);
            check(store.records(true).get(0).count == 2, "History did not persist");
            store.record("   ");
            check(store.records(false).size() == 2, "Empty tag recorded");
            for (int i = 0; i < 110; i++) store.record("Custom " + i);
            check(store.records(false).size() == 100, "Unbounded history");
            store.clear();
            check(new CardTagUsageStore(preferences).records(false).isEmpty(), "Clear did not persist");
            preferences.edit().putString("records", "bad JSON").commit();
            check(store.records(false).isEmpty(), "Corrupt history not recovered");
            result.putString("stream", "Tag UX: 19 checks passed\n");
            finish(Activity.RESULT_OK, result);
        } catch (Throwable failure) {
            result.putString("stream", "FAIL: " + failure + "\n");
            finish(Activity.RESULT_CANCELED, result);
        } finally {
            preferences.edit().clear().commit();
        }
    }

    private static void check(boolean value, String message) {
        if (!value) throw new AssertionError(message);
    }
}
