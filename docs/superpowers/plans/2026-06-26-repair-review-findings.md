# MeQR Review Findings Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the high-risk Code Review findings in the current MeQR SwiftUI/SwiftData repository without changing the product scope.

**Architecture:** Keep the existing SwiftUI + SwiftData structure. Add a lightweight repository-level regression test file that can run with Command Line Tools (`python3 -m unittest`) because this machine does not have full Xcode installed. The Python tests are source-level regression checks for the reviewed risks; full iOS build and XCTest verification still need Xcode later.

**Tech Stack:** SwiftUI, SwiftData, WidgetKit, Vision, Foundation, Python standard-library `unittest`.

## Global Constraints

- Work on branch `codex/repair-review-findings`; do not modify `main`.
- Do not introduce third-party dependencies.
- Preserve current app features unless a reviewed feature is misleading or unsafe.
- Because full Xcode is unavailable in this environment, every task must run `python3 -m unittest Tests/test_review_regressions.py` after adding the test file.
- If changing Swift persistence writes, replace silent `try? modelContext.save()` / `try? context.save()` with explicit `do/catch` handling.
- Keep Widget App Group ID exactly `group.com.lucasli.qrid`.
- Keep app bundle identifiers unchanged: `com.lucasli.QRID` and `com.lucasli.QRID.MeQRWidget`.

---

### Task 1: Add Review Regression Test Harness

**Files:**
- Create: `Tests/test_review_regressions.py`

**Interfaces:**
- Consumes: current repository source files.
- Produces: a runnable regression check command: `python3 -m unittest Tests/test_review_regressions.py`.

- [ ] **Step 1: Write the failing tests**

Create `Tests/test_review_regressions.py` with tests that currently fail against the reviewed issues:

```python
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class ReviewRegressionTests(unittest.TestCase):
    def test_swiftui_onchange_does_not_observe_swiftdata_model_arrays(self):
        app = read("QRID/QRID/QRIDApp.swift")
        main = read("QRID/QRID/Views/MainView.swift")
        self.assertNotIn(".onChange(of: clusters)", app)
        self.assertNotIn(".onChange(of: clusters)", main)

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
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
python3 -m unittest Tests/test_review_regressions.py
```

Expected: FAIL, because the current code still has the reviewed defects.

- [ ] **Step 3: Commit only the test harness**

Run:

```bash
git add Tests/test_review_regressions.py
git commit -m "test: add review regression checks"
```

### Task 2: Fix Sync Triggers, Widget Full-Dataset Sync, and Cluster Ordering

**Files:**
- Modify: `QRID/QRID/QRIDApp.swift`
- Modify: `QRID/QRID/Views/MainView.swift`
- Modify: `QRID/QRID/Views/AddProfileView.swift`
- Modify: `QRID/QRID/Views/WidgetSettingsView.swift`

**Interfaces:**
- Consumes: `WidgetDataHelper.sync(clusters:)`.
- Produces: SwiftUI sync triggers that observe equatable snapshots, widget settings that sync the full cluster list, and new clusters with explicit increasing `sortOrder`.

- [ ] **Step 1: Run the focused failing tests**

Run:

```bash
python3 -m unittest Tests.test_review_regressions.ReviewRegressionTests.test_swiftui_onchange_does_not_observe_swiftdata_model_arrays Tests.test_review_regressions.ReviewRegressionTests.test_widget_settings_does_not_overwrite_shared_json_with_single_cluster Tests.test_review_regressions.ReviewRegressionTests.test_new_clusters_receive_explicit_sort_order
```

Expected: FAIL.

- [ ] **Step 2: Replace model-array `onChange` with equatable signatures**

In `QRID/QRID/QRIDApp.swift`, add a private signature and observe it:

```swift
private var clustersSignature: [String] {
    clusters.map { cluster in
        let profiles = cluster.profiles.sorted { $0.createdAt < $1.createdAt }
        let profileSignature = profiles
            .map { "\($0.id.uuidString)|\($0.platformType)|\($0.qrContent)|\($0.foregroundColorHex)|\($0.customPlatformName ?? "")" }
            .joined(separator: ";")
        return [
            cluster.id.uuidString,
            cluster.name,
            cluster.subtitle,
            cluster.backgroundColorHex,
            cluster.borderColorHex,
            cluster.textColorHex ?? "",
            cluster.qrColorHex ?? "",
            String(cluster.sortOrder),
            String(cluster.widgetProfileIndex ?? -1),
            String(cluster.widgetUseClusterBackground ?? true),
            String(cluster.widgetOpacity ?? 0.8),
            cluster.widgetTextColorHex ?? "",
            String(cluster.widgetSmallOffsetX ?? 0),
            String(cluster.widgetSmallOffsetY ?? 0),
            String(cluster.widgetMediumOffsetX ?? 0),
            String(cluster.widgetMediumOffsetY ?? 0),
            String(cluster.widgetLargeOffsetX ?? 0),
            String(cluster.widgetLargeOffsetY ?? 0),
            profileSignature
        ].joined(separator: "|")
    }
}
```

Then change:

```swift
.onChange(of: clusters) { _, newClusters in
    WidgetDataHelper.sync(clusters: newClusters)
}
```

to:

```swift
.onChange(of: clustersSignature) { _, _ in
    WidgetDataHelper.sync(clusters: clusters)
}
```

In `QRID/QRID/Views/MainView.swift`, add the same idea as `private var clustersSignature: [String]` and change:

```swift
.onChange(of: clusters) {
    WidgetDataHelper.sync(clusters: clusters)
    BackupManager.writeAutoBackup(clusters: clusters)
}
```

to:

```swift
.onChange(of: clustersSignature) {
    WidgetDataHelper.sync(clusters: clusters)
    BackupManager.writeAutoBackup(clusters: clusters)
}
```

- [ ] **Step 3: Give new clusters explicit sort order**

In `QRID/QRID/Views/AddProfileView.swift`, add:

```swift
@Query(sort: \QRCluster.sortOrder, order: .forward) private var clusters: [QRCluster]
```

Add:

```swift
private var nextSortOrder: Int {
    (clusters.map(\.sortOrder).max() ?? -1) + 1
}
```

Pass it into the new `QRCluster` initializer:

```swift
sortOrder: nextSortOrder
```

- [ ] **Step 4: Sync all clusters from widget settings**

In `QRID/QRID/Views/WidgetSettingsView.swift`, add:

```swift
@Query(sort: \QRCluster.sortOrder, order: .forward) private var clusters: [QRCluster]
```

Change:

```swift
WidgetDataHelper.sync(clusters: [cluster])
```

to:

```swift
WidgetDataHelper.sync(clusters: clusters)
```

- [ ] **Step 5: Run focused tests to verify they pass**

Run the same command from Step 1. Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add QRID/QRID/QRIDApp.swift QRID/QRID/Views/MainView.swift QRID/QRID/Views/AddProfileView.swift QRID/QRID/Views/WidgetSettingsView.swift
git commit -m "fix: stabilize cluster sync and ordering"
```

### Task 3: Fix Backup Restore Safety and Security-Scoped Import

**Files:**
- Modify: `QRID/QRID/Helpers/BackupManager.swift`
- Modify: `QRID/QRID/Views/SettingsView.swift`

**Interfaces:**
- Consumes: `BackupManager.exportBackup(clusters:)`, `BackupManager.importBackup(from:modelContext:)`.
- Produces: import flow that writes a pre-restore backup before destructive replacement and opens external document URLs through security-scoped access.

- [ ] **Step 1: Run the focused failing test**

Run:

```bash
python3 -m unittest Tests.test_review_regressions.ReviewRegressionTests.test_backup_import_uses_security_scoped_resource_and_pre_restore_backup
```

Expected: FAIL.

- [ ] **Step 2: Add pre-restore backup writer**

In `QRID/QRID/Helpers/BackupManager.swift`, add:

```swift
static func writePreRestoreBackup(clusters: [QRCluster]) throws -> URL {
    let backup = Backup(
        version: 1,
        exportedAt: Date(),
        clusters: clusters.map(makeClusterBackup)
    )
    let data = try JSONEncoder().encode(backup)
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let formatter = ISO8601DateFormatter()
    let safeDate = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
    let destination = documents.appendingPathComponent("MeQR-PreRestore-\(safeDate).json")
    try data.write(to: destination, options: [.atomic, .completeFileProtection])
    return destination
}
```

Extract cluster backup mapping into:

```swift
private static func makeClusterBackup(_ cluster: QRCluster) -> ClusterBackup
```

and use it from both `exportBackup` and `writePreRestoreBackup`.

- [ ] **Step 3: Call the pre-restore backup before deletion**

In `importBackup(from:modelContext:)`, after decoding and fetching `existingClusters`, call:

```swift
if !existingClusters.isEmpty {
    _ = try writePreRestoreBackup(clusters: existingClusters)
}
```

Only then delete existing clusters. Keep `try modelContext.save()` explicit.

- [ ] **Step 4: Use security-scoped resource access**

In `QRID/QRID/Views/SettingsView.swift`, wrap the picked URL:

```swift
let didAccess = url.startAccessingSecurityScopedResource()
defer {
    if didAccess {
        url.stopAccessingSecurityScopedResource()
    }
}
importSuccess = BackupManager.importBackup(from: url, modelContext: modelContext)
```

- [ ] **Step 5: Run focused test to verify it passes**

Run the same command from Step 1. Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add QRID/QRID/Helpers/BackupManager.swift QRID/QRID/Views/SettingsView.swift
git commit -m "fix: protect backup restore flow"
```

### Task 4: Replace Silent SwiftData Save Failures

**Files:**
- Modify: `QRID/QRID/Helpers/MigrationManager.swift`
- Modify: `QRID/QRID/Views/EditProfileView.swift`
- Modify: `QRID/QRID/Views/EditClusterView.swift`
- Modify: `QRID/QRID/Views/WidgetSettingsView.swift`
- Modify: `QRID/QRID/Views/ReorderClustersView.swift`

**Interfaces:**
- Consumes: existing save actions.
- Produces: explicit save failure handling, and migration completion is marked only after a successful save.

- [ ] **Step 1: Run the focused failing test**

Run:

```bash
python3 -m unittest Tests.test_review_regressions.ReviewRegressionTests.test_persistence_saves_are_not_silently_discarded
```

Expected: FAIL.

- [ ] **Step 2: Fix migration completion**

In `MigrationManager.performClusterMigrationIfNeeded`, replace:

```swift
try? context.save()
UserDefaults.standard.set(true, forKey: key)
```

with:

```swift
do {
    try context.save()
    UserDefaults.standard.set(true, forKey: key)
} catch {
    print("Cluster migration failed: \(error)")
}
```

- [ ] **Step 3: Add user-visible save errors where views dismiss after saving**

For `EditProfileView`, add `@State private var saveError: String?` and `@State private var showSaveError = false`, attach an alert, and change `save()` to:

```swift
do {
    try modelContext.save()
    dismiss()
} catch {
    saveError = error.localizedDescription
    showSaveError = true
}
```

For `EditClusterView`, `WidgetSettingsView`, and `ReorderClustersView`, do the same pattern. In `ReorderClustersView`, restore previous `sortOrder` values before showing the error if save fails.

- [ ] **Step 4: Run focused test to verify it passes**

Run the same command from Step 1. Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add QRID/QRID/Helpers/MigrationManager.swift QRID/QRID/Views/EditProfileView.swift QRID/QRID/Views/EditClusterView.swift QRID/QRID/Views/WidgetSettingsView.swift QRID/QRID/Views/ReorderClustersView.swift
git commit -m "fix: surface SwiftData save failures"
```

### Task 5: Remove Misleading iCloud Toggle and Preserve QR Quiet Zone

**Files:**
- Modify: `QRID/QRID/Views/SettingsView.swift`
- Modify: `QRID/QRID/Helpers/AppSettings.swift`
- Modify: `QRID/QRID/Helpers/QRCodeGenerator.swift`
- Modify: `MeQRWidget/MeQRWidget.swift`
- Modify: `README.md`

**Interfaces:**
- Consumes: current settings UI and transparent QR image generation.
- Produces: no visible iCloud sync claim until CloudKit sync exists; transparent QR rendering keeps a quiet zone.

- [ ] **Step 1: Run focused failing tests**

Run:

```bash
python3 -m unittest Tests.test_review_regressions.ReviewRegressionTests.test_icloud_toggle_is_not_present_until_real_cloudkit_sync_exists Tests.test_review_regressions.ReviewRegressionTests.test_transparent_qr_generation_preserves_quiet_zone
```

Expected: FAIL.

- [ ] **Step 2: Remove the iCloud toggle UI**

In `QRID/QRID/Views/SettingsView.swift`, remove the first `Section` containing `Toggle(isOn: settingsBinding)`.

Remove the now-unused `settingsBinding` computed property if no code uses it.

In `QRID/QRID/Helpers/AppSettings.swift`, remove `iCloudSyncEnabled` unless another file still uses it.

- [ ] **Step 3: Preserve quiet zone for transparent QR generation**

In `QRCodeGenerator.generateTransparent`, keep white/transparent conversion for the QR body, but render the final image into a larger bitmap with:

```swift
let quietZone = max(16, width / 12)
let finalWidth = width + quietZone * 2
let finalHeight = height + quietZone * 2
```

Draw the processed QR at `(quietZone, quietZone)` so the transparent QR keeps whitespace around the modules. Use the same `quietZone` naming in `MeQRWidget.generateQRImage`.

- [ ] **Step 4: Align README compatibility statement**

Update README to reflect the actual current target state, or state that full build verification requires Xcode. Do not claim iCloud sync as implemented.

- [ ] **Step 5: Run focused tests to verify they pass**

Run the same command from Step 1. Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add QRID/QRID/Views/SettingsView.swift QRID/QRID/Helpers/AppSettings.swift QRID/QRID/Helpers/QRCodeGenerator.swift MeQRWidget/MeQRWidget.swift README.md
git commit -m "fix: remove misleading sync claim and protect QR quiet zone"
```

### Task 6: Final Repository Verification

**Files:**
- No production files expected.

**Interfaces:**
- Consumes: all previous task commits.
- Produces: final verification evidence.

- [ ] **Step 1: Run all available checks**

Run:

```bash
python3 -m unittest Tests/test_review_regressions.py
plutil -lint QRID/Info.plist MeQRWidget/Info.plist QRID/QRID.entitlements MeQRWidgetExtension.entitlements
git status --short --branch
```

Expected:

- Python tests pass.
- `plutil` reports all files OK.
- Git branch is `codex/repair-review-findings`.

- [ ] **Step 2: Attempt Xcode build only if full Xcode is available**

Run:

```bash
if ls -d /Applications/Xcode*.app >/dev/null 2>&1; then
  DEVELOPER_DIR="$(ls -d /Applications/Xcode*.app | head -1)/Contents/Developer" xcodebuild -project QRID.xcodeproj -scheme QRID -destination 'generic/platform=iOS Simulator' build
else
  echo "Full Xcode not installed; skipping xcodebuild."
fi
```

Expected in this environment: `Full Xcode not installed; skipping xcodebuild.`

- [ ] **Step 3: Commit if verification files changed**

Only commit if this task changes tracked files.
