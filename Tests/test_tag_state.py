import pathlib
import re
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "QRID/QRID"


class TagStateTests(unittest.TestCase):
    def test_production_state(self):
        model = (SOURCE / "Models/QRCluster.swift").read_text()
        outbox = (SOURCE / "Helpers/CardTagOutbox.swift").read_text().split("struct CardTagOutboxView:")[0]
        client = (SOURCE / "Views/CardTagReportView.swift").read_text().split("enum CardTagReportClient {")[1]
        real = "import Foundation\nimport SwiftUI\n" + model[model.index("enum CardTagLimiter {"):]
        real += "\n" + outbox + "\nenum CardTagReportClient {" + client
        catalog = (SOURCE / "Helpers/RemoteTagCatalog.swift").read_text()
        keys = sorted(set(re.findall(r"L\.(\w+)", real + catalog)))
        fixtures = '''
enum AppLanguage: Sendable { case system, zhHans, zhHantHK, zhHantTW, en, ja
    static func preferredSystemLanguage() -> Self { .en }
}
enum AppSettings { static let shared = Settings()
    final class Settings { var resolvedLanguage: AppLanguage = .en }
}
'''
        fixtures += "enum L {\n" + "\n".join(f'static let {key} = "{key}"' for key in keys) + "\n}\n"
        with tempfile.TemporaryDirectory() as folder:
            path = pathlib.Path(folder)
            generated = path / "Production.swift"
            generated.write_text(real + fixtures)
            binary = path / "tag-state-tests"
            subprocess.run(["swiftc", str(generated), str(SOURCE / "Helpers/RemoteTagCatalog.swift"),
                            str(SOURCE / "Helpers/CardTagReference.swift"), str(ROOT / "Tests/TagStateTests.swift"),
                            "-o", str(binary)], check=True)
            subprocess.run([str(binary), str(SOURCE / "tags-v1.json")], check=True)
