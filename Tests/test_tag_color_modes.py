import pathlib
import re
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class TagColorModesTests(unittest.TestCase):
    def test_production_palette(self):
        model = (ROOT / "QRID/QRID/Models/QRCluster.swift").read_text()
        palette = model[model.index("enum CardTagLimiter {"): ]
        catalog = (ROOT / "QRID/QRID/Helpers/RemoteTagCatalog.swift").read_text()
        keys = sorted(set(re.findall(r"L\.(\w+)", palette + catalog)))
        fixtures = """
import Foundation
import SwiftUI
enum AppLanguage: Sendable { case system, zhHans, zhHantHK, zhHantTW, en, ja
    static func preferredSystemLanguage() -> Self { .en }
}
enum AppSettings { static let shared = Settings()
    final class Settings { var resolvedLanguage: AppLanguage = .en }
}
"""
        fixtures += ((ROOT / "QRID/QRID") / "Helpers/ColorExtensions.swift").read_text().split("    func toHex()")[0] + "\n}\n"
        fixtures += "enum L {\n" + "\n".join(f'static let {key} = "{key}"' for key in keys) + "\n}\n"
        checks = '''
let tag = "projectsekai"
let colors = ["#112233", "#223344", "#334455", "#445566", "#556677", "#667788"]
assert(CardTagColorPalette.colorStyle(for: tag).segmentHexes.count == 6)
assert(CardTagColorPalette.presetSolidHex(for: tag) == "#00A0E9")
for mode in [CardTagColorOverride.Mode.custom, .solid, .preset] {
    let original = [tag: CardTagColorOverride(mode: mode, hexes: colors)]
    let raw = CardTagColorPalette.rawValue(from: original, tags: [tag])!
    let restored = CardTagColorPalette.overrides(from: raw)
    assert(restored[tag]!.mode == mode)
    assert(CardTagColorPalette.customHexes(for: tag, overrides: restored) == Array(colors.prefix(5)))
    let rendered = CardTagColorPalette.colorStyle(for: tag, overrides: restored).segmentHexes
    assert(rendered.count == (mode == .custom ? 5 : mode == .solid ? 1 : 6))
    if mode == .custom { assert(rendered == Array(colors.prefix(5))) }
    if mode == .solid { assert(rendered == ["#00A0E9"]) }
}
let legacy = CardTagColorPalette.overrides(from: "{\\"projectsekai\\":\\"#123456\\"}")
assert(CardTagColorPalette.colorStyle(for: tag, overrides: legacy).segmentHexes == ["#123456"])
assert(CardTagColorPalette.rawValue(from: legacy, tags: []) == nil)
assert(CardTagColorPalette.presetMode(for: "unknown", overrides: [:]) == .solid)
print("Tag color modes passed")
assert(CardTagColorPalette.textWeight(for: tag, overrides: legacy) == .regular)
assert(CardTagTextWeight.regular.next == .medium)
assert(CardTagTextWeight.medium.next == .bold)
assert(CardTagTextWeight.bold.next == .regular)
assert(CardTagTextWeight.regular.fontWeight == .regular)
assert(CardTagTextWeight.medium.fontWeight == .semibold)
assert(CardTagTextWeight.bold.fontWeight == .heavy)
for mode in [CardTagColorOverride.Mode.custom, .solid, .preset] {
    for weight in CardTagTextWeight.allCases {
        let original = [tag: CardTagColorOverride(mode: mode, hexes: colors, textWeight: weight)]
        let raw = CardTagColorPalette.rawValue(from: original, tags: [tag])!
        let restored = CardTagColorPalette.overrides(from: raw)
        assert(CardTagColorPalette.textWeight(for: tag, overrides: restored) == weight)
        assert(restored[tag]!.mode == mode)
        assert(restored[tag]!.hexes.count == 5)
    }
}
let weightOnly = [tag: CardTagColorOverride(mode: .preset, hexes: [], textWeight: .bold)]
let restoredWeight = CardTagColorPalette.overrides(from: CardTagColorPalette.rawValue(from: weightOnly, tags: [tag]))
assert(CardTagColorPalette.textWeight(for: tag, overrides: restoredWeight) == .bold)
assert(CardTagColorPalette.colorStyle(for: tag, overrides: restoredWeight).segmentHexes.count == 6)
'''
        with tempfile.TemporaryDirectory() as folder:
            source = pathlib.Path(folder) / "main.swift"
            source.write_text(fixtures + palette + checks)
            binary = pathlib.Path(folder) / "palette-tests"
            subprocess.run(["swiftc", str(source), str(ROOT / "QRID/QRID/Helpers/RemoteTagCatalog.swift"),
                            str(ROOT / "QRID/QRID/Helpers/CardTagReference.swift"), "-o", str(binary)], check=True)
            subprocess.run([str(binary)], check=True)
