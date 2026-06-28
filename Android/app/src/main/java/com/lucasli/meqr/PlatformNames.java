package com.lucasli.meqr;

import java.util.Arrays;
import java.util.List;

final class PlatformNames {
    static final List<String> IDS = Arrays.asList(
            "wechat", "qq", "whatsapp", "instagram", "twitter", "tiktok",
            "snapchat", "telegram", "discord", "linkedin", "github",
            "facebook", "youtube", "email", "phone", "xiaohongshu",
            "bilibili", "douyin", "weibo", "custom"
    );

    private PlatformNames() {
    }

    static String displayName(String id, I18n i18n) {
        switch (id) {
            case "wechat":
                return i18n.t("wechat");
            case "twitter":
                return i18n.t("twitter");
            case "email":
                return i18n.t("email");
            case "phone":
                return i18n.t("phone");
            case "xiaohongshu":
                return i18n.t("xiaohongshu");
            case "bilibili":
                return i18n.t("bilibili");
            case "douyin":
                return i18n.t("douyin");
            case "weibo":
                return i18n.t("weibo");
            case "custom":
                return i18n.t("custom");
            default:
                return Character.toUpperCase(id.charAt(0)) + id.substring(1);
        }
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
        if (lower.contains("t.me") || lower.contains("telegram.me") || lower.contains("telegram.org")) return "telegram";
        if (lower.contains("discord.com") || lower.contains("discord.gg")) return "discord";
        if (lower.contains("linkedin.com")) return "linkedin";
        if (lower.contains("github.com")) return "github";
        if (lower.contains("facebook.com") || lower.contains("fb.com") || lower.contains("fb.me")) return "facebook";
        if (lower.contains("youtube.com") || lower.contains("youtu.be")) return "youtube";
        if (lower.contains("xiaohongshu.com") || lower.contains("xhslink.com")) return "xiaohongshu";
        if (lower.contains("bilibili.com") || lower.contains("b23.tv")) return "bilibili";
        if (lower.contains("douyin.com") || lower.contains("iesdouyin.com")) return "douyin";
        if (lower.contains("weibo.com") || lower.contains("weibo.cn")) return "weibo";
        if (lower.contains("mailto:")) return "email";
        if (!lower.startsWith("http://") && !lower.startsWith("https://") && lower.contains("@") && lower.contains(".")) return "email";
        return "custom";
    }
}
