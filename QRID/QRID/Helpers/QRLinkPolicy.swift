import Foundation

enum QRLinkPolicy {
    enum TrustedDestination { case wechatScan, qq, xiaohongshu, web }

    static func platformDestination(_ text: String) -> TrustedDestination? {
        if let trusted = trustedDestination(text) { return trusted }
        guard let url = webURL(text), url.scheme?.lowercased() == "https", hasDefaultPort(url),
              ["github.com", "www.github.com"].contains(url.host?.lowercased() ?? "") else { return nil }
        return .web
    }

    static func trustedDestination(_ text: String) -> TrustedDestination? {
        guard let url = webURL(text), hasDefaultPort(url), let host = url.host?.lowercased() else { return nil }
        switch host {
        case "u.wechat.com": return .wechatScan
        case "weixin.qq.com":
            guard URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath.hasPrefix("/g/") == true,
                  !url.pathComponents.contains(".."), !url.path.contains("\\") else { return nil }
            return .wechatScan
        case "qm.qq.com": return .qq
        case "xhslink.com": return .xiaohongshu
        default: return nil
        }
    }

    static func xiaohongshuProfileID(_ url: URL) -> String? {
        guard let checked = xiaohongshuRedirectURL(url),
              ["xiaohongshu.com", "www.xiaohongshu.com"].contains(checked.host?.lowercased() ?? "") else { return nil }
        let parts = checked.path.split(separator: "/")
        guard parts.count == 3, parts[0] == "user", parts[1] == "profile",
              parts[2].range(of: #"^[0-9a-fA-F]{24}$"#, options: .regularExpression) != nil else { return nil }
        return parts[2].lowercased()
    }

    static func xiaohongshuRedirectURL(_ url: URL) -> URL? {
        guard let checked = webURL(url.absoluteString), hasDefaultPort(checked),
              ["xhslink.com", "xiaohongshu.com", "www.xiaohongshu.com"].contains(checked.host?.lowercased() ?? ""),
              var components = URLComponents(url: checked, resolvingAgainstBaseURL: false) else { return nil }
        components.scheme = "https"
        components.port = nil
        return components.url
    }

    private static func hasDefaultPort(_ url: URL) -> Bool {
        url.port == nil || (url.scheme?.lowercased() == "https" ? url.port == 443 : url.port == 80)
    }

    private static let domains: [(String, [String])] = [
        ("wechat", ["wechat.com", "weixin.qq.com"]),
        ("qq", ["qq.com"]),
        ("whatsapp", ["wa.me", "whatsapp.com"]),
        ("instagram", ["instagram.com", "instagr.am"]),
        ("twitter", ["twitter.com", "x.com"]),
        ("tiktok", ["tiktok.com"]),
        ("snapchat", ["snapchat.com"]),
        ("reddit", ["reddit.com", "redd.it"]),
        ("threads", ["threads.net", "threads.com"]),
        ("linkedin", ["linkedin.com"]),
        ("github", ["github.com"]),
        ("facebook", ["facebook.com", "fb.com", "fb.me"]),
        ("twitch", ["twitch.tv"]),
        ("line", ["line.me", "lin.ee"]),
        ("testflight", ["testflight.apple.com"]),
        ("xiaohongshu", ["xiaohongshu.com", "xhslink.com"]),
        ("bilibili", ["bilibili.com", "b23.tv"]),
        ("douyin", ["douyin.com", "iesdouyin.com"]),
        ("weibo", ["weibo.com", "weibo.cn"]),
    ]

    static func webURL(_ text: String) -> URL? {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.contains(where: { $0.isWhitespace || $0.isNewline }),
              let components = URLComponents(string: raw),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil else { return nil }
        return components.url
    }

    static func platformID(_ text: String) -> String? {
        guard let url = webURL(text), let host = url.host?.lowercased() else { return nil }
        return domains.first { $0.1.contains { host == $0 || host.hasSuffix("." + $0) } }?.0
    }

    static func warningKey(_ text: String, platform: String = "custom") -> String? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let url = webURL(text), let host = url.host?.lowercased() else {
            return platform == "custom" && URLComponents(string: text)?.scheme == nil ? nil : "qrFormatWarning"
        }
        if url.scheme?.lowercased() != "https" || host.contains(":") ||
            host.range(of: #"^[0-9.]+$"#, options: .regularExpression) != nil { return "qrDestinationWarning" }
        if platform != "custom" && platformID(text) != platform { return "qrFormatWarning" }
        if platform == "qq" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let shortLink = url.path.hasPrefix("/q/") && url.path.count > 3
            let legacyLink = url.path == "/cgi-bin/qm/qr" &&
                components?.queryItems?.contains(where: { $0.name == "k" && !($0.value ?? "").isEmpty }) == true
            if host != "qm.qq.com" || !(shortLink || legacyLink) { return "qrFormatWarning" }
        }
        return nil
    }
}
