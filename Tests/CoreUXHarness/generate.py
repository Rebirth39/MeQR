"""Generate an isolated native app from the current production views."""
from pathlib import Path
import argparse
import re
import shutil

parser = argparse.ArgumentParser()
parser.add_argument("output", type=Path)
args = parser.parse_args()
harness = Path(__file__).resolve().parent
source = harness.parents[1] / "QRID/QRID"
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=True)
project = (harness / "project.pbxproj.template").read_text()
for relative in re.findall(r'path = "(Sources/[^"\n]+\.swift)"', project):
    name = Path(relative).name
    matches = list(source.rglob(name))
    assert len(matches) == 1, (name, matches)
    content = matches[0].read_text()
    if name == "QRIDApp.swift":
        # Replace only the app entry point; retain AppRootView and all support types.
        content = content[:content.index("@main")] + content[content.index("private struct ModelContainerBootstrap"):]
    content = content.replace('"group.com.lucasli.meqr"', '"group.com.lucasli.meqr.coreuxregression"')
    target = output / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content)
for name in ("Host.swift", "LayoutTests.swift", "CoreUXHost.entitlements"):
    shutil.copyfile(harness / name, output / name)
shutil.copyfile(source / "tags-v1.json", output / "tags-v1.json")
shutil.copyfile("/Users/lucasli/Documents/debug/BG.jpg", output / "BG.jpg")
project_dir = output / "CoreUX.xcodeproj"
scheme_dir = project_dir / "xcshareddata/xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
(project_dir / "project.pbxproj").write_text(project)
shutil.copyfile(harness / "CoreUXHost.xcscheme", scheme_dir / "CoreUXHost.xcscheme")
print(output)
