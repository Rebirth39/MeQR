import pathlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]


class ActivityReportingTests(unittest.TestCase):
    def test_production_reporting_state(self):
        with tempfile.TemporaryDirectory() as directory:
            binary = pathlib.Path(directory) / 'activity-tests'
            subprocess.run(['swiftc', '-parse-as-library',
                            str(ROOT / 'QRID/QRID/Helpers/ActivityReporting.swift'),
                            str(ROOT / 'Tests/ActivityReportingTests.swift'), '-o', str(binary)], check=True)
            subprocess.run([str(binary)], check=True)


if __name__ == '__main__':
    unittest.main()
