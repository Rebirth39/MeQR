package com.lucasli.meqr;

import java.net.URI;
import java.util.Locale;

final class QRLinkPolicy {
    private static final String[][] DOMAINS = {
        {"wechat", "wechat.com", "weixin.qq.com"}, {"qq", "qq.com"},
        {"whatsapp", "wa.me", "whatsapp.com"}, {"instagram", "instagram.com", "instagr.am"},
        {"twitter", "twitter.com", "x.com"}, {"tiktok", "tiktok.com"},
        {"snapchat", "snapchat.com"}, {"linkedin", "linkedin.com"}, {"github", "github.com"},
        {"facebook", "facebook.com", "fb.com", "fb.me"}, {"reddit", "reddit.com", "redd.it"},
        {"threads", "threads.net", "threads.com"}, {"twitch", "twitch.tv"},
        {"line", "line.me", "lin.ee"}, {"testflight", "testflight.apple.com"},
        {"xiaohongshu", "xiaohongshu.com", "xhslink.com"}, {"bilibili", "bilibili.com", "b23.tv"},
        {"douyin", "douyin.com", "iesdouyin.com"}, {"weibo", "weibo.com", "weibo.cn"}
    };

    static URI webURL(String text) {
        if (text == null) return null;
        try {
            URI uri = new URI(text.trim());
            String scheme = uri.getScheme();
            if (!("http".equalsIgnoreCase(scheme) || "https".equalsIgnoreCase(scheme))
                    || uri.getHost() == null || uri.getRawUserInfo() != null) return null;
            return uri;
        } catch (Exception ignored) { return null; }
    }

    static String platformID(String text) {
        URI uri = webURL(text);
        if (uri == null) return "custom";
        String host = uri.getHost().toLowerCase(Locale.ROOT);
        for (String[] group : DOMAINS) {
            for (int i = 1; i < group.length; i++) {
                if (host.equals(group[i]) || host.endsWith("." + group[i])) return group[0];
            }
        }
        return "custom";
    }

    static String warningKey(String text, String platform) {
        if (text == null || text.trim().isEmpty()) return null;
        URI uri = webURL(text);
        if (uri == null) {
            try {
                if ("custom".equals(platform) && new URI(text).getScheme() == null) return null;
            } catch (Exception ignored) {
                if ("custom".equals(platform) && !text.contains(":")) return null;
            }
            return "qrFormatWarning";
        }
        String host = uri.getHost().toLowerCase(Locale.ROOT);
        if (!"https".equalsIgnoreCase(uri.getScheme()) || host.contains(":") || host.matches("[0-9.]+"))
            return "qrDestinationWarning";
        if (!"custom".equals(platform) && !platformID(text).equals(platform)) return "qrFormatWarning";
        if ("qq".equals(platform)) {
            String path = uri.getPath();
            boolean shortLink = path.startsWith("/q/") && path.length() > 3;
            boolean legacy = path.equals("/cgi-bin/qm/qr") && uri.getRawQuery() != null
                    && java.util.Arrays.stream(uri.getRawQuery().split("&")).anyMatch(q -> q.startsWith("k=") && q.length() > 2);
            if (!host.equals("qm.qq.com") || !(shortLink || legacy)) return "qrFormatWarning";
        }
        return null;
    }
}
