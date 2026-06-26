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


def extract_function_body(source: str, function_name: str) -> str:
    pattern = (
        r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*"
        r"(?:(?:private|fileprivate|internal|public|open)\s+)?"
        r"(?:(?:static|class)\s+)?func\s+"
        + re.escape(function_name)
        + r"\s*\("
    )
    header = re.search(pattern, source, flags=re.MULTILINE)
    if header is None:
        raise AssertionError(f"Could not find function {function_name!r}")

    start = source.find("{", header.end())
    if start == -1:
        raise AssertionError(f"Could not find opening brace for {function_name!r}")

    depth = 0
    for index in range(start, len(source)):
        char = source[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[start + 1 : index]

    raise AssertionError(f"Could not find closing brace for {function_name!r}")


class ReviewRegressionTests(unittest.TestCase):
    def test_swiftui_onchange_does_not_observe_swiftdata_model_arrays(self):
        app = read("QRID/QRID/QRIDApp.swift")
        main = read("QRID/QRID/Views/MainView.swift")
        self.assertNotIn(".onChange(of: clusters)", app)
        self.assertNotIn(".onChange(of: clusters)", main)

    def test_live_model_change_observers_do_not_write_widget_or_backup_files(self):
        app = read("QRID/QRID/QRIDApp.swift")
        main = read("QRID/QRID/Views/MainView.swift")

        self.assertNotIn(".onChange(of: clustersSignature)", app)
        self.assertNotIn(".onChange(of: clustersSignature)", main)
        self.assertNotIn("clustersSignature", app)
        self.assertNotIn("clustersSignature", main)

        for source in [app, main]:
            self.assertNotRegex(
                source,
                r"\.onChange\(of:\s*clusters\)\s*\{[\s\S]*?WidgetDataHelper\.sync",
            )
            self.assertNotRegex(
                source,
                r"\.onChange\(of:\s*clusters\)\s*\{[\s\S]*?BackupManager\.writeAutoBackup",
            )

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

        migration_manager = read("QRID/QRID/Helpers/MigrationManager.swift")
        self.assertIsNone(re.search(r"try\?\s+(?:modelContext|context)\.fetch\(", migration_manager))

    def test_backup_import_uses_security_scoped_resource_and_pre_restore_backup(self):
        settings = read("QRID/QRID/Views/SettingsView.swift")
        backup = read("QRID/QRID/Helpers/BackupManager.swift")
        import_body = extract_function_body(backup, "importBackup")
        self.assertIn("startAccessingSecurityScopedResource()", settings)
        self.assertIn("writePreRestoreBackup", import_body)
        self.assertLess(import_body.index("writePreRestoreBackup"), import_body.index("modelContext.delete"))
        self.assertRegex(
            import_body,
            r"catch\s*\{\s*modelContext\.rollback\(\)[\s\S]*?return false",
        )

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
        qr_body = extract_function_body(qr_generator, "generateTransparent")
        widget_body = extract_function_body(widget, "generateQRImage")
        for name, body in [("app QR", qr_body), ("widget QR", widget_body)]:
            with self.subTest(target=name):
                self.assertIn("quietZone", body)
                self.assertNotIn("pixels[offset + 3] = 0", body)
                self.assertIn("pixels[offset] = 255", body)
                self.assertIn("pixels[offset + 1] = 255", body)
                self.assertIn("pixels[offset + 2] = 255", body)
                self.assertIn("pixels[offset + 3] = 255", body)

    def test_failed_persistence_paths_roll_back_unsaved_changes(self):
        cases = [
            ("QRID/QRID/Helpers/BackupManager.swift", "importBackup"),
            ("QRID/QRID/Views/EditProfileView.swift", "save"),
            ("QRID/QRID/Views/EditClusterView.swift", "save"),
            ("QRID/QRID/Views/WidgetSettingsView.swift", "save"),
        ]
        for path, function_name in cases:
            with self.subTest(path=path):
                body = extract_function_body(read(path), function_name)
                self.assertRegex(
                    body,
                    r"catch\s*\{\s*modelContext\.rollback\(\)",
                    msg=f"{path} should roll back in {function_name} catch path",
                )


if __name__ == "__main__":
    unittest.main()
