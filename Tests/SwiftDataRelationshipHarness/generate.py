"""Generate an isolated app using production models, persistence, and UI."""
from pathlib import Path
import subprocess, sys, shutil
here = Path(__file__).resolve().parent
out = Path(sys.argv[1]).resolve()
subprocess.run([sys.executable, str(here.parent/'CoreUXHarness/generate.py'), str(out)], check=True)
for name in ['Host.swift', 'LayoutTests.swift']:
    shutil.copyfile(here/name, out/name)
for name in ['CoreUX.xcodeproj/project.pbxproj', 'CoreUXHost.entitlements', 'Sources/WidgetDataHelper.swift']:
    f = out/name
    f.write_text(f.read_text().replace('com.lucasli.meqr.coreuxregression', 'com.lucasli.meqr.relationshipregression'))
