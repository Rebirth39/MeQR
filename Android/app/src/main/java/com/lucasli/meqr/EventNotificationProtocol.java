package com.lucasli.meqr;

final class EventNotificationProtocol {
    static final int VERSION = 1;
    static final int MAX_HOP_COUNT = 8;
    static final int MAX_NOTIFICATION_BYTES = 64 * 1024;

    static final class EventCertificate {
        final String eventId, channelId, eventName, publicKey, signature;
        final long validFrom, validUntil;
        EventCertificate(String eventId, String channelId, String eventName, String publicKey,
                         long validFrom, long validUntil, String signature) {
            this.eventId = eventId; this.channelId = channelId; this.eventName = eventName;
            this.publicKey = publicKey; this.validFrom = validFrom; this.validUntil = validUntil;
            this.signature = signature;
        }
    }

    static final class CheckInChallenge {
        final String eventId, challenge, signature;
        final long issuedAt, expiresAt;
        CheckInChallenge(String eventId, String challenge, long issuedAt, long expiresAt, String signature) {
            this.eventId = eventId; this.challenge = challenge; this.issuedAt = issuedAt;
            this.expiresAt = expiresAt; this.signature = signature;
        }
    }

    private EventNotificationProtocol() { }
}
