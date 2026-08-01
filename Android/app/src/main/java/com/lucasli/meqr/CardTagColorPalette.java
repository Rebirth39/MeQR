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
        put("leoneed", 0xFF00A0E9);
        put("ln", 0xFF00A0E9);
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
        putMulti(new int[]{0xFF39C5BB, 0xFFFFE211, 0xFFFFB000, 0xFFFF69B4, 0xFFE44D98, 0xFF0068B7},
                "vocaloid", "术力口", "ボカロ");
        putMulti(new int[]{0xFF00A0E9, 0xFF33AAEE, 0xFFFFDD45, 0xFFEE6666, 0xFFBBDD22},
                "leoneed", "ln", "レオニ");
        putMulti(new int[]{0xFF88DD44, 0xFFFFCCAA, 0xFF99CCFF, 0xFFFFAACC, 0xFF99EEDD},
                "moremorejump", "mmj", "モモジャン", "桃跳");
        putMulti(new int[]{0xFFEE1166, 0xFFFF6699, 0xFF00BBDD, 0xFFFF7722, 0xFF0077DD},
                "vividbadsquad", "vbs", "ビビバス");
        putMulti(new int[]{0xFFFF9900, 0xFFFFBB00, 0xFFFF66BB, 0xFF33DD99, 0xFFBB88EE},
                "wonderlandsxshowtime", "wonderlandsxshowtime拼色", "wsmix", "wxs", "ws", "ワンダショ", "ワンダショmix");
        putMulti(new int[]{0xFF884499, 0xFFBB6688, 0xFF8889CC, 0xFFCCAA88, 0xFFDDAACC},
                "nightcordat2500", "nightcord", "n25", "25点nightcord见", "25時ナイトコードで", "ニーゴ");
        putMulti(new int[]{0xFFFF3377, 0xFFFF5522, 0xFF3366CC, 0xFFFF99CC, 0xFFFFCC33, 0xFFAA66CC},
                "poppinparty", "popipa", "ポピパ");
        putMulti(new int[]{0xFFE53344, 0xFFE5004F, 0xFF55BB77, 0xFFFF77AA, 0xFFCC3333, 0xFFFFCC66},
                "afterglow", "aglow");
        putMulti(new int[]{0xFF33DDAA, 0xFFFF66AA, 0xFF66CCFF, 0xFFFFEE99, 0xFF88DD44, 0xFFCC99FF},
                "pastelpalettes", "pp", "パスパレ");
        putMulti(new int[]{0xFF3344AA, 0xFF66CCFF, 0xFFDD2244, 0xFFAA44DD, 0xFF9999CC},
                "roselia");
        putMulti(new int[]{0xFFFFC02A, 0xFFFFCC33, 0xFFAA66CC, 0xFFFF9933, 0xFF66CCFF, 0xFF996633},
                "hellohappyworld", "hhw", "ハロハピ");
        putMulti(new int[]{0xFF33AADD, 0xFFAABBFF, 0xFFFF99CC, 0xFF99DD66, 0xFFFFCC66, 0xFF6699CC},
                "morfonica", "monica", "モニカ");
        putMulti(new int[]{0xFF66CC33, 0xFFAA3333, 0xFF77CC44, 0xFFFF9933, 0xFFFF77BB, 0xFF66CCFF},
                "raiseasuilen", "ras");
        putMulti(new int[]{0xFF3381B0, 0xFF77BBDD, 0xFFFF8899, 0xFF66CC99, 0xFFDDBB66, 0xFF4455AA},
                "mygo", "迷子");
        putMulti(new int[]{0xFF881144, 0xFFCC4466, 0xFF884499, 0xFF66AA66, 0xFF336699, 0xFFDDBB66},
                "avemujica", "母鸡卡", "母雞卡");
        putMulti(new int[]{0xFFF4B6C2, 0xFFFF99CC, 0xFFFFD34E, 0xFF5B8FE8, 0xFFE94B4B},
                "孤独摇滚", "孤獨搖滾", "bocchitherock");

        putSplit("星乃一歌", 0xFF00A0E9, 0xFF33AAEE);
        putSplit("天马咲希", 0xFF00A0E9, 0xFFFFDD45);
        putSplit("望月穗波", 0xFF00A0E9, 0xFFEE6666);
        putSplit("日野森志步", 0xFF00A0E9, 0xFFBBDD22);
        putSplit("高松灯", 0xFF3381B0, 0xFF77BBDD);
        putSplit("千早爱音", 0xFF3381B0, 0xFFFF8899);
        putSplit("要乐奈", 0xFF3381B0, 0xFF66CC99);
        putSplit("长崎素世", 0xFF3381B0, 0xFFDDBB66);
        putSplit("椎名立希", 0xFF3381B0, 0xFF4455AA);
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
        int[] custom = parseColors(override);
        if (custom.length > 0) {
            return custom;
        }
        int[] preset = MULTI_BY_KEYWORD.get(normalize(tag));
        return preset == null ? new int[]{colorFor(tag)} : preset.clone();
    }

    static boolean hasPresetMulti(String tag) {
        return MULTI_BY_KEYWORD.containsKey(normalize(tag));
    }

    static String encodeColors(List<String> values) {
        List<String> valid = new ArrayList<>();
        for (String value : values) {
            String normalized = normalizedHex(value);
            if (normalized != null && valid.size() < 3) {
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

    private static int[] parseColors(String raw) {
        if (raw == null || raw.trim().isEmpty()) {
            return new int[0];
        }
        String[] parts = raw.split("[|,;/]+", -1);
        List<Integer> colors = new ArrayList<>();
        for (String part : parts) {
            String normalized = normalizedHex(part);
            if (normalized != null && colors.size() < 3) {
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
