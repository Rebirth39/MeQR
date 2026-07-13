import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def extract_computed_property_body(source: str, property_name: str) -> str:
    pattern = (
        r"^\s*(?:private\s+|fileprivate\s+)?(?:static\s+)?var\s+"
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
        self.assertIn("https://rebirth39.github.io/MeQR/\\(path)", about)
        self.assertIn('"privacy.html"', about)
        self.assertIn('"privacy-en.html"', about)
        self.assertIn("appSettings.isChinese", about)
        self.assertIn("Text(L.privacyPolicy)", about)
        self.assertIn("static var privacyPolicy", localization)
        self.assertIn("\"隐私政策\"", localization)
        self.assertIn("\"Privacy Policy (English)\"", localization)
        self.assertIn("\"プライバシーポリシー（英語）\"", localization)

    def test_privacy_policy_view_and_hosted_page_exist(self):
        privacy_page = read("privacy.html")
        english_privacy_page = read("privacy-en.html")
        self.assertIn("喜劳转扩 隐私政策", privacy_page)
        self.assertIn("mailto:lucas_and_miku@icloud.com", privacy_page)
        self.assertIn("当你使用 MeQR 交换码的在线功能时", privacy_page)
        self.assertIn("不会在后台读取你的相册", privacy_page)
        self.assertNotIn("开发者的话", privacy_page)
        self.assertNotIn("Privacy Policy</h2>", privacy_page)
        self.assertIn("https://qm.qq.com/q/ErpPGQuaAi", privacy_page)
        self.assertIn("Rebirth39", privacy_page)
        self.assertIn("MeQR Privacy Policy", english_privacy_page)
        self.assertIn("Privacy Policy</h2>", english_privacy_page)
        self.assertIn("mailto:lucas_and_miku@icloud.com", english_privacy_page)
        self.assertIn("online MeQR exchange-code feature", english_privacy_page)
        self.assertIn("does not include advertising SDKs", english_privacy_page)

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

    def test_platform_picker_uses_curated_groups_and_case_insensitive_custom_names(self):
        profile = read("QRID/QRID/Models/QRProfile.swift")
        add_profile = read("QRID/QRID/Views/AddProfileView.swift")
        edit_profile = read("QRID/QRID/Views/EditProfileView.swift")

        self.assertIn("static var commonPlatforms: [Platform]", profile)
        self.assertIn("[.wechat, .qq, .xiaohongshu, .bilibili, .instagram, .line, .github]", profile)
        self.assertIn("[localizedShortVideoPlatform, .weibo, .whatsapp, .twitter, .snapchat, .facebook, .reddit, .threads, .twitch]", profile)
        self.assertIn("[.linkedin, .testflight]", profile)
        self.assertIn("case .zhHans, .zhHantHK:", profile)
        self.assertIn("return .douyin", profile)
        self.assertIn("case .system, .zhHantTW, .en, .ja:", profile)
        self.assertIn("return .tiktok", profile)
        self.assertIn('case "testflight", "tf": return .testflight', profile)
        self.assertIn('if lower.contains("testflight.apple.com") { return .testflight }', profile)

        for removed_visible_option in [
            ".paypal", ".venmo", ".cashapp", ".email", ".phone",
            ".telegram", ".discord", ".youtube", ".pinterest",
            ".signal", ".mastodon", ".bluesky", ".linktree",
        ]:
            self.assertNotIn(removed_visible_option, extract_computed_property_body(profile, "selectablePlatforms"))

        for source in [add_profile, edit_profile]:
            self.assertIn("Section(L.commonPlatforms)", source)
            self.assertIn("Section(L.socialPlatforms)", source)
            self.assertIn("Section(L.professionalPlatforms)", source)
            self.assertIn("platformOption(.custom)", source)
            self.assertNotIn("ForEach(Platform.allCases)", source)
        self.assertIn("Platform.resolvedSelection(", add_profile)
        self.assertIn("Platform.resolvedSelection(", edit_profile)

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

    def test_card_tags_have_default_and_custom_colors(self):
        cluster = read("QRID/QRID/Models/QRCluster.swift")
        add_profile = read("QRID/QRID/Views/AddProfileView.swift")
        edit_cluster = read("QRID/QRID/Views/EditClusterView.swift")
        card = read("QRID/QRID/Views/ClusterCardView.swift")
        editor = read("QRID/QRID/Views/CardTagColorEditor.swift")
        localization = read("QRID/QRID/Helpers/Localization.swift")

        self.assertIn("var tagColorOverridesRawValue: String?", cluster)
        self.assertIn("static let maxTags = 10", cluster)
        self.assertIn("static let maxHalfWidthUnits = 20", cluster)
        self.assertIn("if let indexedTag = CardTagIndex.canonicalTag(for: trimmed)", cluster)
        self.assertIn("return indexedTag", cluster)
        self.assertIn('("#39C5BB", ["术力口", "ボカロ", "vocaloid"', cluster)
        self.assertIn('("#3381B0", ["mygo"', cluster)
        self.assertIn('("#E53344", ["afterglow"', cluster)
        self.assertIn('("#33DDAA", ["pastelpalettes"', cluster)
        self.assertIn('("#FFC02A", ["hellohappyworld"', cluster)
        self.assertIn('("#33AADD", ["morfonica"', cluster)
        self.assertIn('("#66CC33", ["raiseasuilen"', cluster)
        self.assertIn('("#7D4CFF", ["mugendaimewtype"', cluster)
        self.assertIn('"プロセカ", "世界计划", "世界計畫"', cluster)
        self.assertIn('"世嘉彩舞", "彩舞"', cluster)
        self.assertIn('"l/n", "ln", "レオニ"', cluster)
        self.assertIn('"mmj", "モモジャン", "桃跳"', cluster)
        self.assertIn('"vbs", "ビビバス"', cluster)
        self.assertIn('"ws", "wxS", "wxs"', cluster)
        self.assertIn('"n25", "25ji", "25時", "25时"', cluster)
        self.assertIn('"天馬司", "凤笑梦", "鳳えむ"', cluster)
        self.assertIn('("#FF9900", "#FF66BB", ["凤笑梦", "鳳笑夢", "鳳えむ"', cluster)
        self.assertIn('tags(from: value).joined(separator: "\\n")', cluster)
        self.assertIn('let separators = CharacterSet(charactersIn: "\\n\\r")', cluster)
        self.assertNotIn('CharacterSet(charactersIn: ",，、;；\\n\\r\\t ")', cluster)
        self.assertIn('enum CardTagIndex', cluster)
        self.assertIn('zhHans: "世界计划", zhHantHK: "世界計畫", zhHantTW: "世界計畫", en: "Project Sekai", ja: "プロセカ"', cluster)
        self.assertIn('aliases: ["pjsk", "projectsekai", "project sekai", "啤酒烧烤"', cluster)
        self.assertIn('en: "VOCALOID", ja: "ボカロ"', cluster)
        self.assertIn('en: "BanG Dream!", ja: "バンドリ"', cluster)
        self.assertIn('en: "MyGO!!!!!", ja: "MyGO!!!!!"), aliases: ["mygo"', cluster)
        self.assertIn('en: "Tomori Takamatsu", ja: "高松燈"), aliases: ["灯", "燈", "tmr"', cluster)
        self.assertIn('en: "Arknights", ja: "アークナイツ"', cluster)
        self.assertIn('en: "Blue Archive", ja: "ブルアカ"', cluster)
        self.assertIn('en: "Honkai: Star Rail", ja: "崩壊スターレイル"', cluster)
        self.assertIn('en: "Genshin Impact", ja: "原神"', cluster)
        self.assertIn('en: "Bocchi the Rock!", ja: "ぼっち・ざ・ろっく！"', cluster)
        self.assertIn('en: "Touhou Project", ja: "東方Project"', cluster)
        self.assertIn('en: "Evangelion", ja: "エヴァンゲリオン"', cluster)
        self.assertIn('en: "Frieren", ja: "葬送のフリーレン"', cluster)
        self.assertIn('en: "Jujutsu Kaisen", ja: "呪術廻戦"', cluster)
        self.assertIn('en: "Demon Slayer", ja: "鬼滅の刃"', cluster)
        self.assertIn('en: "Haikyu!!", ja: "ハイキュー!!"', cluster)
        self.assertIn('en: "Detective Conan", ja: "名探偵コナン"', cluster)
        self.assertIn('en: "Attack on Titan", ja: "進撃の巨人"', cluster)
        self.assertIn('en: "Chainsaw Man", ja: "チェンソーマン"', cluster)
        self.assertIn('en: "Oshi no Ko", ja: "【推しの子】"', cluster)
        self.assertIn('en: "SPY x FAMILY", ja: "SPY×FAMILY"', cluster)
        self.assertIn('en: "Pokemon", ja: "ポケモン"', cluster)
        self.assertIn('en: "Satoru Gojo", ja: "五条悟"', cluster)
        self.assertIn('en: "Anya Forger", ja: "アーニャ・フォージャー"', cluster)
        self.assertIn('en: "Pikachu", ja: "ピカチュウ"', cluster)
        self.assertIn('zhHans: "MORE MORE JUMP!", zhHantHK: "MORE MORE JUMP!", zhHantTW: "MORE MORE JUMP!"', cluster)
        self.assertIn('aliases: ["mmj", "more more jump", "moremorejump", "モモジャン", "桃跳"]', cluster)
        self.assertIn('zhHans: "Wonderlands x Showtime", zhHantHK: "Wonderlands x Showtime"', cluster)
        self.assertIn('"ワンダーランズ x ショウタイム"', cluster)
        self.assertIn('zhHans: "Wonderlands x Showtime 拼色"', cluster)
        self.assertIn('aliases: ["wsmix", "ws mix", "ws多色", "ws拼色"', cluster)
        self.assertIn('zhHans: "25点，Nightcord见。", zhHantHK: "25點，Nightcord見。", zhHantTW: "25點，Nightcord見。"', cluster)
        self.assertIn('"MORE MORE JUMP!", "mmj"', cluster)
        self.assertIn('"Nightcord at 25:00", "25点，Nightcord见。", "25點，Nightcord見。"', cluster)
        self.assertIn("private nonisolated static let multiDefaults", cluster)
        self.assertIn('["#39C5BB", "#00A0E9", "#88DD44", "#FF9900", "#EE1166", "#884499"]', cluster)
        self.assertIn('["#FF9900", "#FFBB00", "#FF66BB", "#33DD99", "#BB88EE"]', cluster)
        self.assertIn("struct CardTagColorOverride: Codable, Equatable", cluster)
        self.assertIn("case preset", cluster)
        self.assertIn("case solid", cluster)
        self.assertIn("case custom", cluster)
        self.assertIn("CardTagColorStyle(segmentHexes: hexes)", cluster)
        self.assertIn("let hexes = normalizedPresetHexes(entry.hexes)", cluster)
        self.assertIn("private nonisolated static func normalizedPresetHexes", cluster)
        self.assertIn("Array(values.compactMap(normalizedHex).prefix(3))", cluster)
        self.assertIn('("#00A0E9", "#33AAEE", ["星乃一歌"', cluster)
        self.assertIn('"Ichika Hoshino"', cluster)
        self.assertIn('("#88DD44", "#FFCCAA", ["花里实乃理"', cluster)
        self.assertIn('"Minori Hanasato"', cluster)
        self.assertIn('("#EE1166", "#FF6699", ["小豆泽心羽"', cluster)
        self.assertIn('"Kohane Azusawa"', cluster)
        self.assertIn('("#884499", "#BB6688", ["宵崎奏"', cluster)
        self.assertIn('"Kanade Yoisaki"', cluster)
        self.assertIn('("#FF3377", "#FF5522", ["户山香澄"', cluster)
        self.assertIn('("#E53344", "#55BB77", ["青叶摩卡"', cluster)
        self.assertIn('("#33DDAA", "#FF66AA", ["丸山彩"', cluster)
        self.assertIn('("#3344AA", "#DD2244", ["今井莉莎"', cluster)
        self.assertIn('("#FFC02A", "#AA66CC", ["濑田薰"', cluster)
        self.assertIn('("#33AADD", "#AABBFF", ["仓田真白"', cluster)
        self.assertIn('("#66CC33", "#77CC44", ["朝日六花"', cluster)
        self.assertIn('("#3381B0", "#FF8899", ["千早爱音"', cluster)
        self.assertIn('("#881144", "#884499", ["丰川祥子"', cluster)
        self.assertIn('("#7D4CFF", "#FF66AA", ["仲町阿拉蕾"', cluster)
        self.assertIn('en: "Kessoku Band", ja: "結束バンド"', cluster)
        self.assertIn('("#F4B6C2", "#FFD34E", ["伊地知虹夏"', cluster)
        self.assertIn('en: "Ho-kago Tea Time", ja: "放課後ティータイム"', cluster)
        self.assertIn('aliases: ["k-on", "kon", "けいおん", "轻音", "輕音", "轻音少女"', cluster)
        self.assertIn('("#F2C94C", "#61C28B", ["中野梓"', cluster)
        self.assertIn('("#F2C94C", "#F5A6B8", ["平泽忧"', cluster)
        self.assertIn('("#F2C94C", "#72BFA3", ["真锅和"', cluster)
        self.assertIn('("#F2C94C", "#B990D8", ["山中佐和子"', cluster)
        self.assertIn('("#F2C94C", "#D59A5B", ["铃木纯"', cluster)
        self.assertIn('en: "TOGENASHI TOGEARI", ja: "トゲナシトゲアリ"', cluster)
        self.assertIn('aliases: ["gbc", "girlsbandcry", "ガルクラ"', cluster)
        self.assertIn('("#E60033", "#F05A8A", ["井芹仁菜"', cluster)
        self.assertIn("struct CardTagColorStyle", cluster)
        self.assertIn("let segmentHexes: [String]", cluster)
        self.assertIn("nonisolated static func colorStyle", cluster)
        self.assertIn('"朝比奈真冬", "真冬"', cluster)
        self.assertIn('"明日方舟", "アークナイツ"', cluster)
        self.assertIn('"阿米娅", "阿米婭", "アーミヤ"', cluster)
        self.assertIn('"小鸟游星野", "小鳥遊ホシノ"', cluster)
        self.assertIn('"卡芙卡", "kafka"', cluster)
        self.assertIn('"芙宁娜", "芙寧娜", "furina"', cluster)
        self.assertIn('"高坂穗乃果", "高坂穂乃果"', cluster)
        self.assertIn('"朔间零", "朔間零"', cluster)
        self.assertIn('"岛村卯月", "島村卯月"', cluster)
        self.assertIn('"特别周", "スペシャルウィーク"', cluster)
        self.assertIn('"后藤一里", "後藤ひとり"', cluster)
        self.assertIn('"博丽灵梦", "博麗霊夢"', cluster)
        self.assertIn('("#7B4BC9", ["eva"', cluster)
        self.assertIn('("#8CC7A1", ["frieren"', cluster)
        self.assertIn('("#4B3F72", ["jjk"', cluster)
        self.assertIn('("#2E8B57", ["demonslayer"', cluster)
        self.assertIn('("#F58220", ["haikyu"', cluster)
        self.assertIn('("#1E73BE", ["conan"', cluster)
        self.assertIn('("#8A6A4F", ["aot"', cluster)
        self.assertIn('("#E84A27", ["chainsawman"', cluster)
        self.assertIn('("#E85AA8", ["oshinoko"', cluster)
        self.assertIn('("#7BA05B", ["spyxfamily"', cluster)
        self.assertIn('("#FFCB05", ["pokemon"', cluster)
        self.assertIn('("#F2C94C", ["k-on"', cluster)
        self.assertIn('("#E60033", ["girlsbandcry"', cluster)
        self.assertIn('["#39C5BB", "#FFE211", "#FFB000", "#FF69B4", "#E44D98", "#0068B7"]', cluster)
        self.assertIn('["#E60033", "#F05A8A", "#9B6DFF", "#FFD447", "#58A6FF", "#5EC26A"]', cluster)
        self.assertIn('"母鸡卡"', cluster)
        self.assertIn("tagGradientStops(for: style)", editor)
        self.assertIn("tagGradientStops(for: style, opacity: 0.86)", editor)
        self.assertIn("tagGradientStops(for: style, opacity: 0.86)", card)
        self.assertIn("style.segmentHexes.enumerated().flatMap", editor)
        self.assertIn("style.segmentHexes.enumerated().flatMap", card)
        self.assertIn('"孤摇", "孤搖"', cluster)
        self.assertNotIn('"bilibili"', cluster)
        self.assertNotIn('"weibo"', cluster)
        self.assertNotIn('"wechat"', cluster)
        self.assertIn("static func rawValue(from overrides:", cluster)
        self.assertIn("CardTagInputView(text: $tagInput, colorOverrides: tagColorOverrides)", add_profile)
        self.assertIn("CardTagInputView(text: $tagInput, colorOverrides: tagColorOverrides)", edit_cluster)
        self.assertIn("CardTagColorEditor(tagInput: tagInput, colorOverrides: $tagColorOverrides)", add_profile)
        self.assertIn("CardTagColorEditor(tagInput: tagInput, colorOverrides: $tagColorOverrides)", edit_cluster)
        self.assertIn("DisclosureGroup(L.tagColors", editor)
        self.assertIn("DisclosureGroup(L.appearance", add_profile)
        self.assertIn("DisclosureGroup(L.backgroundImage", add_profile)
        self.assertIn("DisclosureGroup(L.appearance", edit_cluster)
        self.assertIn("DisclosureGroup(L.widgetSettings", edit_cluster)
        self.assertIn("DisclosureGroup(L.backgroundImage", edit_cluster)
        self.assertIn("tagColorOverridesRawValue: CardTagColorPalette.rawValue", add_profile)
        self.assertIn("cluster.tagColorOverridesRawValue = CardTagColorPalette.rawValue", edit_cluster)
        self.assertIn("struct CardTagInputView", editor)
        self.assertIn("private struct CardTagPreviewChip", editor)
        self.assertIn("struct CardTagFlowLayout: Layout", editor)
        self.assertIn("TextField(L.tags, text: $draft)", editor)
        self.assertIn("CardTagIndex.suggestions(", editor)
        self.assertIn("commitDraft()", editor)
        self.assertIn("removeTag(_ tag: String)", editor)
        self.assertIn("CardTagFlowLayout(spacing: 8, rowSpacing: 6)", editor)
        self.assertIn("ColorPicker(selection: customColorBinding(for: tag, index: index), supportsOpacity: false)", editor)
        self.assertIn("Label(L.addColor, systemImage: \"plus.circle\")", editor)
        self.assertIn("CardTagPreviewChip(tag: tag, colorOverrides: colorOverrides)", editor)
        self.assertIn("let style = CardTagColorPalette.colorStyle(for: tag, overrides: colorOverrides)", editor)
        self.assertIn("return [fallbackHex]", cluster)
        self.assertIn("guard hexes.count < 3 else { return }", editor)
        self.assertIn("Picker(\"\", selection: presetModeBinding(for: tag))", editor)
        self.assertIn("CardTagColorPalette.isPresetColored(tag)", editor)
        self.assertIn("cluster.tagColorStyle(for: tag)", card)
        self.assertIn("CardTagFlowLayout(spacing: 7, rowSpacing: 6)", card)
        self.assertIn("LinearGradient(", card)
        self.assertIn("tagColor.uiContrastColor", card)
        self.assertIn(".background(.white.opacity(cluster.cardOpacity ?? 0.7), in: RoundedRectangle(cornerRadius: 14))", card)
        self.assertIn("static var tagColors", localization)
        self.assertIn("static var addColor", localization)
        self.assertIn("static var tagColorMixed", localization)
        self.assertIn("最多 10 个", localization)


if __name__ == "__main__":
    unittest.main()
