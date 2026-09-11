package com.lucasli.meqr;

import android.app.Instrumentation;
import android.os.Bundle;

public final class ExchangeCodeInstrumentation extends Instrumentation {
    @Override public void onCreate(Bundle arguments) { super.onCreate(arguments); start(); }
    @Override public void onStart() {
        Bundle result = new Bundle();
        try {
            check(getTargetContext().getPackageName().endsWith(".exchangetest"), "Isolated package required");
            I18n i18n = new I18n(getTargetContext());
            MeQrProfile profile = new MeQrProfile();
            profile.name = "Cache fixture";
            profile.firstItem().qrContent = "https://example.com/first";
            MeQrExchangeCodeStore store = new MeQrExchangeCodeStore(getTargetContext());
            String fingerprint = MeQrExchangeCodeStore.fingerprint(profile, i18n, null);
            check(fingerprint.equals(MeQrExchangeCodeStore.fingerprint(profile, i18n, null)), "Stable fingerprint");
            MeQrExchangeCodeStore.Record record = MeQrExchangeCodeStore.create(profile, i18n, fingerprint, null);
            check(!record.payload.contains(record.ownerToken), "Owner secret never in QR");
            check(MeQrExchangeCodec.offlineFallback(record.payload).id.equals(profile.id), "Offline identity preserved");
            check(QrCodeGenerator.generateColorLayered(record.payload, record.avatar, 960) != null, "QR renders");
            store.save(profile.id, record);
            MeQrExchangeCodeStore reopened = new MeQrExchangeCodeStore(getTargetContext());
            check(reopened.load(profile.id, fingerprint).payload.equals(record.payload), "Restart retains code");
            reopened.markSynced(profile.id, record);
            check(reopened.load(profile.id, fingerprint).synced, "Sync status saved");
            check(reopened.load(profile.id, fingerprint).payload.equals(record.payload), "Sync never replaces QR");
            profile.subtitle = "changed";
            String changed = MeQrExchangeCodeStore.fingerprint(profile, i18n, null);
            check(!changed.equals(fingerprint) && reopened.load(profile.id, changed) == null, "Changes invalidate cache");
            MeQrExchangeCodeStore.Record replacement = MeQrExchangeCodeStore.create(profile, i18n, changed, null);
            store.save(profile.id, replacement);
            store.markSynced(profile.id, record);
            check(!store.load(profile.id, changed).synced, "Stale request cannot overwrite replacement");
            check(!MeQrExchangeCodeStore.fingerprint(profile, i18n, "event").equals(changed), "Event binding invalidates cache");
            result.putString("stream", "PASS: persistent hybrid QR, offline-first, sync stability, identity, invalidation, stale completion\n");
            finish(-1, result);
        } catch (Throwable error) {
            result.putString("stream", android.util.Log.getStackTraceString(error));
            finish(1, result);
        }
    }
    private static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }
}
