"""Native SwiftData migration and backup round-trip for local glass settings."""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "QRID/QRID"

class GlassStrengthTests(unittest.TestCase):
    def test_native_migration_and_backup(self):
        model = (SOURCE / "Models/QRCluster.swift").read_text()
        catalog = (SOURCE / "Helpers/RemoteTagCatalog.swift").read_text()
        keys = sorted(set(re.findall(r"L\.(\w+)", model + catalog)))
        fixtures = r"""
import Foundation
import SwiftData
import SwiftUI
extension Color { init(hex: String) { self = .black } }
enum AppLanguage: Sendable { case system, zhHans, zhHantHK, zhHantTW, en, ja
    static func preferredSystemLanguage() -> Self { .zhHans }
}
enum AppSettings { static let shared = Settings()
    final class Settings { var resolvedLanguage: AppLanguage = .zhHans }
}
@Model final class QRProfile {
    var cluster: QRCluster?
    var platformType: String
    var qrContent: String
    var foregroundColorHex: String
    var customPlatformName: String?
    init(platformType: String = "qq", qrContent: String = "fixture", foregroundColorHex: String = "#000000", customPlatformName: String? = nil) {
        self.platformType = platformType; self.qrContent = qrContent
        self.foregroundColorHex = foregroundColorHex; self.customPlatformName = customPlatformName
    }
    func attach(to cluster: QRCluster, in context: ModelContext) { context.insert(self); self.cluster = cluster }
}
enum WidgetDataHelper { static func sync(clusters: [QRCluster]) {} }
"""
        fixtures += "enum L {\n" + "\n".join(f'static let {key} = "{key}"' for key in keys) + "\n}\n"
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            fixture = folder / "Fixtures.swift"
            fixture.write_text(fixtures)
            # Compile the actual model with only the new optional field removed to seed the previous schema.
            old = model.replace("    var cardGlassStrength: Double?\n", "").replace("        cardGlassStrength: Double? = nil,\n", "").replace("        self.cardGlassStrength = cardGlassStrength\n", "")
            old = re.sub(r"    // Older cards.*?    var backgroundColor: Color", "    var backgroundColor: Color", old, flags=re.S)
            legacy = folder / "QRCluster.swift"
            legacy.write_text(old)
            writer = folder / "Writer.swift"
            writer.write_text(r'''
import Foundation
import SwiftData
@main struct Writer {
    @MainActor static func main() throws {
        let store = URL(fileURLWithPath: CommandLine.arguments[1])
        let container = try ModelContainer(for: QRCluster.self, QRProfile.self, configurations: ModelConfiguration(url: store))
        let c = QRCluster(name: "Legacy glass", cardOpacity: 0.7, cardGlassEnabled: true)
        container.mainContext.insert(c)
        QRProfile().attach(to: c, in: container.mainContext)
        try container.mainContext.save()
    }
}
''')
            shared = [str(fixture), str(SOURCE / "Helpers/RemoteTagCatalog.swift"), str(SOURCE / "Helpers/CardTagReference.swift")]
            store = folder / "legacy.store"
            subprocess.run(["swiftc", *shared, str(legacy), str(writer), "-o", str(folder / "writer")], check=True)
            subprocess.run([str(folder / "writer"), str(store)], check=True)
            # Redirect backup documents into the disposable test directory; backup logic remains production code.
            backup = (SOURCE / "Helpers/BackupManager.swift").read_text().replace("FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first", "Optional(URL(fileURLWithPath: CommandLine.arguments[2]))")
            (folder / "BackupManager.swift").write_text(backup)
            subprocess.run(["swiftc", *shared, str(SOURCE / "Models/QRCluster.swift"), str(folder / "BackupManager.swift"), str(ROOT / "Tests/GlassStrengthTests.swift"), "-o", str(folder / "tests")], check=True)
            subprocess.run([str(folder / "tests"), str(store), str(folder)], check=True)
