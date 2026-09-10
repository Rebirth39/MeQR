"""Run focused production Swift regressions without xcodebuild or a device."""
import os
import pathlib
import re
import subprocess
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "QRID/QRID"
ARTIFACTS = pathlib.Path("/Users/lucasli/Documents/TestsScreenshot/bug-audit-20260909")


class TagAuditTests(unittest.TestCase):
    def test_production_tag_regressions(self):
        ARTIFACTS.mkdir(parents=True, exist_ok=True)
        model = (SOURCE / "Models/QRCluster.swift").read_text()
        outbox = (SOURCE / "Helpers/CardTagOutbox.swift").read_text().split("struct CardTagOutboxView:")[0]
        client = "enum CardTagReportClient {" + (SOURCE / "Views/CardTagReportView.swift").read_text().split("enum CardTagReportClient {")[1]
        backup = (SOURCE / "Helpers/BackupManager.swift").read_text().split("    // MARK: - Export")[0] + "}\n"
        catalog = (SOURCE / "Helpers/RemoteTagCatalog.swift").read_text()
        keys = sorted(set(re.findall(r"L\.(\w+)", model + outbox + client + catalog)))
        fixtures = '''
import SwiftData
import SwiftUI
enum AppLanguage: Sendable { case system, zhHans, zhHantHK, zhHantTW, en, ja
    static func preferredSystemLanguage() -> Self { .en }
}
enum AppSettings { static let shared = Settings()
    final class Settings { var resolvedLanguage: AppLanguage = .en }
}
extension Color { init(hex: String) { self = .black } }
@Model final class QRProfile {
    var cluster: QRCluster?
    var platformType = "custom"
    var qrContent = "fixture"
    var foregroundColorHex = "#000000"
    var customPlatformName: String?
    init() {}
}
extension BackupManager {
    static func auditSnapshot(_ cluster: QRCluster) -> ClusterBackup { makeClusterBackup(cluster) }
}
'''
        fixtures += "enum L {\n" + "\n".join(f'static let {key} = "{key}"' for key in keys) + "\n}\n"
        generated = ARTIFACTS / "TagAuditProduction.swift"
        generated.write_text(outbox + client + backup + fixtures)
        binary = ARTIFACTS / "tag-audit-tests"
        compile_result = subprocess.run([
            "swiftc", "-module-cache-path", str(ARTIFACTS / "module-cache"),
            str(generated), str(SOURCE / "Models/QRCluster.swift"),
            str(SOURCE / "Helpers/RemoteTagCatalog.swift"),
            str(SOURCE / "Helpers/CardTagReference.swift"),
            str(ROOT / "Tests/TagAudit20260909Tests.swift"), "-o", str(binary),
        ], capture_output=True, text=True)
        (ARTIFACTS / "tag-audit-compile.log").write_text(compile_result.stdout + compile_result.stderr)
        self.assertEqual(compile_result.returncode, 0, compile_result.stderr)
        result = subprocess.run([str(binary), str(ARTIFACTS)], capture_output=True, text=True,
                                env={**os.environ, "TMPDIR": str(ARTIFACTS)})
        (ARTIFACTS / "tag-audit-results.log").write_text(result.stdout + result.stderr)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
