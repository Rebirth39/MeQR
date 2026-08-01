package com.lucasli.meqr;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

final class CardTagIndex {
    private static final List<Entry> ENTRIES = new ArrayList<>();

    static {
        add("世界计划", "Project Sekai", "プロセカ", "pjsk", "project sekai", "彩舞", "世嘉彩舞");
        add("Leo/need", "Leo/need", "Leo/need", "ln", "l/n", "レオニ");
        add("MORE MORE JUMP!", "MORE MORE JUMP!", "MORE MORE JUMP!", "mmj", "桃跳", "モモジャン");
        add("Vivid BAD SQUAD", "Vivid BAD SQUAD", "Vivid BAD SQUAD", "vbs", "ビビバス");
        add("Wonderlands x Showtime", "Wonderlands x Showtime", "ワンダーランズ x ショウタイム", "wxs", "ws", "ワンダショ");
        add("Wonderlands x Showtime 拼色", "Wonderlands x Showtime Mix", "ワンダショMIX", "wsmix", "wxs mix", "ws拼色");
        add("25点，Nightcord见。", "Nightcord at 25:00", "25時、ナイトコードで。", "n25", "25ji", "nightcord", "ニーゴ");
        add("星乃一歌", "Ichika Hoshino", "星乃一歌", "一歌", "ichika");
        add("天马咲希", "Saki Tenma", "天馬咲希", "咲希", "saki");
        add("望月穗波", "Honami Mochizuki", "望月穂波", "穗波", "honami");
        add("日野森志步", "Shiho Hinomori", "日野森志歩", "志步", "shiho");
        add("花里实乃理", "Minori Hanasato", "花里みのり", "实乃理", "minori");
        add("桐谷遥", "Haruka Kiritani", "桐谷遥", "遥", "haruka");
        add("桃井爱莉", "Airi Momoi", "桃井愛莉", "爱莉", "airi");
        add("日野森雫", "Shizuku Hinomori", "日野森雫", "shizuku");
        add("小豆泽心羽", "Kohane Azusawa", "小豆沢こはね", "心羽", "kohane");
        add("白石杏", "An Shiraishi", "白石杏", "杏", "shiraishi an");
        add("东云彰人", "Akito Shinonome", "東雲彰人", "彰人", "akito");
        add("青柳冬弥", "Toya Aoyagi", "青柳冬弥", "冬弥", "toya");
        add("天马司", "Tsukasa Tenma", "天馬司", "司", "tsukasa");
        add("凤笑梦", "Emu Otori", "鳳えむ", "笑梦", "emu");
        add("草薙宁宁", "Nene Kusanagi", "草薙寧々", "宁宁", "nene");
        add("神代类", "Rui Kamishiro", "神代類", "类", "rui");
        add("宵崎奏", "Kanade Yoisaki", "宵崎奏", "奏", "kanade");
        add("朝比奈真冬", "Mafuyu Asahina", "朝比奈まふゆ", "真冬", "mafuyu");
        add("东云绘名", "Ena Shinonome", "東雲絵名", "绘名", "ena");
        add("晓山瑞希", "Mizuki Akiyama", "暁山瑞希", "瑞希", "mizuki");
        add("VOCALOID", "VOCALOID", "ボカロ", "术力口", "vocalo");
        add("初音未来", "Hatsune Miku", "初音ミク", "初音", "miku");
        add("镜音铃", "Kagamine Rin", "鏡音リン", "rin");
        add("镜音连", "Kagamine Len", "鏡音レン", "len");
        add("巡音流歌", "Megurine Luka", "巡音ルカ", "luka");
        add("MEIKO", "MEIKO", "MEIKO");
        add("KAITO", "KAITO", "KAITO");
        add("BanG Dream!", "BanG Dream!", "バンドリ", "bandori", "邦邦");
        add("Poppin'Party", "Poppin'Party", "Poppin'Party", "popipa", "ポピパ");
        add("Afterglow", "Afterglow", "Afterglow", "aglow");
        add("Pastel*Palettes", "Pastel*Palettes", "Pastel*Palettes", "pasupare", "パスパレ");
        add("Roselia", "Roselia", "Roselia");
        add("Hello Happy World!", "Hello Happy World!", "ハロー、ハッピーワールド！", "hhw", "ハロハピ");
        add("Morfonica", "Morfonica", "Morfonica", "monica", "モニカ");
        add("RAISE A SUILEN", "RAISE A SUILEN", "RAISE A SUILEN", "ras");
        add("MyGO!!!!!", "MyGO!!!!!", "MyGO!!!!!", "mygo", "迷子");
        add("Ave Mujica", "Ave Mujica", "Ave Mujica", "avemujica", "母鸡卡");
        add("梦限大 Mewtype", "Mugendai Mewtype", "夢限大みゅーたいぷ", "mugendai", "梦限大");
        add("高松灯", "Tomori Takamatsu", "高松燈", "灯", "tomori");
        add("千早爱音", "Anon Chihaya", "千早愛音", "爱音", "anon");
        add("要乐奈", "Raana Kaname", "要楽奈", "乐奈", "raana");
        add("长崎素世", "Soyo Nagasaki", "長崎そよ", "素世", "soyo");
        add("椎名立希", "Taki Shiina", "椎名立希", "立希", "taki");
        add("明日方舟", "Arknights", "アークナイツ", "arknights", "方舟", "罗德岛");
        add("蔚蓝档案", "Blue Archive", "ブルーアーカイブ", "blue archive", "ba", "ブルアカ");
        add("崩坏：星穹铁道", "Honkai: Star Rail", "崩壊：スターレイル", "hsr", "星铁", "star rail");
        add("原神", "Genshin Impact", "原神", "genshin");
        add("LoveLive!", "LoveLive!", "ラブライブ！", "lovelive", "ll");
        add("偶像梦幻祭", "Ensemble Stars", "あんさんぶるスターズ！", "enstars", "あんスタ");
        add("赛马娘", "Uma Musume", "ウマ娘", "umamusume", "马娘");
        add("孤独摇滚", "Bocchi the Rock!", "ぼっち・ざ・ろっく！", "bocchi", "孤摇");
        add("轻音少女", "K-ON!", "けいおん！", "k-on", "kon");
        add("少女乐队的呐喊", "Girls Band Cry", "ガールズバンドクライ", "gbc", "ガルクラ");
        add("东方Project", "Touhou Project", "東方Project", "touhou", "东方");
        add("新世纪福音战士", "Evangelion", "エヴァンゲリオン", "eva", "nge");
        add("葬送的芙莉莲", "Frieren", "葬送のフリーレン", "frieren", "芙莉莲");
        add("咒术回战", "Jujutsu Kaisen", "呪術廻戦", "jjk", "jujutsu");
        add("鬼灭之刃", "Demon Slayer", "鬼滅の刃", "kimetsu", "demonslayer");
        add("排球少年", "Haikyu!!", "ハイキュー!!", "haikyuu");
        add("名侦探柯南", "Detective Conan", "名探偵コナン", "conan");
        add("进击的巨人", "Attack on Titan", "進撃の巨人", "aot", "snk");
        add("电锯人", "Chainsaw Man", "チェンソーマン", "csm", "chainsawman");
        add("我推的孩子", "Oshi no Ko", "【推しの子】", "oshinoko");
        add("间谍过家家", "SPY x FAMILY", "SPY×FAMILY", "spyfamily", "spy x family");
        add("宝可梦", "Pokémon", "ポケモン", "pokemon", "口袋妖怪");
    }

    private CardTagIndex() {
    }

    static List<String> all(I18n i18n, List<String> excluding) {
        return matching("", i18n, excluding, Integer.MAX_VALUE);
    }

    static List<String> suggestions(String query, I18n i18n, List<String> excluding, int limit) {
        return matching(query, i18n, excluding, limit);
    }

    static String normalizedKey(String value) {
        return value == null ? "" : value.toLowerCase(Locale.US)
                .replaceAll("[\\s_　・·'’!！:：,，.。/\\-×x]", "")
                .trim();
    }

    static String canonicalKey(String value) {
        String key = normalizedKey(value);
        for (Entry entry : ENTRIES) {
            if (entry.exactlyMatches(key)) {
                return normalizedKey(entry.zhHans);
            }
        }
        return key;
    }

    private static List<String> matching(String query, I18n i18n, List<String> excluding, int limit) {
        String key = normalizedKey(query);
        Set<String> existing = new HashSet<>();
        for (String tag : excluding) {
            existing.add(canonicalKey(tag));
        }
        List<String> result = new ArrayList<>();
        for (Entry entry : ENTRIES) {
            String display = entry.display(i18n.resolvedLanguage());
            if (existing.contains(canonicalKey(display)) || !entry.matches(key)) {
                continue;
            }
            result.add(display);
            if (result.size() >= limit) {
                break;
            }
        }
        return result;
    }

    private static void add(String zhHans, String english, String japanese, String... aliases) {
        ENTRIES.add(new Entry(zhHans, english, japanese, aliases));
    }

    private static final class Entry {
        final String zhHans;
        final String english;
        final String japanese;
        final String[] aliases;

        Entry(String zhHans, String english, String japanese, String[] aliases) {
            this.zhHans = zhHans;
            this.english = english;
            this.japanese = japanese;
            this.aliases = aliases;
        }

        String display(String language) {
            if (I18n.EN.equals(language)) {
                return english;
            }
            if (I18n.JA.equals(language)) {
                return japanese;
            }
            return zhHans;
        }

        boolean matches(String query) {
            if (query.isEmpty() || normalizedKey(zhHans).contains(query)
                    || normalizedKey(english).contains(query) || normalizedKey(japanese).contains(query)) {
                return true;
            }
            for (String alias : aliases) {
                if (normalizedKey(alias).contains(query)) {
                    return true;
                }
            }
            return false;
        }

        boolean exactlyMatches(String query) {
            if (normalizedKey(zhHans).equals(query) || normalizedKey(english).equals(query)
                    || normalizedKey(japanese).equals(query)) {
                return true;
            }
            for (String alias : aliases) {
                if (normalizedKey(alias).equals(query)) {
                    return true;
                }
            }
            return false;
        }
    }
}
