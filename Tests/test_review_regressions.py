import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def extract_computed_property_body(source: str, property_name: str) -> str:
    pattern = (
        r"^\s*(?:private\s+|fileprivate\s+)?var\s+"
        + re.escape(property_name)
        + r"\s*:[^=]+{"
    )
    header = re.search(pattern, source, flags=re.MULTILINE)
    if header is None:
        raise AssertionError(f"Could not find computed property {property_name!r}")

    start = source.find("{", header.end() - 1)
    if start == -1:
        raise AssertionError(f"Could not find opening brace for {property_name!r}")

    depth = 0
    for index in range(start, len(source)):
        char = source[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[start + 1 : index]

    raise AssertionError(f"Could not find closing brace for {property_name!r}")


class ReviewRegressionTests(unittest.TestCase):
    def test_swiftui_onchange_does_not_observe_swiftdata_model_arrays(self):
        app = read("QRID/QRID/QRIDApp.swift")
        main = read("QRID/QRID/Views/MainView.swift")
        self.assertNotIn(".onChange(of: clusters)", app)
        self.assertNotIn(".onChange(of: clusters)", main)

    def test_cluster_signatures_cover_exported_cluster_fields(self):
        required_fields = [
            "avatarImageData",
            "backgroundImageData",
            "cornerRadius",
            "cardOpacity",
            "widgetBackgroundImageData",
        ]
        for path in ["QRID/QRID/QRIDApp.swift", "QRID/QRID/Views/MainView.swift"]:
            with self.subTest(path=path):
                source = read(path)
                signature_body = extract_computed_property_body(source, "clustersSignature")
                for field in required_fields:
                    self.assertIn(field, signature_body)

    def test_widget_settings_does_not_overwrite_shared_json_with_single_cluster(self):
        widget_settings = read("QRID/QRID/Views/WidgetSettingsView.swift")
        self.assertNotIn("WidgetDataHelper.sync(clusters: [cluster])", widget_settings)
        self.assertRegex(widget_settings, r"WidgetDataHelper\.sync\(clusters:\s*clusters")

    def test_persistence_saves_are_not_silently_discarded(self):
        files = [
            "QRID/QRID/Helpers/MigrationManager.swift",
            "QRID/QRID/Views/EditProfileView.swift",
            "QRID/QRID/Views/EditClusterView.swift",
            "QRID/QRID/Views/WidgetSettingsView.swift",
            "QRID/QRID/Views/ReorderClustersView.swift",
        ]
        for path in files:
            with self.subTest(path=path):
                source = read(path)
                self.assertIsNone(re.search(r"try\?\s+(?:modelContext|context)\.save\(\)", source))

    def test_backup_import_uses_security_scoped_resource_and_pre_restore_backup(self):
        settings = read("QRID/QRID/Views/SettingsView.swift")
        backup = read("QRID/QRID/Helpers/BackupManager.swift")
        self.assertIn("startAccessingSecurityScopedResource()", settings)
        self.assertIn("writePreRestoreBackup", backup)
        self.assertLess(backup.index("writePreRestoreBackup"), backup.index("modelContext.delete"))

    def test_new_clusters_receive_explicit_sort_order(self):
        add_profile = read("QRID/QRID/Views/AddProfileView.swift")
        self.assertIn("@Query(sort: \\QRCluster.sortOrder", add_profile)
        self.assertIn("nextSortOrder", add_profile)
        self.assertRegex(add_profile, r"sortOrder:\s*nextSortOrder")

    def test_icloud_toggle_is_not_present_until_real_cloudkit_sync_exists(self):
        settings = read("QRID/QRID/Views/SettingsView.swift")
        self.assertNotIn("Toggle(isOn: settingsBinding)", settings)
        self.assertNotIn("开启后，你的合集数据将同步到你的 iCloud 账户", settings)

    def test_transparent_qr_generation_preserves_quiet_zone(self):
        qr_generator = read("QRID/QRID/Helpers/QRCodeGenerator.swift")
        widget = read("MeQRWidget/MeQRWidget.swift")
        self.assertIn("quietZone", qr_generator)
        self.assertIn("quietZone", widget)


if __name__ == "__main__":
    unittest.main()
