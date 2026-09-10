import Foundation

@main struct QRLinkPolicyTests {
    static func main() {
        let invalid = ["javascript:alert(1)", "intent://scan", "weixin://scanqrcode",
                       "https://qq.com@evil.test", "https://", "https://qq.com/a b"]
        for text in invalid { precondition(QRLinkPolicy.webURL(text) == nil, text) }
        for text in ["https://qm.qq.com.evil.test/q/abc", "https://evil.test/?qq.com", "https://notx.com"] {
            precondition(QRLinkPolicy.platformID(text) == nil, text)
        }
        precondition(QRLinkPolicy.platformID("HTTPS://QM.QQ.COM/q/abc") == "qq")
        precondition(QRLinkPolicy.platformID("https://u.wechat.com/abc") == "wechat")
        precondition(QRLinkPolicy.platformID("https://weixin.qq.com/abc") == "wechat")
        precondition(QRLinkPolicy.platformID("https://testflight.apple.com/join/abc") == "testflight")
        for text in ["https://qm.qq.com/q/abc", "https://qm.qq.com/cgi-bin/qm/qr?k=abc"] {
            precondition(QRLinkPolicy.warningKey(text, platform: "qq") == nil)
        }
        for text in ["123456", "https://qq.com", "https://qm.qq.com/q/", "https://qm.qq.com/cgi-bin/qm/qr?k="] {
            precondition(QRLinkPolicy.warningKey(text, platform: "qq") == "qrFormatWarning", text)
        }
        precondition(QRLinkPolicy.warningKey("plain custom text") == nil)
        precondition(QRLinkPolicy.warningKey("https://example.com", platform: "wechat") == "qrFormatWarning")
        for text in ["http://example.com", "https://127.0.0.1", "https://[::1]"] {
            precondition(QRLinkPolicy.warningKey(text) == "qrDestinationWarning", text)
        }
        for text in ["https://u.wechat.com/abc", "http://u.wechat.com/abc", "https://weixin.qq.com/g/abc", "HTTPS://U.WECHAT.COM/abc"] {
            precondition(QRLinkPolicy.trustedDestination(text) == .wechatScan, text)
        }
        for text in ["https://qm.qq.com/q/abc", "http://qm.qq.com/cgi-bin/qm/qr?k=abc"] {
            precondition(QRLinkPolicy.trustedDestination(text) == .qq, text)
        }
        precondition(QRLinkPolicy.trustedDestination("https://xhslink.com/m/AbCd") == .xiaohongshu)
        for text in ["https://github.com/lucas", "https://www.github.com/lucas?tab=repositories"] {
            precondition(QRLinkPolicy.platformDestination(text) == .web)
            precondition(QRLinkPolicy.trustedDestination(text) == nil, "GitHub requires an explicit platform-button tap")
        }
        for text in ["https://github.com.evil.test/lucas", "https://github.com@evil.test/lucas", "http://github.com/lucas", "https://github.com:8443/lucas", "https://evil.test/?github.com"] {
            precondition(QRLinkPolicy.platformDestination(text) == nil, text)
        }
        precondition(QRLinkPolicy.platformDestination("https://u.wechat.com/abc") == .wechatScan)
        precondition(QRLinkPolicy.platformDestination("https://qm.qq.com/q/abc") == .qq)
        for text in ["https://u.wechat.com.evil.test/abc", "https://fake.u.wechat.com/abc", "https://weixin.qq.com/other", "https://weixin.qq.com/g/../other", "https://weixin.qq.com/g/%2e%2e/other", "https://weixin.qq.com/g%2fabc", "https://weixin.qq.com/good", "https://qm.qq.com@evil.test/q/abc", "https://evil.test/?url=https://qm.qq.com", "https://qm.qq.com:8443/q/abc", "https://xhslink.com.evil.test/abc", "https://www.xhslink.com/abc", "https://xiaohongshu.com/user/profile/abcdef0123456789abcdef01", "weixin://scanqrcode"] {
            precondition(QRLinkPolicy.trustedDestination(text) == nil, text)
        }
        let profile = URL(string: "https://www.xiaohongshu.com/user/profile/ABCDEF0123456789ABCDEF01?source=qrcode")!
        precondition(QRLinkPolicy.xiaohongshuProfileID(profile) == "abcdef0123456789abcdef01")
        for text in ["https://evil.test/user/profile/abcdef0123456789abcdef01", "https://xiaohongshu.com.evil.test/user/profile/abcdef0123456789abcdef01", "https://www.xiaohongshu.com/explore/abcdef0123456789abcdef01", "https://xhslink.com/?id=abcdef0123456789abcdef01"] {
            precondition(QRLinkPolicy.xiaohongshuProfileID(URL(string: text)!) == nil, text)
        }
        precondition(QRLinkPolicy.xiaohongshuRedirectURL(URL(string: "http://xhslink.com:80/m/AbCd")!)?.absoluteString == "https://xhslink.com/m/AbCd")
        for text in ["https://evil.test/", "https://xhslink.com:8080/", "https://user@xhslink.com/", "file:///tmp/test"] {
            precondition(QRLinkPolicy.xiaohongshuRedirectURL(URL(string: text)!) == nil, text)
        }
        print("QRLinkPolicy: existing URL warnings, exact allowlist, paths, ports and RED redirect validation passed")
    }
}
