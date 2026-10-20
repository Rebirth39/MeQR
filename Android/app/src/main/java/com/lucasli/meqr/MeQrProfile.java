package com.lucasli.meqr;

import org.json.JSONException;
import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.UUID;

final class MeQrProfile {
    static final int MAX_TAGS = 15;

    String id = UUID.randomUUID().toString();
    String name = "";
    String subtitle = "";
    String platform = "custom";
    String customPlatformName = "";
    String qrContent = "";
    final List<MeQrItem> qrItems = new ArrayList<>();
    final List<String> tags = new ArrayList<>();
    final Map<String, String> tagColorOverrides = new HashMap<>();
    final Map<String, Integer> tagTextWeights = new HashMap<>();
    final List<TagReference> tagReferences = new ArrayList<>();

    TagPair tagPair(String name) {
        TagReference reference = referenceFor(name);
        return reference == null ? null : reference.pairing;
    }

    boolean combineTags(String source, String target, String kind, String language) {
        int first = tags.indexOf(source), second = tags.indexOf(target);
        TagPair pair = TagPair.make(source, target, kind);
        if (first < 0 || second < 0 || pair == null || tagPair(source) != null || tagPair(target) != null) return false;
        String name = pair.display(language);
        if (pairConflicts(name, pair, null)) return false;
        tags.remove(Math.max(first, second));
        tags.set(Math.min(first, second), name);
        tagColorOverrides.remove(source); tagColorOverrides.remove(target);
        tagTextWeights.remove(source); tagTextWeights.remove(target);
        tagReferences.removeIf(reference -> reference.lastName.equals(source) || reference.lastName.equals(target));
        TagReference reference = new TagReference(name);
        reference.pairing = pair;
        reference.colors = pair.colors(); reference.solid = reference.colors[0];
        reference.override = "@preset";
        tagReferences.add(reference);
        tagColorOverrides.put(name, "@preset");
        return true;
    }

    boolean canSwapTag(String tag, String language) {
        TagPair pair = tagPair(tag);
        return tags.contains(tag) && pair != null && !pairConflicts(pair.swapped().display(language), pair.swapped(), tag);
    }

    boolean swapTag(String tag, String language) {
        if (!canSwapTag(tag, language)) return false;
        TagReference reference = referenceFor(tag);
        String name = reference.pairing.swapped().display(language);
        reference.pairing = reference.pairing.swapped();
        reference.lastName = reference.fallbackName = name;
        reference.colors = reference.pairing.colors(); reference.solid = reference.colors[0];
        String override = tagColorOverrides.remove(tag);
        int weight = tagTextWeight(tag); tagTextWeights.remove(tag);
        tags.set(tags.indexOf(tag), name);
        if (override != null) tagColorOverrides.put(name, override);
        setTagTextWeight(name, weight);
        return true;
    }

    private boolean pairConflicts(String name, TagPair pair, String excluding) {
        for (String tag : tags) {
            if (tag.equals(excluding)) continue;
            TagPair existing = tagPair(tag);
            if (CardTagIndex.normalizedKey(tag).equals(CardTagIndex.normalizedKey(name))
                    || existing != null && existing.identity().equals(pair.identity())) return true;
        }
        return false;
    }

    TagReference referenceFor(String name) {
        for (TagReference reference : tagReferences) {
            if (reference.lastName.equals(name) || reference.fallbackName.equals(name)) return reference;
        }
        return null;
    }

    void reconcileTags(String language) {
        if (RemoteTagCatalog.entries().isEmpty() && tagReferences.isEmpty()) return;
        List<TagReference> updated = new ArrayList<>();
        List<String> names = new ArrayList<>();
        Map<String, String> overrides = new HashMap<>();
        Map<String, Integer> weights = new HashMap<>();
        // Resolve old names before a rename can collide with a later tag's name.
        Map<String, TagReference> referencesByName = new HashMap<>();
        for (TagReference reference : tagReferences) referencesByName.putIfAbsent(reference.lastName, reference);
        for (TagReference reference : tagReferences) referencesByName.putIfAbsent(reference.fallbackName, reference);
        for (String tag : tags) {
            if (names.size() >= MAX_TAGS) break;
            TagReference reference = referencesByName.get(tag);
            if (reference == null) reference = new TagReference(tag);
            reference.override = tagColorOverrides.get(tag);
            reference.textWeight = tagTextWeight(tag);
            RemoteTagCatalog.Entry entry = RemoteTagCatalog.entryByID(reference.catalogID);
            if (entry != null) {
                reference.colors = entry.colors.clone();
                reference.solid = entry.solidColor == null ? reference.colors[0] : entry.solidColor;
            }
            if (reference.pairing != null) {
                reference.colors = reference.pairing.colors();
                reference.solid = reference.colors[0];
            }
            String display = language == null ? tag : reference.display(language);
            if (entry != null || reference.pairing != null) reference.fallbackName = display;
            reference.lastName = display;
            names.add(display); updated.add(reference);
            if (reference.override != null) overrides.put(display, reference.override);
            if (reference.textWeight != TagTextWeight.REGULAR) weights.put(display, reference.textWeight);
        }
        tagReferences.clear(); tagReferences.addAll(updated);
        tags.clear(); tags.addAll(names);
        tagColorOverrides.clear(); tagColorOverrides.putAll(overrides);
        tagTextWeights.clear(); tagTextWeights.putAll(weights);
    }

    int tagTextWeight(String tag) {
        return TagTextWeight.normalize(tagTextWeights.getOrDefault(tag, TagTextWeight.REGULAR));
    }

    void setTagTextWeight(String tag, int weight) {
        int normalized = TagTextWeight.normalize(weight);
        if (normalized == TagTextWeight.REGULAR) tagTextWeights.remove(tag);
        else tagTextWeights.put(tag, normalized);
    }

    int[] tagColors(String tag) { return tagColors(tag, tagColorOverrides.get(tag)); }

    int[] tagLibraryColors(String displayName) {
        String key = CardTagIndex.canonicalKey(displayName);
        for (String selected : tags) {
            if (CardTagIndex.canonicalKey(selected).equals(key)) return tagColors(selected);
        }
        return tagColors(displayName);
    }

    int[] tagColors(String tag, String override) {
        TagReference reference = referenceFor(tag);
        return reference == null ? CardTagColorPalette.colorsFor(tag, override) : reference.colors(override);
    }
    String template = "standard";
    String passSubtitle = "";
    String avatarPath = "";
    String backgroundPath = "";
    String bannerPath = "";
    String backgroundColor = "#FFFFFF";
    String borderColor = "#111111";
    String textColor = "#111111";
    String qrColor = "#111111";
    int cornerRadius = 28;
    float cardOpacity = 1.0f;
    boolean cardGlassEnabled = false;
    long createdAt = System.currentTimeMillis();
    int sortOrder = 0;

    MeQrProfile() {
        qrItems.add(new MeQrItem());
    }

    MeQrItem firstItem() {
        if (qrItems.isEmpty()) {
            qrItems.add(new MeQrItem());
        }
        return qrItems.get(0);
    }

    void syncLegacyFields() {
        MeQrItem item = firstItem();
        platform = item.platform;
        customPlatformName = item.customPlatformName;
        qrContent = item.qrContent;
    }

    String platformDisplayName(I18n i18n) {
        return firstItem().platformDisplayName(i18n);
    }

    JSONObject toJson() throws JSONException {
        syncLegacyFields();
        reconcileTags(null);
        JSONObject object = new JSONObject();
        object.put("id", id);
        object.put("name", name);
        object.put("subtitle", subtitle);
        object.put("platform", platform);
        object.put("customPlatformName", customPlatformName);
        object.put("qrContent", qrContent);
        JSONArray itemArray = new JSONArray();
        for (MeQrItem item : qrItems) {
            itemArray.put(item.toJson());
        }
        object.put("qrItems", itemArray);
        JSONArray tagArray = new JSONArray();
        for (String tag : tags) {
            tagArray.put(tag);
        }
        object.put("tags", tagArray);
        JSONObject tagColorObject = new JSONObject();
        for (Map.Entry<String, String> entry : tagColorOverrides.entrySet()) {
            tagColorObject.put(entry.getKey(), entry.getValue());
        }
        object.put("tagColorOverrides", tagColorObject);
        JSONObject tagWeightObject = new JSONObject();
        for (Map.Entry<String, Integer> entry : tagTextWeights.entrySet()) {
            tagWeightObject.put(entry.getKey(), TagTextWeight.normalize(entry.getValue()));
        }
        object.put("tagTextWeights", tagWeightObject);
        JSONArray referenceArray = new JSONArray();
        for (TagReference reference : tagReferences) referenceArray.put(reference.toJson());
        if (!tagReferences.isEmpty() || tags.isEmpty()) object.put("tagReferences", referenceArray);
        object.put("template", template);
        object.put("passSubtitle", passSubtitle);
        object.put("avatarPath", avatarPath);
        object.put("backgroundPath", backgroundPath);
        object.put("bannerPath", bannerPath);
        object.put("backgroundColor", backgroundColor);
        object.put("borderColor", borderColor);
        object.put("textColor", textColor);
        object.put("qrColor", qrColor);
        object.put("cornerRadius", cornerRadius);
        object.put("cardOpacity", cardOpacity);
        object.put("cardGlassEnabled", cardGlassEnabled);
        object.put("createdAt", createdAt);
        object.put("sortOrder", sortOrder);
        return object;
    }

    static MeQrProfile fromJson(JSONObject object) {
        MeQrProfile profile = new MeQrProfile();
        profile.id = object.optString("id", profile.id);
        profile.name = object.optString("name", "");
        profile.subtitle = object.optString("subtitle", "");
        profile.platform = object.optString("platform", "custom");
        profile.customPlatformName = object.optString("customPlatformName", "");
        profile.qrContent = object.optString("qrContent", "");
        profile.qrItems.clear();
        JSONArray itemArray = object.optJSONArray("qrItems");
        if (itemArray != null) {
            for (int i = 0; i < itemArray.length(); i++) {
                JSONObject item = itemArray.optJSONObject(i);
                if (item != null) {
                    profile.qrItems.add(MeQrItem.fromJson(item));
                }
            }
        }
        if (profile.qrItems.isEmpty()) {
            MeQrItem legacy = new MeQrItem();
            legacy.platform = profile.platform;
            legacy.customPlatformName = profile.customPlatformName;
            legacy.qrContent = profile.qrContent;
            profile.qrItems.add(legacy);
        }
        profile.tags.clear();
        profile.tagColorOverrides.clear();
        JSONArray tagArray = object.optJSONArray("tags");
        if (tagArray != null) {
            for (int i = 0; i < tagArray.length() && profile.tags.size() < MAX_TAGS; i++) {
                String tag = tagArray.optString(i, "").trim();
                boolean duplicate = false;
                for (String existing : profile.tags) {
                    if (CardTagIndex.canonicalKey(existing).equals(CardTagIndex.canonicalKey(tag))) {
                        duplicate = true;
                        break;
                    }
                }
                if (!tag.isEmpty() && !duplicate) {
                    profile.tags.add(tag);
                }
            }
        }
        JSONObject tagColorObject = object.optJSONObject("tagColorOverrides");
        if (tagColorObject != null) {
            Iterator<String> keys = tagColorObject.keys();
            while (keys.hasNext()) {
                String key = keys.next();
                String color = tagColorObject.optString(key, "");
                if (profile.tags.contains(key) && !color.isEmpty()) {
                    profile.tagColorOverrides.put(key, color);
                }
            }
        }
        JSONObject tagWeightObject = object.optJSONObject("tagTextWeights");
        if (tagWeightObject != null) {
            for (String tag : profile.tags) profile.setTagTextWeight(tag, tagWeightObject.optInt(tag, TagTextWeight.REGULAR));
        }
        String template = object.optString("template", "standard");
        profile.template = ("rhodes".equals(template) || "rhodesPass".equals(template)) ? "rhodes" : "standard";
        JSONArray references = object.optJSONArray("tagReferences");
        if (references != null) {
            profile.tags.clear(); profile.tagColorOverrides.clear(); profile.tagTextWeights.clear();
            for (int i = 0; i < references.length() && i < MAX_TAGS; i++) {
                JSONObject raw = references.optJSONObject(i);
                if (raw == null) continue;
                TagReference reference = TagReference.fromJson(raw);
                profile.tagReferences.add(reference); profile.tags.add(reference.lastName);
                if (reference.override != null) profile.tagColorOverrides.put(reference.lastName, reference.override);
                profile.setTagTextWeight(reference.lastName, reference.textWeight);
            }
        }
        profile.passSubtitle = object.optString("passSubtitle", "");
        profile.avatarPath = object.optString("avatarPath", "");
        profile.backgroundPath = object.optString("backgroundPath", "");
        profile.bannerPath = object.optString("bannerPath", "");
        profile.backgroundColor = object.optString("backgroundColor", "#FFFFFF");
        profile.borderColor = object.optString("borderColor", "#111111");
        profile.textColor = object.optString("textColor", "#111111");
        profile.qrColor = object.optString("qrColor", "#111111");
        profile.cornerRadius = object.optInt("cornerRadius", 28);
        profile.cardOpacity = (float) object.optDouble("cardOpacity", 1.0);
        profile.cardGlassEnabled = object.optBoolean("cardGlassEnabled", false);
        profile.createdAt = object.optLong("createdAt", System.currentTimeMillis());
        profile.sortOrder = object.optInt("sortOrder", 0);
        profile.syncLegacyFields();
        return profile;
    }

    static String normalizeTag(String value) {
        String trimmed = value == null ? "" : value.trim();
        StringBuilder result = new StringBuilder();
        int units = 0;
        for (int offset = 0; offset < trimmed.length();) {
            int codePoint = trimmed.codePointAt(offset);
            int next = units + (codePoint <= 0x7f ? 1 : 2);
            if (next > 20) {
                break;
            }
            result.appendCodePoint(codePoint);
            units = next;
            offset += Character.charCount(codePoint);
        }
        return result.toString();
    }
}
