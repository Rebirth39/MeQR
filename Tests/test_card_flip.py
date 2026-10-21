from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class CardFlipTests(unittest.TestCase):
    def test_original_perspective_fits_reserved_space(self):
        source = (ROOT / "QRID/QRID/Views/ClusterCardView.swift").read_text()
        effect = source[source.index("private struct PassFlipLayout:"):]
        checks = r"""
import SwiftUI

EFFECT_SOURCE

for size in [CGSize(width: 288, height: 560), CGSize(width: 352, height: 720),
             CGSize(width: 508, height: 780), CGSize(width: 588, height: 900),
             CGSize(width: 620, height: 320)] {
    for step in 0...720 {
        let angle = Double(step) / 4
        let radians = angle * .pi / 180
        let scale = 1 - 0.055 * abs(sin(radians))
        let overflow = PassFlipLayout(angle: angle).verticalOverflow(height: size.height)
        let centerY = size.height / 2 + overflow
        let cameraDistance = size.width / 0.72
        for horizontal in [-0.5, 0.5] {
            let depth = size.width * horizontal * scale * sin(radians)
            for vertical in [-0.5, 0.5] {
                let projectedY = centerY + size.height * vertical * scale / (1 - depth / cameraDistance)
                assert(projectedY >= -0.001 && projectedY <= size.height + 2 * overflow + 0.001,
                       "Original perspective exceeds envelope at \(angle): \(projectedY)")
            }
        }
        if step == 0 || step == 720 { assert(overflow < 0.001) }
        if step == 360 { assert(overflow > 0, "Original flip must be allowed to grow taller") }
    }
}
print("PASS: original perspective fits reserved vertical space at 3,605 size/angle combinations")
"""
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "CardFlip.swift"
            fixture.write_text(checks.replace("EFFECT_SOURCE", effect))
            subprocess.run(["swift", str(fixture)], check=True)
