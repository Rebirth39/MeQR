package com.lucasli.meqr;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

final class TagPair {
    static final String CP = "CP", CB = "CB";
    private static final int[] SURNAME_LENGTHS = {2, 2, 2, 3, 2, 2, 2, 3, 3, 2, 2, 2, 2, 1, 2, 2, 2, 3, 2, 2};
    private static final String[] LANGUAGES = {I18n.ZH_HANS, I18n.ZH_HANT_HK, I18n.ZH_HANT_TW, I18n.EN, I18n.JA};
    private static final String[] NAME_KEYS = {"zhHans", "zhHantHK", "zhHantTW", "en", "ja"};
    final String kind;
    final Member left, right;

    private TagPair(String kind, Member left, Member right) {
        this.kind = kind;
        this.left = left;
        this.right = right;
    }

    static final class Member {
        final String catalogID;
        private final String[] names;
        private final int color;

        Member(String catalogID, String[] names, int color) {
            this.catalogID = catalogID;
            this.names = names.clone();
            this.color = color;
        }

        String display(String language) {
            RemoteTagCatalog.Entry entry = RemoteTagCatalog.entryByID(catalogID);
            int locale = 0;
            for (int index = 0; index < LANGUAGES.length; index++) if (LANGUAGES[index].equals(language)) locale = index;
            String full = entry == null ? names[locale] : entry.display(language);
            if (I18n.EN.equals(language)) return full.split(" ")[0];
            int count = SURNAME_LENGTHS[characterIndex(catalogID)];
            return full.substring(full.offsetByCodePoints(0, Math.min(count, full.codePointCount(0, full.length()))));
        }

        int color() {
            RemoteTagCatalog.Entry entry = RemoteTagCatalog.entryByID(catalogID);
            return entry == null ? color : entry.solidColor == null ? entry.colors[0] : entry.solidColor;
        }

        JSONObject toJson() throws JSONException {
            JSONObject snapshot = new JSONObject();
            RemoteTagCatalog.Entry entry = RemoteTagCatalog.entryByID(catalogID);
            for (int index = 0; index < NAME_KEYS.length; index++)
                snapshot.put(NAME_KEYS[index], entry == null ? names[index] : entry.display(LANGUAGES[index]));
            return new JSONObject().put("catalogID", catalogID).put("names", snapshot).put("color", CardTagColorPalette.hex(color()));
        }
    }

    private static int characterIndex(String id) {
        if (id == null || !id.matches("tag-[0-9]{4}")) return -1;
        int index = Integer.parseInt(id.substring(4)) - 8;
        return index >= 0 && index < SURNAME_LENGTHS.length ? index : -1;
    }

    static RemoteTagCatalog.Entry character(String name) {
        RemoteTagCatalog.Entry entry = RemoteTagCatalog.entryFor(name);
        if (entry == null || !"character".equals(entry.kind) || characterIndex(entry.id) < 0) return null;
        for (RemoteTagCatalog.Category category : RemoteTagCatalog.categories())
            if ("ip-project-sekai".equals(category.id) && category.contains(entry.id)) return entry;
        return null;
    }

    static TagPair make(String first, String second, String kind) {
        RemoteTagCatalog.Entry left = character(first), right = character(second);
        if ((!CP.equals(kind) && !CB.equals(kind)) || left == null || right == null || left.id.equals(right.id)) return null;
        return new TagPair(kind, member(left), member(right));
    }

    private static Member member(RemoteTagCatalog.Entry entry) {
        String[] names = new String[LANGUAGES.length];
        for (int index = 0; index < names.length; index++) names[index] = entry.display(LANGUAGES[index]);
        return new Member(entry.id, names, entry.solidColor == null ? entry.colors[0] : entry.solidColor);
    }

    String display(String language) { return left.display(language) + "&" + right.display(language); }
    String identity() { return "pair:" + left.catalogID + ":" + right.catalogID; }
    int[] colors() { return new int[]{left.color(), right.color()}; }
    boolean isCB() { return CB.equals(kind); }
    TagPair swapped() { return new TagPair(kind, right, left); }
    TagPair withKind(String value) { return new TagPair(CB.equals(value) ? CB : CP, left, right); }

    JSONObject toJson() throws JSONException {
        return new JSONObject().put("kind", kind).put("members", new JSONArray().put(left.toJson()).put(right.toJson()));
    }

    static TagPair fromJson(JSONObject value) {
        if (value == null) return null;
        String kind = value.optString("kind");
        JSONArray members = value.optJSONArray("members");
        if ((!CP.equals(kind) && !CB.equals(kind)) || members == null || members.length() != 2) return null;
        Member[] parsed = new Member[2];
        for (int index = 0; index < 2; index++) {
            JSONObject member = members.optJSONObject(index);
            if (member == null || characterIndex(member.optString("catalogID")) < 0) return null;
            JSONObject snapshot = member.optJSONObject("names");
            String hex = CardTagColorPalette.normalizedHex(member.optString("color"));
            if (snapshot == null || hex == null) return null;
            String[] names = new String[NAME_KEYS.length];
            for (int locale = 0; locale < names.length; locale++) {
                names[locale] = snapshot.optString(NAME_KEYS[locale]).trim();
                if (names[locale].isEmpty()) return null;
            }
            parsed[index] = new Member(member.optString("catalogID"), names, CardTagColorPalette.parseHex(hex, 0xFF6F7582));
        }
        return parsed[0].catalogID.equals(parsed[1].catalogID) ? null : new TagPair(kind, parsed[0], parsed[1]);
    }
}
