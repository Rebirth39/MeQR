"""Build the current production-source window regression fixture in a temporary directory."""
from pathlib import Path
import argparse
import shutil
import subprocess
import sys

parser = argparse.ArgumentParser()
parser.add_argument("output", type=Path)
args = parser.parse_args()
harness = Path(__file__).resolve().parent
output = args.output.resolve()
subprocess.run([sys.executable, str(harness.parent / "CoreUXHarness/generate.py"), str(output)], check=True)
for name in ("Host.swift", "LayoutTests.swift"):
    shutil.copyfile(harness / name, output / name)
