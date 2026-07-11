package com.lucasli.meqr;

import java.util.Arrays;
import java.util.List;

final class PlatformNames {
    static final List<String> COMMON_IDS = Arrays.asList("wechat", "qq", "xiaohongshu", "bilibili", "instagram", "line", "github");
    static final List<String> SOCIAL_IDS = Arrays.asList("shortVideo", "weibo", "whatsapp", "twitter", "snapchat", "facebook", "reddit", "threads", "twitch");
    static final List<String> PROFESSIONAL_IDS = Arrays.asList("linkedin", "testflight");
    static final List<String> IDS = Arrays.asList(
            "wechat", "qq", "xiaohongshu", "bilibili", "instagram", "line", "github",
            "douyin", "tiktok", "weibo", "whatsapp", "twitter", "snapchat", "facebook", "reddit", "threads", "twitch",
            "linkedin", "testflight", "custom"
    );

    private PlatformNames() {
    }

    static String displayName(String id, I18n i18n) {
        if ("shortVideo".equals(id)) {
            id = shortVideoId(i18n);
        }
        switch (id) {
            case "wechat":
                return i18n.t("wechat");
            case "qq":
                return "QQ";
            case "whatsapp":
                return "WhatsApp";
            case "instagram":
                return "Instagram";
            case "twitter":
                return i18n.t("twitter");
            case "snapchat":
                return "Snapchat";
            case "facebook":
                return "Facebook";
            case "reddit":
                return "Reddit";
            case "threads":
                return "Threads";
            case "twitch":
                return "Twitch";
            case "linkedin":
                return "LinkedIn";
            case "github":
                return "GitHub";
            case "line":
                return "LINE";
            case "testflight":
                return "TestFlight";
            case "email":
                return i18n.t("email");
            case "phone":
                return i18n.t("phone");
            case "xiaohongshu":
                return i18n.t("xiaohongshu");
            case "bilibili":
                return i18n.t("bilibili");
            case "douyin":
            case "tiktok":
                return i18n.t("douyinTikTok");
            case "weibo":
                return i18n.t("weibo");
            case "custom":
                return i18n.t("custom");
            default:
                return Character.toUpperCase(id.charAt(0)) + id.substring(1);
        }
    }

    static String actualId(String id, I18n i18n) {
        return "shortVideo".equals(id) ? shortVideoId(i18n) : id;
    }

    static String detect(String text) {
        String lower = text == null ? "" : text.toLowerCase();
        if (lower.contains("u.wechat.com") || lower.contains("wechat.com") || lower.contains("weixin")) return "wechat";
        if (lower.contains("qm.qq.com") || lower.contains("qq.com")) return "qq";
        if (lower.contains("wa.me") || lower.contains("whatsapp.com")) return "whatsapp";
        if (lower.contains("instagram.com") || lower.contains("instagr.am")) return "instagram";
        if (lower.contains("twitter.com") || lower.contains("x.com")) return "twitter";
        if (lower.contains("tiktok.com") || lower.contains("vm.tiktok.com")) return "tiktok";
        if (lower.contains("snapchat.com")) return "snapchat";
        if (lower.contains("linkedin.com")) return "linkedin";
        if (lower.contains("github.com")) return "github";
        if (lower.contains("facebook.com") || lower.contains("fb.com") || lower.contains("fb.me")) return "facebook";
        if (lower.contains("reddit.com")) return "reddit";
        if (lower.contains("threads.net")) return "threads";
        if (lower.contains("twitch.tv")) return "twitch";
        if (lower.contains("testflight.apple.com")) return "testflight";
        if (lower.contains("xiaohongshu.com") || lower.contains("xhslink.com")) return "xiaohongshu";
        if (lower.contains("bilibili.com") || lower.contains("b23.tv")) return "bilibili";
        if (lower.contains("douyin.com") || lower.contains("iesdouyin.com")) return "douyin";
        if (lower.contains("weibo.com") || lower.contains("weibo.cn")) return "weibo";
        return "custom";
    }

    static String matchingName(String name, I18n i18n) {
        String normalized = normalize(name);
        switch (normalized) {
            case "wechat":
            case "weixin":
            case "wx":
            case "微信":
                return "wechat";
            case "qq":
                return "qq";
            case "xiaohongshu":
            case "xhs":
            case "小红书":
            case "小紅書":
                return "xiaohongshu";
            case "bilibili":
            case "b站":
                return "bilibili";
            case "instagram":
            case "ig":
                return "instagram";
            case "line":
                return "line";
            case "github":
                return "github";
            case "douyin":
            case "抖音":
                return "douyin";
            case "tiktok":
                return "tiktok";
            case "weibo":
            case "微博":
                return "weibo";
            case "whatsapp":
                return "whatsapp";
            case "twitter":
            case "x":
                return "twitter";
            case "snapchat":
                return "snapchat";
            case "facebook":
            case "fb":
                return "facebook";
            case "reddit":
                return "reddit";
            case "threads":
                return "threads";
            case "twitch":
                return "twitch";
            case "linkedin":
                return "linkedin";
            case "testflight":
            case "tf":
                return "testflight";
            default:
                return null;
        }
    }

    private static String shortVideoId(I18n i18n) {
        String language = i18n.resolvedLanguage();
        if (I18n.ZH_HANS.equals(language) || I18n.ZH_HANT_HK.equals(language)) {
            return "douyin";
        }
        return "tiktok";
    }

    private static String normalize(String value) {
        String lower = value == null ? "" : value.trim().toLowerCase();
        StringBuilder builder = new StringBuilder();
        for (int i = 0; i < lower.length(); i++) {
            char c = lower.charAt(i);
            if (Character.isLetterOrDigit(c) || c > 127) {
                builder.append(c);
            }
        }
        return builder.toString();
    }
}
