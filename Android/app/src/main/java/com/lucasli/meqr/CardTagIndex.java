package com.lucasli.meqr;

import java.util.List;
import java.util.Locale;
import java.util.Collections;

final class CardTagIndex {
    private CardTagIndex() {
    }

    static List<String> suggestions(String query, I18n i18n, List<String> excluding, int limit) {
        if (normalizedKey(query).isEmpty()) {
            return Collections.emptyList();
        }
        return RemoteTagCatalog.suggestions(query, i18n, excluding, limit);
    }

    static String normalizedKey(String value) {
        return value == null ? "" : value.toLowerCase(Locale.US)
                .replaceAll("[\\s_　・·'’!！:：,，.。/\\-×x]", "")
                .trim();
    }

    static String canonicalKey(String value) {
        return RemoteTagCatalog.canonicalKey(value);
    }
}
