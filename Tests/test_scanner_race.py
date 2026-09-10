"""Run the scanner's production async methods with manually resumed dependencies.

No camera, network, shared harness, or signed app build is needed. SwiftUI State
is replaced by reference-backed storage; lifecycle wiring is checked separately.
"""

import pathlib
import re
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "QRID/QRID/Views/MeQRScannerView.swift"


def declaration(source, name):
    match = re.search(r"    (?:private )?(?:static )?(?:func|var) " + name + r"\b", source)
    if match is None:
        raise AssertionError(f"Missing scanner declaration: {name}")
    start = source.index("{", match.start())
    depth = 1
    end = start + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[match.start():end].replace("private ", "", 1)


FIXTURES = r'''
import Foundation

@propertyWrapper
struct State<Value> {
    final class Storage {
        var value: Value
        init(_ value: Value) { self.value = value }
    }
    private let storage: Storage
    init(wrappedValue: Value) { storage = Storage(wrappedValue) }
    var wrappedValue: Value {
        get { storage.value }
        nonmutating set { storage.value = newValue }
    }
}
extension State where Value: ExpressibleByNilLiteral {
    init() { self.init(wrappedValue: nil) }
}

struct UIImage: Sendable { let key: String }
struct MeQRExchangeProfile: Sendable {
    let name: String
    var avatarJPEGBase64: String?
}
struct Session: Sendable {
    let sessionID: String
    let creatorProfile: MeQRExchangeProfile?
}
enum Failure: Error { case failed }
enum MeQRRemoteServiceError: Error { case server(String) }
enum L {
    static let notMeQRProfileCode = "notMeQRProfileCode"
    static let qrAppOpenFailed = "qrAppOpenFailed"
    static let wechatNotInstalled = "wechatNotInstalled"
}

@MainActor final class UIApplication {
    enum OpenOption: Hashable { case universalLinksOnly }
    static let shared = UIApplication()
    var requests: [(URL, Bool)] = []
    var succeeds = true
    func open(_ url: URL, options: [OpenOption: Bool] = [:]) async -> Bool {
        requests.append((url, options[.universalLinksOnly] == true))
        return succeeds
    }
}

// Continuations deliberately ignore task cancellation, just as an expensive
// decode or already-completed network request can do.
@MainActor
final class Deferred<Value: Sendable> {
    var continuation: CheckedContinuation<Value, Error>?
    var calls = 0
    func get() async throws -> Value {
        calls += 1
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func succeed(_ value: Value) { continuation!.resume(returning: value); continuation = nil }
    func fail() { continuation!.resume(throwing: Failure.failed); continuation = nil }
}

@MainActor
enum Photos {
    static var loads: [String: Deferred<Data?>] = [:]
    static func load(_ key: String) -> Deferred<Data?> {
        if let value = loads[key] { return value }
        let value = Deferred<Data?>(); loads[key] = value; return value
    }
}
struct PhotosPickerItem {
    let key: String
    @MainActor func loadTransferable(type: Data.Type) async throws -> Data? {
        try await Photos.load(key).get()
    }
}

@MainActor
enum QRCodeGenerator {
    enum QRDecodeError: Error { case invalidImage }
    struct DecodedCode: Sendable { let payload: String; let colorAvatarJPEG: Data? }
    static var decodes: [String: Deferred<DecodedCode>] = [:]
    static func decode(_ key: String) -> Deferred<DecodedCode> {
        if let value = decodes[key] { return value }
        let value = Deferred<DecodedCode>(); decodes[key] = value; return value
    }
    static func imageForDecoding(from data: Data) -> UIImage? {
        UIImage(key: String(decoding: data, as: UTF8.self))
    }
    static func decodeEnhanced(from image: UIImage) async throws -> DecodedCode {
        try await decode(image.key).get()
    }
}

enum MeQRExchangeCodec {
    static func decode(_ payload: String) throws -> MeQRExchangeProfile {
        guard payload.hasPrefix("local:") else { throw Failure.failed }
        return MeQRExchangeProfile(name: payload)
    }
    static func offlineFallback(from payload: String) -> MeQRExchangeProfile? {
        payload.contains("#offline") ? MeQRExchangeProfile(name: "fallback") : nil
    }
}

@MainActor
enum MeQRRemoteService {
    static var sessions: [String: Deferred<Session>] = [:]
    static var profiles: [String: Deferred<MeQRExchangeProfile>] = [:]
    static func session(_ key: String) -> Deferred<Session> {
        if let value = sessions[key] { return value }
        let value = Deferred<Session>(); sessions[key] = value; return value
    }
    static func profile(_ key: String) -> Deferred<MeQRExchangeProfile> {
        if let value = profiles[key] { return value }
        let value = Deferred<MeQRExchangeProfile>(); profiles[key] = value; return value
    }
    static func canFetchEncounterSession(from payload: String) -> Bool { payload.hasPrefix("session:") }
    static func encounterSessionID(from payload: String) -> String? {
        canFetchEncounterSession(from: payload) ? String(payload.dropFirst(8).split(separator: "#")[0]) : nil
    }
    static func canFetchProfile(from payload: String) -> Bool { payload.hasPrefix("profile:") }
    static func fetchEncounterSession(from payload: String) async throws -> Session { try await session(payload).get() }
    static func fetchProfile(from payload: String) async throws -> MeQRExchangeProfile { try await profile(payload).get() }
}
'''


CASES = r'''
@main
struct ScannerRaceTests {
    @MainActor static func waitFor(_ condition: () -> Bool) async {
        for _ in 0..<10000 {
            if condition() { return }
            await Task.yield()
        }
        fatalError("Expected suspension point was not reached")
    }
    @MainActor static func scanner() -> Scanner {
        let value = Scanner(); value.isScannerActive = true; return value
    }
    @MainActor static func main() async {
        // Back-to-back callbacks reserve the slot before either Task runs.
        let first = scanner()
        first.handlePayload("local:first", frame: UIImage(key: "first"))
        let firstTask = first.decodeTask!
        first.handlePayload("local:second", frame: UIImage(key: "second"))
        await waitFor { QRCodeGenerator.decode("first").continuation != nil }
        precondition(QRCodeGenerator.decode("second").calls == 0)
        QRCodeGenerator.decode("first").succeed(.init(payload: "local:first", colorAvatarJPEG: Data([1, 2])))
        await firstTask.value
        precondition(first.decodedScan?.profile.name == "local:first" && first.decodeTask == nil)
        precondition(first.decodedScan?.profile.avatarJPEGBase64 == Data([1, 2]).base64EncodedString())
        print("PASS synchronous camera gating and avatar decode")

        // Explicit photo intent cancels camera work and blocks further frames.
        let photo = scanner()
        photo.handlePayload("session:old", frame: nil)
        let oldSessionTask = photo.decodeTask!
        await waitFor { MeQRRemoteService.session("session:old").continuation != nil }
        photo.cancelDecode(); photo.showingPhotoPicker = true
        photo.handlePayload("local:blocked", frame: nil)
        precondition(photo.decodeTask == nil)
        photo.handlePhoto(.init(key: "photo"))
        let photoTask = photo.decodeTask!
        photo.showingPhotoPicker = false
        await waitFor { Photos.load("photo").continuation != nil }
        MeQRRemoteService.session("session:old").succeed(.init(sessionID: "old", creatorProfile: .init(name: "old")))
        await oldSessionTask.value
        precondition(photo.decodeTask != nil && photo.decodedScan == nil)
        photo.handlePayload("local:blocked-again", frame: nil)
        Photos.load("photo").succeed(Data("photo-image".utf8))
        await waitFor { QRCodeGenerator.decode("photo-image").continuation != nil }
        QRCodeGenerator.decode("photo-image").succeed(.init(payload: "local:photo", colorAvatarJPEG: nil))
        await photoTask.value
        precondition(photo.decodedScan?.profile.name == "local:photo" && photo.decodedScan?.sessionID == nil)
        print("PASS photo priority, late session discard, replacement slot retained")

        // An old profile response must not overwrite an already-presented session.
        let visible = scanner()
        visible.handlePayload("profile:stale-success", frame: nil)
        let staleTask = visible.decodeTask!
        await waitFor { MeQRRemoteService.profile("profile:stale-success").continuation != nil }
        visible.handlePhoto(.init(key: "session-photo")); let visibleTask = visible.decodeTask!
        await waitFor { Photos.load("session-photo").continuation != nil }
        Photos.load("session-photo").succeed(Data("session-photo-image".utf8))
        await waitFor { QRCodeGenerator.decode("session-photo-image").continuation != nil }
        QRCodeGenerator.decode("session-photo-image").succeed(.init(payload: "session:photo", colorAvatarJPEG: nil))
        await waitFor { MeQRRemoteService.session("session:photo").continuation != nil }
        MeQRRemoteService.session("session:photo").succeed(.init(sessionID: "photo-id", creatorProfile: .init(name: "photo-creator")))
        await visibleTask.value
        MeQRRemoteService.profile("profile:stale-success").succeed(.init(name: "stale"))
        await staleTask.value
        precondition(visible.decodedScan?.profile.name == "photo-creator" && visible.decodedScan?.sessionID == "photo-id")
        print("PASS visible preview and session pair survive late profile success")

        // A superseded photo load can fail without showing an error or freeing the slot.
        let latest = scanner()
        latest.handlePhoto(.init(key: "old-photo")); let oldPhotoTask = latest.decodeTask!
        await waitFor { Photos.load("old-photo").continuation != nil }
        latest.handlePhoto(.init(key: "new-photo")); let newPhotoTask = latest.decodeTask!
        await waitFor { Photos.load("new-photo").continuation != nil }
        Photos.load("old-photo").fail(); await oldPhotoTask.value
        precondition(!latest.showError && latest.decodeTask != nil)
        Photos.load("new-photo").succeed(Data("new-photo-image".utf8))
        await waitFor { QRCodeGenerator.decode("new-photo-image").continuation != nil }
        QRCodeGenerator.decode("new-photo-image").succeed(.init(payload: "local:new-photo", colorAvatarJPEG: nil))
        await newPhotoTask.value
        precondition(latest.decodedScan?.profile.name == "local:new-photo")
        print("PASS latest photo wins and canceled load errors stay silent")

        // Leave at each async stage; success/error must not publish stale state.
        for kind in ["color", "session", "profile", "load", "photo-color"] {
            let view = scanner()
            let key = "dismiss-" + kind
            switch kind {
            case "color": view.handlePayload("local:dismiss", frame: UIImage(key: key))
            case "session": view.handlePayload("session:" + key + "#offline", frame: nil)
            case "profile": view.handlePayload("profile:" + key + "#offline", frame: nil)
            default: view.handlePhoto(.init(key: key))
            }
            let task = view.decodeTask!
            switch kind {
            case "color": await waitFor { QRCodeGenerator.decode(key).continuation != nil }
            case "session": await waitFor { MeQRRemoteService.session("session:" + key + "#offline").continuation != nil }
            case "profile": await waitFor { MeQRRemoteService.profile("profile:" + key + "#offline").continuation != nil }
            default:
                await waitFor { Photos.load(key).continuation != nil }
                if kind == "photo-color" {
                    Photos.load(key).succeed(Data(key.utf8))
                    await waitFor { QRCodeGenerator.decode(key).continuation != nil }
                }
            }
            view.isScannerActive = false; view.cancelDecode()
            switch kind {
            case "color", "photo-color": QRCodeGenerator.decode(key).succeed(.init(payload: "local:stale", colorAvatarJPEG: nil))
            case "session": MeQRRemoteService.session("session:" + key + "#offline").fail()
            case "profile": MeQRRemoteService.profile("profile:" + key + "#offline").fail()
            default: Photos.load(key).succeed(nil)
            }
            await task.value
            precondition(view.decodedScan == nil && view.pendingContent == nil)
            precondition(!view.showError && view.errorMessage == nil && view.decodeTask == nil)
            print("PASS dismissal during " + kind)
        }

        // Successful session/profile and ordinary offline/error paths still work.
        let session = scanner()
        session.handlePayload("session:valid", frame: nil); let sessionTask = session.decodeTask!
        await waitFor { MeQRRemoteService.session("session:valid").continuation != nil }
        MeQRRemoteService.session("session:valid").succeed(.init(sessionID: "valid-id", creatorProfile: .init(name: "creator")))
        await sessionTask.value
        precondition(session.decodedScan?.sessionID == "valid-id" && session.decodedScan?.profile.name == "creator")
        for kind in ["session", "profile"] {
            let fallback = scanner()
            let payload = kind + ":fallback#offline"
            fallback.handlePayload(payload, frame: nil); let task = fallback.decodeTask!
            if kind == "session" {
                await waitFor { MeQRRemoteService.session(payload).continuation != nil }
                MeQRRemoteService.session(payload).fail()
            } else {
                await waitFor { MeQRRemoteService.profile(payload).continuation != nil }
                MeQRRemoteService.profile(payload).fail()
            }
            await task.value
            precondition(fallback.decodedScan?.profile.name == "fallback" && !fallback.showError && fallback.decodedScan?.localProfile?.name == "short")
            precondition(fallback.decodedScan?.sessionID == (kind == "session" ? "fallback" : nil))
        }
        let remote = scanner()
        remote.handlePayload("profile:valid", frame: nil); let remoteTask = remote.decodeTask!
        await waitFor { MeQRRemoteService.profile("profile:valid").continuation != nil }
        MeQRRemoteService.profile("profile:valid").succeed(.init(name: "remote"))
        await remoteTask.value
        precondition(remote.decodedScan?.profile.name == "remote" && remote.decodedScan?.sessionID == nil)
        let failed = scanner()
        failed.handlePayload("profile:failed", frame: nil); let failedTask = failed.decodeTask!
        await waitFor { MeQRRemoteService.profile("profile:failed").continuation != nil }
        MeQRRemoteService.profile("profile:failed").fail(); await failedTask.value
        precondition(failed.showError && failed.errorMessage != nil && failed.decodeTask == nil)
        failed.showError = false
        failed.handlePayload("https://example.com", frame: nil); await failed.decodeTask!.value
        precondition(failed.pendingContent == "https://example.com")
        print("PASS paired session/profile, offline fallbacks, error recovery, generic consent routing")

        for blocked in ["preview", "consent", "my-code", "error", "inactive"] {
            let view = scanner()
            switch blocked {
            case "preview": view.decodedScan = .init(profile: .init(name: "shown"), sessionID: nil, localProfile: nil)
            case "consent": view.pendingContent = "https://example.com"
            case "my-code": view.showingMyCode = true
            case "error": view.showError = true
            default: view.isScannerActive = false
            }
            view.handlePayload("local:blocked", frame: nil)
            view.handlePhoto(.init(key: "blocked"))
            precondition(view.decodeTask == nil)
        }
        print("PASS both input paths respect presentations and inactive scanner")

        for payload in ["https://u.wechat.com/id", "https://weixin.qq.com/g/id", "https://qm.qq.com/q/id"] {
            let view = scanner()
            view.handlePayload(payload, frame: nil)
            await view.decodeTask!.value
            if let task = view.trustedLinkTask { await task.value }
            precondition(view.pendingContent == nil)
        }
        precondition(UIApplication.shared.requests.last?.0.absoluteString == "https://qm.qq.com/q/id")
        let red = scanner()
        red.handlePayload("https://xhslink.com/m/AbCd", frame: nil)
        await red.decodeTask!.value
        await waitFor { Scanner.redirect.continuation != nil }
        let redTask = red.trustedLinkTask!
        red.handlePayload("https://example.com", frame: nil)
        precondition(red.pendingContent == nil && red.decodeTask == nil)
        Scanner.redirect.succeed(URL(string: "https://www.xiaohongshu.com/user/profile/abcdef0123456789abcdef01")!)
        await redTask.value
        precondition(UIApplication.shared.requests.last?.0.absoluteString == "xhsdiscover://user/abcdef0123456789abcdef01")
        precondition(!red.isOpeningTrustedLink && red.pendingContent == nil)
        let cached = scanner()
        cached.handlePayload("https://xhslink.com/m/AbCd", frame: nil)
        await cached.decodeTask!.value
        if let task = cached.trustedLinkTask { await task.value }
        precondition(Scanner.redirect.calls == 1)

        let canceled = scanner()
        canceled.handlePayload("https://xhslink.com/m/Canceled", frame: nil)
        await canceled.decodeTask!.value
        await waitFor { Scanner.redirect.continuation != nil }
        let canceledTask = canceled.trustedLinkTask!
        let count = UIApplication.shared.requests.count
        canceled.isScannerActive = false; canceled.cancelDecode()
        Scanner.redirect.succeed(URL(string: "https://www.xiaohongshu.com/user/profile/abcdef0123456789abcdef01")!)
        await canceledTask.value
        precondition(UIApplication.shared.requests.count == count && !canceled.showError)

        let failedRed = scanner()
        UIApplication.shared.succeeds = false
        failedRed.handlePayload("https://xhslink.com/m/Unresolved", frame: nil)
        await failedRed.decodeTask!.value
        await waitFor { Scanner.redirect.continuation != nil }
        let failedRedTask = failedRed.trustedLinkTask!
        Scanner.redirect.succeed(nil)
        await failedRedTask.value
        precondition(UIApplication.shared.requests.last?.1 == true && failedRed.showError)
        precondition(failedRed.pendingContent == nil)
        print("PASS trusted app routing, RED scheme/cache, no browser fallback, cancellation and single-flight gating")
    }
}
'''


class ScannerRaceTests(unittest.TestCase):
    def test_production_async_paths(self):
        source = SOURCE.read_text()
        state = "\n".join(
            line.replace("private ", "", 1)
            for line in source.splitlines()
            if "@State private var" in line and "cameraAuthorized" not in line
        )
        methods = "\n".join(declaration(source, name) for name in (
            "canPresentScanResult", "cancelDecode", "handlePayload", "handlePhoto",
            "decodePayload", "decodePhoto", "routeGenericQR", "applyingColorAvatar", "presentScan", "openTrustedLink", "openTrustedDestination",
        ))
        result = source[source.index("struct MeQRDecodedScan:"):source.index("@MainActor")]
        reply = '\nfunc localProfile(forOffline: Bool) -> MeQRExchangeProfile? { .init(name: forOffline ? "short" : "full") }\n'
        reply += '''
        static let redirect = Deferred<URL?>()
        static let xiaohongshuUserIDCache = NSCache<NSString, NSString>()
        static func resolveXiaohongshuRedirect(_ url: URL) async -> URL? { try? await redirect.get() }
        static func xiaohongshuUserID(from url: URL) -> String? { QRLinkPolicy.xiaohongshuProfileID(url) }
        func openWeChatScan() { UIApplication.shared.requests.append((URL(string: "weixin://scanqrcode")!, false)) }
        '''
        production = "\n" + result + "\n@MainActor struct Scanner {\n" + state + "\n" + methods + reply + "\n}\n"
        with tempfile.TemporaryDirectory(prefix="scanner-race-") as directory:
            test_source = pathlib.Path(directory) / "ScannerRaceTests.swift"
            binary = pathlib.Path(directory) / "scanner-race-tests"
            policy = (ROOT / "QRID/QRID/Helpers/QRLinkPolicy.swift").read_text()
            test_source.write_text(FIXTURES + policy + production + CASES)
            subprocess.run(["xcrun", "swiftc", "-swift-version", "5", "-parse-as-library",
                            str(test_source), "-o", str(binary)], check=True, timeout=90)
            subprocess.run([str(binary)], check=True, timeout=30)

    def test_lifecycle_and_consent_wiring(self):
        source = SOURCE.read_text()
        self.assertIn("@MainActor\nstruct MeQRScannerView", source)
        self.assertRegex(source, r"\.onDisappear\s*\{\s*isScannerActive = false\s*cancelDecode\(\)")
        self.assertRegex(source, r"Button\(L.cancel\)\s*\{\s*isScannerActive = false\s*cancelDecode\(\)\s*dismiss\(\)")
        self.assertRegex(source, r"cancelDecode\(\)\s*showingMyCode = true")
        self.assertRegex(source, r"cancelDecode\(\)\s*showingPhotoPicker = true")
        self.assertIn(".photosPicker(isPresented: $showingPhotoPicker, selection: $pickedItem, matching: .images)", source)
        self.assertRegex(source, r"\.onChange\(of: pickedItem\)[\s\S]*?pickedItem = nil\s*handlePhoto\(item\)")
        self.assertIn("QRLinkReviewView(content: content) { url in", source)
        self.assertNotIn("UIApplication.shared.open", declaration(source, "routeGenericQR"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
