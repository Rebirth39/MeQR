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

    def test_successful_persistence_paths_refresh_widget_and_backup_outputs(self):
        cases = [
            ("QRID/QRID/Views/AddProfileView.swift", "save"),
            ("QRID/QRID/Views/EditProfileView.swift", "save"),
            ("QRID/QRID/Views/EditClusterView.swift", "save"),
            ("QRID/QRID/Views/WidgetSettingsView.swift", "save"),
            ("QRID/QRID/Views/ReorderClustersView.swift", "move"),
            ("QRID/QRID/Views/MainView.swift", "deleteCurrentQR"),
            ("QRID/QRID/Views/MainView.swift", "deleteCurrentCluster"),
        ]
        for path, function_name in cases:
            with self.subTest(path=path):
                source = read(path)
                body = extract_function_body(source, function_name)
                self.assertIn("@Query(sort: \\QRCluster.sortOrder", source)
                widget_sync = re.search(r"WidgetDataHelper\.sync\(clusters:\s*[^)]+\)", body)
                auto_backup = re.search(r"BackupManager\.writeAutoBackup\(clusters:\s*[^)]+\)", body)
                self.assertIsNotNone(widget_sync)
                self.assertIsNotNone(auto_backup)
                self.assertLess(
                    body.index("try modelContext.save()"),
                    widget_sync.start(),
                )
                self.assertLess(widget_sync.start(), auto_backup.start())

    def test_delete_paths_sync_from_persisted_fetch_after_save(self):
        cases = [
            ("QRID/QRID/Views/MainView.swift", "deleteCurrentQR"),
            ("QRID/QRID/Views/MainView.swift", "deleteCurrentCluster"),
            ("QRID/QRID/Views/EditClusterView.swift", "deleteProfiles"),
        ]
        for path, function_name in cases:
            with self.subTest(function_name=function_name):
                body = extract_function_body(read(path), function_name)
                fetch = re.search(r"modelContext\.fetch\(FetchDescriptor<QRCluster>", body)
                widget_sync = re.search(r"WidgetDataHelper\.sync\(clusters:\s*[^)]+\)", body)
                auto_backup = re.search(r"BackupManager\.writeAutoBackup\(clusters:\s*[^)]+\)", body)
                self.assertIsNotNone(fetch)
                self.assertIsNotNone(widget_sync)
                self.assertIsNotNone(auto_backup)
                self.assertNotIn("try? modelContext.fetch", body)
                self.assertNotIn("?? clusters", body)
                self.assertLess(body.index("try modelContext.save()"), fetch.start())
                self.assertLess(fetch.start(), widget_sync.start())
                self.assertLess(widget_sync.start(), auto_backup.start())

    def test_reorder_syncs_from_persisted_fetch_after_save(self):
        body = extract_function_body(read("QRID/QRID/Views/ReorderClustersView.swift"), "move")
        fetch = re.search(r"modelContext\.fetch\(FetchDescriptor<QRCluster>", body)
        widget_sync = re.search(r"WidgetDataHelper\.sync\(clusters:\s*[^)]+\)", body)
        auto_backup = re.search(r"BackupManager\.writeAutoBackup\(clusters:\s*[^)]+\)", body)
        self.assertIsNotNone(fetch)
        self.assertIsNotNone(widget_sync)
        self.assertIsNotNone(auto_backup)
        self.assertNotIn("try? modelContext.fetch", body)
        self.assertNotIn("?? clusters", body)
        self.assertLess(body.index("try modelContext.save()"), fetch.start())
        self.assertLess(fetch.start(), widget_sync.start())
        self.assertLess(widget_sync.start(), auto_backup.start())

    def test_add_profile_does_not_sync_stale_query_after_post_save_fetch_failure(self):
        body = extract_function_body(read("QRID/QRID/Views/AddProfileView.swift"), "save")
        self.assertNotIn("savedClusters = clusters", body)
        self.assertNotIn("?? clusters", body)
        self.assertLess(
            body.index("try modelContext.fetch(FetchDescriptor<QRCluster>"),
            body.index("WidgetDataHelper.sync(clusters:"),
        )

    def test_add_profile_success_path_does_not_show_debug_cluster_count_alert(self):
        source = read("QRID/QRID/Views/AddProfileView.swift")
        body = extract_function_body(source, "save")
        self.assertNotIn("已保存，当前共有", source)
        self.assertNotIn(".alert(\"保存结果\"", source)
        self.assertIn("dismiss()", body)
        self.assertLess(body.index("BackupManager.writeAutoBackup(clusters: persistedClusters)"), body.index("dismiss()"))

    def test_qrprofile_attach_does_not_mutate_both_sides_of_swiftdata_relationship(self):
        body = extract_function_body(read("QRID/QRID/Models/QRProfile.swift"), "attach")
        self.assertIn("self.cluster = cluster", body)
        self.assertIn("captureClusterFallback(from: cluster)", body)
        self.assertNotIn("cluster.profiles.append", body)

    def test_edit_cluster_profile_delete_rolls_back_and_dismisses_after_save(self):
        body = extract_function_body(read("QRID/QRID/Views/EditClusterView.swift"), "deleteProfiles")
        self.assertRegex(body, r"catch\s*\{\s*modelContext\.rollback\(\)")
        self.assertIn("shouldDismissAfterSave", body)
        self.assertLess(body.index("try modelContext.save()"), body.index("dismiss()"))

    def test_backup_restore_refreshes_widget_and_auto_backup_after_save(self):
        body = extract_function_body(read("QRID/QRID/Helpers/BackupManager.swift"), "importBackup")
        self.assertIn("WidgetDataHelper.sync(clusters:", body)
        self.assertIn("writeAutoBackup(clusters:", body)
        self.assertLess(body.index("try modelContext.save()"), body.index("modelContext.fetch(FetchDescriptor<QRCluster>"))
        self.assertLess(body.index("modelContext.fetch(FetchDescriptor<QRCluster>"), body.index("WidgetDataHelper.sync(clusters:"))
        self.assertLess(body.index("WidgetDataHelper.sync(clusters:"), body.index("writeAutoBackup(clusters:"))

    def test_migration_failures_roll_back_and_surface_to_main_view(self):
        migration = read("QRID/QRID/Helpers/MigrationManager.swift")
        migration_body = extract_function_body(migration, "performClusterMigrationIfNeeded")
        main = read("QRID/QRID/Views/MainView.swift")
        self.assertRegex(
            migration,
            r"static func performClusterMigrationIfNeeded\(context:\s*ModelContext\)\s+throws",
        )
        self.assertRegex(migration_body, r"catch\s*\{\s*context\.rollback\(\)\s*throw error")
        self.assertNotIn("print(\"Cluster migration", migration)
        self.assertIn("try MigrationManager.performClusterMigrationIfNeeded(context: modelContext)", main)
        self.assertRegex(
            main,
            r"catch\s*\{[\s\S]*?saveError\s*=\s*error\.localizedDescription[\s\S]*?showSaveError\s*=\s*true",
        )

    def test_main_view_migration_refreshes_persisted_outputs_before_lifecycle_sync(self):
        main = read("QRID/QRID/Views/MainView.swift")
        self.assertIn("private func syncPersistedOutputsFromStore() throws", main)
        sync_body = extract_function_body(main, "syncPersistedOutputsFromStore")
        migration_body = extract_function_body(main, "migrateClustersIfNeeded")
        self.assertLess(
            sync_body.index("let persistedClusters = try modelContext.fetch(FetchDescriptor<QRCluster>"),
            sync_body.index("WidgetDataHelper.sync(clusters: persistedClusters)"),
        )
        self.assertLess(
            sync_body.index("WidgetDataHelper.sync(clusters: persistedClusters)"),
            sync_body.index("BackupManager.writeAutoBackup(clusters: persistedClusters)"),
        )
        self.assertIn("try MigrationManager.performClusterMigrationIfNeeded(context: modelContext)", migration_body)
        self.assertIn("try syncPersistedOutputsFromStore()", migration_body)
        self.assertLess(
            migration_body.index("try MigrationManager.performClusterMigrationIfNeeded(context: modelContext)"),
            migration_body.index("try syncPersistedOutputsFromStore()"),
        )
        self.assertNotIn(".onAppear {\n                WidgetDataHelper.sync(clusters: clusters)", main)

    def test_app_uses_explicit_swiftdata_store_configuration(self):
        app = read("QRID/QRID/QRIDApp.swift")
        self.assertIn("let schema = Schema([QRCluster.self, QRProfile.self])", app)
        self.assertIn("ModelConfiguration(", app)
        self.assertIn("url: storeDirectoryURL.appendingPathComponent(\"QRID.store\")", app)
        self.assertIn("cloudKitDatabase: .none", app)
        self.assertIn(".modelContainer(sharedModelContainer)", app)
        self.assertNotIn(".modelContainer(for: [QRCluster.self, QRProfile.self])", app)

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

    def test_backup_ui_is_removed_but_pre_restore_backup_guard_remains(self):
        backup = read("QRID/QRID/Helpers/BackupManager.swift")
        import_body = extract_function_body(backup, "importBackup")
        self.assertFalse((ROOT / "QRID/QRID/Views/SettingsView.swift").exists())
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
        about = read("QRID/QRID/Views/AboutView.swift")
        localization = read("QRID/QRID/Helpers/Localization.swift")
        self.assertNotIn("开启后，你的合集数据将同步到你的 iCloud 账户", about)
        self.assertIn("https://rebirth39.github.io/MeQR/privacy.html", about)
        self.assertIn("Text(L.privacyPolicy)", about)
        self.assertIn("static var privacyPolicy", localization)
        self.assertIn("\"隐私政策\"", localization)

    def test_privacy_policy_view_and_hosted_page_exist(self):
        privacy_page = read("privacy.html")
        self.assertIn("喜劳转扩 隐私政策", privacy_page)
        self.assertIn("mailto:lucas_and_miku@icloud.com", privacy_page)
        self.assertIn("这个 App 目前主要是本地使用的小工具。", privacy_page)
        self.assertIn("https://qm.qq.com/q/ErpPGQuaAi", privacy_page)
        self.assertIn("Rebirth39", privacy_page)

    def test_about_view_uses_qid_link_instead_of_raw_qq_number(self):
        about = read("QRID/QRID/Views/AboutView.swift")
        self.assertIn("https://qm.qq.com/q/ErpPGQuaAi", about)
        self.assertIn('Text("QID")', about)
        self.assertIn('Text("Rebirth39")', about)
        self.assertNotIn("2137620096", about)

    def test_system_language_walks_preferred_language_fallback_list(self):
        settings = read("QRID/QRID/Helpers/AppSettings.swift")
        body = extract_function_body(settings, "preferredSystemLanguage")
        self.assertIn("for identifier in Locale.preferredLanguages", body)
        self.assertIn("language(matching: identifier)", body)
        self.assertRegex(body, r"return\s+\.en")
        self.assertIn("didSet", settings)
        self.assertIn("UserDefaults.standard.set(language", settings)

    def test_system_language_prefers_script_before_region(self):
        settings = read("QRID/QRID/Helpers/AppSettings.swift")
        matcher = extract_function_body(settings, "language")
        self.assertLess(matcher.index('normalized.contains("hans")'), matcher.index('normalized.contains("-hk")'))
        self.assertLess(matcher.index('normalized.contains("hant")'), matcher.index('normalized.contains("-hk")'))
        self.assertIn('return .zhHans', matcher)
        self.assertIn('return .zhHantHK', matcher)
        self.assertIn('return .zhHantTW', matcher)

    def test_unused_settings_and_embedded_privacy_views_are_removed(self):
        self.assertFalse((ROOT / "QRID/QRID/Views/SettingsView.swift").exists())
        self.assertFalse((ROOT / "QRID/QRID/Views/PrivacyPolicyView.swift").exists())

    def test_transparent_qr_generation_preserves_quiet_zone(self):
        qr_generator = read("QRID/QRID/Helpers/QRCodeGenerator.swift")
        widget = read("MeQRWidget/MeQRWidget.swift")
        qr_body = extract_function_body(qr_generator, "generateTransparent")
        widget_body = extract_function_body(widget, "generateQRImage")
        for name, body in [("app QR", qr_body), ("widget QR", widget_body)]:
            with self.subTest(target=name):
                self.assertIn("quietZone", body)
                self.assertIn("finalWidth = width + quietZone * 2", body)
                self.assertIn("finalHeight = height + quietZone * 2", body)
                self.assertIn("pixels[offset + 3] = 0", body)
                self.assertNotIn("pixels[offset] = 255", body)
                self.assertNotIn("pixels[offset + 1] = 255", body)
                self.assertNotIn("pixels[offset + 2] = 255", body)

    def test_failed_persistence_paths_roll_back_unsaved_changes(self):
        cases = [
            ("QRID/QRID/Helpers/BackupManager.swift", "importBackup"),
            ("QRID/QRID/Views/AddProfileView.swift", "save"),
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
