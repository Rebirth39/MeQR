package com.lucasli.meqr;

import android.graphics.Color;

import java.util.HashMap;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Keyword-based tag color index, mirroring the iOS card tag palette. One color per
 * IP/project; unit and character aliases map to their project color.
 */
final class CardTagColorPalette {
    private static final String SOLID_OVERRIDE = "@solid";
    static final int MAX_CUSTOM_COLORS = 5;
    private static final Map<String, Integer> BY_KEYWORD = new HashMap<>();
    private static final Map<String, int[]> MULTI_BY_KEYWORD = new HashMap<>();

    static {
        put("术力口", 0xFF39C5BB);
        put("vocaloid", 0xFF39C5BB);
        put("ボカロ", 0xFF39C5BB);
        put("初音未来", 0xFF39C5BB);
        put("初音ミク", 0xFF39C5BB);
        put("miku", 0xFF39C5BB);
        put("hatsune", 0xFF39C5BB);

        put("mygo", 0xFF3381B0);
        put("迷子", 0xFF3381B0);
        put("mygo!!!!!", 0xFF3381B0);

        put("projectsekai", 0xFF39C5BB);
        put("psekai", 0xFF39C5BB);
        put("pjs", 0xFF39C5BB);
        put("プロセカ", 0xFF39C5BB);
        put("世界计划", 0xFF39C5BB);
        put("世界計畫", 0xFF39C5BB);
        put("彩舞", 0xFF39C5BB);
        put("世嘉彩舞", 0xFF39C5BB);
        put("leoneed", 0xFF4455DD);
        put("ln", 0xFF4455DD);
        put("mmj", 0xFF88DD44);
        put("moremorejump", 0xFF88DD44);
        put("wonderlands", 0xFFFF9900);
        put("ws", 0xFFFF9900);
        put("ワンダショ", 0xFFFF9900);
        put("vbs", 0xFFEE1166);
        put("vividbad", 0xFFEE1166);
        put("n25", 0xFF884499);
        put("nightcord", 0xFF884499);
        put("25时", 0xFF884499);
        put("25時", 0xFF884499);

        put("avemujica", 0xFF6C5CE7);
        put("母鸡卡", 0xFF6C5CE7);
        put("母雞卡", 0xFF6C5CE7);

        put("bangdream", 0xFFE84393);
        put("バンドリ", 0xFFE84393);
        put("邦邦", 0xFFE84393);
        put("roselia", 0xFFA29BFE);
        put("popipa", 0xFFFF6B81);
        put("poppinparty", 0xFFFF6B81);
        put("ポピパ", 0xFFFF6B81);

        put("arknights", 0xFF6E8094);
        put("明日方舟", 0xFF6E8094);
        put("アークナイツ", 0xFF6E8094);
        put("方舟", 0xFF6E8094);
        put("罗德岛", 0xFF6E8094);
        put("羅德島", 0xFF6E8094);

        put("bluearchive", 0xFF4FA3E3);
        put("ブルアカ", 0xFF4FA3E3);
        put("蔚蓝档案", 0xFF4FA3E3);
        put("蔚藍檔案", 0xFF4FA3E3);
        put("碧蓝档案", 0xFF4FA3E3);
        put("碧藍檔案", 0xFF4FA3E3);

        put("starrail", 0xFFD9A441);
        put("hsr", 0xFFD9A441);
        put("星铁", 0xFFD9A441);
        put("星鐵", 0xFFD9A441);
        put("honkaistarrail", 0xFFD9A441);

        put("genshin", 0xFF5FB4A4);
        put("原神", 0xFF5FB4A4);

        put("lovelive", 0xFFE94E9E);
        put("ラブライブ", 0xFFE94E9E);

        put("ensemblestars", 0xFFF7A600);
        put("あんスタ", 0xFFF7A600);
        put("偶像梦幻祭", 0xFFF7A600);
        put("偶像夢幻祭", 0xFFF7A600);

        put("idolmaster", 0xFFC9379E);
        put("アイマス", 0xFFC9379E);
        put("偶像大师", 0xFFC9379E);
        put("偶像大師", 0xFFC9379E);

        put("umamusume", 0xFFF27A9D);
        put("ウマ娘", 0xFFF27A9D);
        put("赛马娘", 0xFFF27A9D);
        put("賽馬娘", 0xFFF27A9D);

        put("bocchi", 0xFFF28C5B);
        put("ぼっち", 0xFFF28C5B);
        put("孤独摇滚", 0xFFF28C5B);
        put("孤獨搖滾", 0xFFF28C5B);

        put("touhou", 0xFFE2725B);
        put("东方", 0xFFE2725B);
        put("東方", 0xFFE2725B);

        put("evangelion", 0xFF8E44AD);
        put("eva", 0xFF8E44AD);
        put("新世纪福音战士", 0xFF8E44AD);
        put("新世紀福音戰士", 0xFF8E44AD);

        put("frieren", 0xFFA3C4BC);
        put("芙莉莲", 0xFFA3C4BC);
        put("芙莉蓮", 0xFFA3C4BC);

        put("jujutsu", 0xFFB03052);
        put("咒术回战", 0xFFB03052);
        put("咒術迴戰", 0xFFB03052);

        put("demonslayer", 0xFF2E9E8F);
        put("鬼灭之刃", 0xFF2E9E8F);
        put("鬼滅之刃", 0xFF2E9E8F);

        put("haikyuu", 0xFFF77F00);
        put("排球少年", 0xFFF77F00);

        put("conan", 0xFF3D6FB4);
        put("柯南", 0xFF3D6FB4);
        put("名侦探柯南", 0xFF3D6FB4);
        put("名偵探柯南", 0xFF3D6FB4);

        put("attackontitan", 0xFF7B5E57);
        put("aot", 0xFF7B5E57);
        put("进击的巨人", 0xFF7B5E57);
        put("進擊的巨人", 0xFF7B5E57);

        put("chainsawman", 0xFFC0392B);
        put("电锯人", 0xFFC0392B);
        put("電鋸人", 0xFFC0392B);

        put("oshinoko", 0xFF9B59B6);
        put("我推的孩子", 0xFF9B59B6);

        put("spyfamily", 0xFF7F8C8D);
        put("间谍过家家", 0xFF7F8C8D);
        put("間諜過家家", 0xFF7F8C8D);

        put("pokemon", 0xFFF1C40F);
        put("宝可梦", 0xFFF1C40F);
        put("寶可夢", 0xFFF1C40F);
        put("口袋妖怪", 0xFFF1C40F);

        putMulti(new int[]{0xFF39C5BB, 0xFF00A0E9, 0xFF88DD44, 0xFFFF9900, 0xFFEE1166, 0xFF884499},
                "projectsekai", "pjsk", "プロセカ", "世界计划", "世界計畫", "彩舞");
        putMulti(new int[]{0xFF39C5BB, 0xFFFFB000, 0xFFFFE211, 0xFFFF69B4, 0xFFD80000, 0xFF0068B7},
                "vocaloid", "术力口", "ボカロ");
        putMulti(new int[]{0xFF4455DD, 0xFF33AAEE, 0xFFFFDD44, 0xFFEE6666, 0xFFBBDD22},
                "leoneed", "ln", "レオニ");
        putMulti(new int[]{0xFF88DD44, 0xFFFFCCAA, 0xFF99CCFF, 0xFFFFAACC, 0xFF99EEDD},
                "moremorejump", "mmj", "モモジャン", "桃跳");
        putMulti(new int[]{0xFFEE1166, 0xFFFF6699, 0xFF00BBDD, 0xFFFF7722, 0xFF0077DD},
                "vividbadsquad", "vbs", "ビビバス");
        putMulti(new int[]{0xFFFF9900, 0xFFFFBB00, 0xFFFF66BB, 0xFF33DD99, 0xFFBB88EE},
                "wonderlandsxshowtime", "wonderlandsxshowtime拼色", "wsmix", "wxs", "ws", "ワンダショ", "ワンダショmix");
        putMulti(new int[]{0xFF884499, 0xFFBB6688, 0xFF8889CC, 0xFFCCAA88, 0xFFDDAACC},
                "nightcordat2500", "nightcord", "n25", "25点nightcord见", "25時ナイトコードで", "ニーゴ");
        putMulti(new int[]{0xFFFF3377, 0xFFFF5522, 0xFF0077DD, 0xFFFF55BB, 0xFFFFCC11, 0xFFAA66DD},
                "poppinparty", "popipa", "ポピパ");
        putMulti(new int[]{0xFFE53344, 0xFFEE0022, 0xFF00CCAA, 0xFFFF9999, 0xFFBB0033, 0xFFFFEE88},
                "afterglow", "aglow");
        putMulti(new int[]{0xFF33DDAA, 0xFFFF66AA, 0xFF66CCFF, 0xFFFFEE99, 0xFF88DD44, 0xFFCC99FF},
                "pastelpalettes", "pp", "パスパレ");
        putMulti(new int[]{0xFF3344AA, 0xFF881188, 0xFF00AABB, 0xFFDD2200, 0xFFDD0088, 0xFFBBBBBB},
                "roselia");
        putMulti(new int[]{0xFFFFC02A, 0xFFFFEE22, 0xFFAA33CC, 0xFFFF9922, 0xFF44DDFF, 0xFF006699},
                "hellohappyworld", "hhw", "ハロハピ");
        putMulti(new int[]{0xFF33AADD, 0xFF6677CC, 0xFFEE6666, 0xFFEE7744, 0xFFEE7788, 0xFF669988},
                "morfonica", "monica", "モニカ");
        putMulti(new int[]{0xFF66CC33, 0xFFCC0000, 0xFFAAEE22, 0xFFEEBB44, 0xFFFF99BB, 0xFF00BBFF},
                "raiseasuilen", "ras");
        putMulti(new int[]{0xFF3381B0, 0xFF77BBDD, 0xFFFF8899, 0xFF77DD77, 0xFFFFDD88, 0xFF7777AA},
                "mygo", "迷子");
        putMulti(new int[]{0xFF881144, 0xFFCC4466, 0xFF884499, 0xFF66AA66, 0xFF336699, 0xFFDDBB66},
                "avemujica", "母鸡卡", "母雞卡");
        putMulti(new int[]{0xFFF4B6C2, 0xFFFF99CC, 0xFFFFD34E, 0xFF5B8FE8, 0xFFE94B4B},
                "孤独摇滚", "孤獨搖滾", "bocchitherock");

        putSplit("星乃一歌", 0xFF4455DD, 0xFF33AAEE);
        putSplit("天马咲希", 0xFF4455DD, 0xFFFFDD44);
        putSplit("望月穗波", 0xFF4455DD, 0xFFEE6666);
        putSplit("日野森志步", 0xFF4455DD, 0xFFBBDD22);
        putSplit("高松灯", 0xFF3381B0, 0xFF77BBDD);
        putSplit("千早爱音", 0xFF3381B0, 0xFFFF8899);
        putSplit("要乐奈", 0xFF3381B0, 0xFF77DD77);
        putSplit("长崎素世", 0xFF3381B0, 0xFFFFDD88);
        putSplit("椎名立希", 0xFF3381B0, 0xFF7777AA);
    }

    private static final int[] GENERIC = {
        0xFF39C5BB, 0xFF3381B0, 0xFF88DD44, 0xFFFF9900,
        0xFFEE1166, 0xFF884499, 0xFFE84393, 0xFFF7A600,
    };

    private CardTagColorPalette() {
    }

    private static void put(String keyword, int color) {
        BY_KEYWORD.put(normalize(keyword), color);
    }

    private static void putMulti(int[] colors, String... keywords) {
        for (String keyword : keywords) {
            MULTI_BY_KEYWORD.put(normalize(keyword), colors);
        }
    }

    private static void putSplit(String keyword, int first, int second) {
        MULTI_BY_KEYWORD.put(normalize(keyword), new int[]{first, second});
    }

    static int colorFor(String tag) {
        if (tag == null || tag.trim().isEmpty()) {
            return GENERIC[0];
        }
        int[] remote = RemoteTagCatalog.colorsFor(tag);
        if (remote.length > 0) {
            return remote[0];
        }
        String normalized = normalize(tag);
        Integer mapped = BY_KEYWORD.get(normalized);
        if (mapped != null) {
            return mapped;
        }
        int hash = normalized.hashCode();
        return GENERIC[Math.floorMod(hash, GENERIC.length)];
    }

    static String hex(int color) {
        return String.format(Locale.US, "#%06X", color & 0xFFFFFF);
    }

    static int[] colorsFor(String tag, String override) {
        if (modeFor(tag, override).equals("custom")) {
            int[] custom = parseColors(override);
            if (custom.length > 0) return custom;
        }
        if (isSolidOverride(override)) return new int[]{solidColorFor(tag)};
        int[] preset = presetColorsFor(tag);
        if (preset.length > 0) {
            return isSolidOverride(override) ? new int[]{preset[0]} : preset;
        }
        return new int[]{colorFor(tag)};
    }

    static int solidColorFor(String tag) {
        Integer remote = RemoteTagCatalog.solidColorFor(tag);
        if (remote != null) return remote;
        int[] preset = presetColorsFor(tag);
        if (preset.length == 6 && preset[0] == 0xFF39C5BB && preset[1] == 0xFF00A0E9) return preset[1];
        return preset.length > 0 ? preset[preset.length == 2 ? 1 : 0] : colorFor(tag);
    }

    static String modeFor(String tag, String override) {
        if (isSolidOverride(override)) return "solid";
        if (override != null && (override.equals("@preset") || override.startsWith("@preset|"))) return "preset";
        if (parseColors(override).length > 0) return "custom";
        return hasPresetMulti(tag) ? "preset" : "solid";
    }

    static List<String> customColorsFor(String tag, String override) {
        List<String> colors = new ArrayList<>();
        for (int color : parseColors(override)) colors.add(hex(color));
        if (colors.isEmpty()) colors.add(hex(solidColorFor(tag)));
        return colors;
    }

    static String encodeMode(String mode, List<String> colors) {
        String encoded = encodeColors(colors);
        return mode.equals("custom") ? encoded : "@" + mode + (encoded.isEmpty() ? "" : "|" + encoded);
    }

    static boolean hasPresetMulti(String tag) {
        return presetColorsFor(tag).length > 1;
    }

    static boolean isPresetColored(String tag) {
        return presetColorsFor(tag).length > 0;
    }

    static int[] presetColorsFor(String tag) {
        int[] remote = RemoteTagCatalog.colorsFor(tag);
        if (remote.length > 0) {
            return remote;
        }
        String key = normalize(tag);
        int[] multi = MULTI_BY_KEYWORD.get(key);
        if (multi != null) {
            return multi.clone();
        }
        Integer single = BY_KEYWORD.get(key);
        return single == null ? new int[0] : new int[]{single};
    }

    static boolean isSolidOverride(String override) {
        return SOLID_OVERRIDE.equals(override) || (override != null && override.startsWith(SOLID_OVERRIDE + "|"));
    }

    static String solidOverrideValue() {
        return SOLID_OVERRIDE;
    }

    static String encodeColors(List<String> values) {
        List<String> valid = new ArrayList<>();
        for (String value : values) {
            String normalized = normalizedHex(value);
            if (normalized != null && valid.size() < MAX_CUSTOM_COLORS) {
                valid.add(normalized);
            }
        }
        return String.join("|", valid);
    }

    static String normalizedHex(String value) {
        if (value == null) {
            return null;
        }
        String normalized = value.trim().toUpperCase(Locale.US);
        if (!normalized.startsWith("#")) {
            normalized = "#" + normalized;
        }
        return normalized.matches("#[0-9A-F]{6}") ? normalized : null;
    }

    static int[] parseColors(String raw) {
        if (raw == null || raw.trim().isEmpty()) {
            return new int[0];
        }
        String[] parts = raw.split("[|,;/]+", -1);
        List<Integer> colors = new ArrayList<>();
        for (String part : parts) {
            String normalized = normalizedHex(part);
            if (normalized != null && colors.size() < MAX_CUSTOM_COLORS) {
                colors.add(Color.parseColor(normalized));
            }
        }
        int[] result = new int[colors.size()];
        for (int i = 0; i < colors.size(); i++) {
            result[i] = colors.get(i);
        }
        return result;
    }

    static String normalize(String tag) {
        return tag.toLowerCase(Locale.US)
                .replaceAll("[\\s_　・·'’!！:：,，.。/\\-×]", "")
                .trim();
    }

    static int parseHex(String value, int fallback) {
        try {
            return Color.parseColor(value == null || value.trim().isEmpty() ? "#000000" : value.trim());
        } catch (IllegalArgumentException exception) {
            return fallback;
        }
    }
}
