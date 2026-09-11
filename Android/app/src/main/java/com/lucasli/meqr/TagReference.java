package com.lucasli.meqr;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import java.util.UUID;

final class TagReference {
    String catalogID = "";
    String localID = UUID.randomUUID().toString();
    String fallbackName;
    String lastName;
    int[] colors;
    int solid;
    String override;
    int textWeight = TagTextWeight.REGULAR;

    TagReference(String name) {
        fallbackName = lastName = name;
        RemoteTagCatalog.Entry entry = RemoteTagCatalog.entryFor(name);
        if (entry != null) catalogID = entry.id;
        colors = CardTagColorPalette.colorsFor(name, null);
        solid = CardTagColorPalette.solidColorFor(name);
    }

    String display(String language) {
        RemoteTagCatalog.Entry entry = RemoteTagCatalog.entryByID(catalogID);
        return entry == null ? fallbackName : entry.display(language);
    }

    String modeFor(String value) {
        if (CardTagColorPalette.isSolidOverride(value)) return "solid";
        if (value != null && (value.equals("@preset") || value.startsWith("@preset|"))) return "preset";
        if (CardTagColorPalette.parseColors(value).length > 0) return "custom";
        return colors(null).length > 1 ? "preset" : "solid";
    }

    java.util.List<String> customColorsFor(String value) {
        java.util.List<String> saved = new java.util.ArrayList<>();
        for (int color : CardTagColorPalette.parseColors(value)) saved.add(CardTagColorPalette.hex(color));
        if (saved.isEmpty()) saved.add(CardTagColorPalette.hex(colors("@solid")[0]));
        return saved;
    }

    int[] colors(String value) {
        if (CardTagColorPalette.modeFor(lastName, value).equals("custom")) return CardTagColorPalette.colorsFor(lastName, value);
        RemoteTagCatalog.Entry entry = RemoteTagCatalog.entryByID(catalogID);
        if (CardTagColorPalette.isSolidOverride(value)) return new int[]{entry == null || entry.solidColor == null ? solid : entry.solidColor};
        return entry == null ? colors.clone() : entry.colors.clone();
    }

    JSONObject toJson() throws JSONException {
        JSONArray palette = new JSONArray(); for (int color : colors) palette.put(CardTagColorPalette.hex(color));
        return new JSONObject().put("catalogID", catalogID).put("localID", localID).put("fallbackName", fallbackName)
                .put("lastName", lastName).put("colors", palette).put("solidColor", CardTagColorPalette.hex(solid)).put("override", override)
                .put("textWeight", TagTextWeight.normalize(textWeight));
    }

    static TagReference fromJson(JSONObject object) {
        TagReference value = new TagReference(object.optString("fallbackName"));
        value.catalogID = object.optString("catalogID"); value.localID = object.optString("localID", value.localID);
        value.lastName = object.optString("lastName", value.fallbackName);
        JSONArray colors = object.optJSONArray("colors");
        if (colors != null && colors.length() > 0) {
            value.colors = new int[Math.min(6, colors.length())];
            for (int i = 0; i < value.colors.length; i++) value.colors[i] = CardTagColorPalette.parseHex(colors.optString(i), 0xFF6F7582);
        }
        value.solid = CardTagColorPalette.parseHex(object.optString("solidColor"), value.colors[0]);
        value.override = object.has("override") ? object.optString("override", null) : null;
        value.textWeight = TagTextWeight.normalize(object.optInt("textWeight", TagTextWeight.REGULAR));
        return value;
    }
}
