import pathlib
import re
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "QRID/QRID"


class TagPairTests(unittest.TestCase):
    def test_production_pair_state(self):
        model = (SOURCE / "Models/QRCluster.swift").read_text()
        catalog = (SOURCE / "Helpers/RemoteTagCatalog.swift").read_text()
        sync = (SOURCE / "Helpers/ProfileSync.swift").read_text().split("struct SyncSnapshot:")[0]
        sync = sync[sync.index("struct SyncDocument:"):]
        keys = sorted(set(re.findall(r"L\.(\w+)", model + catalog)))
        fixtures = '''
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
@Model final class QRProfile { var cluster: QRCluster?; init() {} }
'''
        fixtures += "enum L {\n" + "\n".join(f'static let {key} = "{key}"' for key in keys) + "\n}\n"
        with tempfile.TemporaryDirectory() as directory:
            folder = pathlib.Path(directory)
            generated = folder / "Fixtures.swift"
            generated.write_text(fixtures + sync)
            binary = folder / "tag-pair-tests"
            subprocess.run(["swiftc", str(generated), str(SOURCE / "Models/QRCluster.swift"),
                            str(SOURCE / "Helpers/RemoteTagCatalog.swift"), str(SOURCE / "Helpers/CardTagReference.swift"),
                            str(ROOT / "Tests/TagPairTests.swift"),
                            "-o", str(binary)], check=True)
            subprocess.run([str(binary), str(SOURCE / "tags-v1.json"), str(folder)], check=True)
