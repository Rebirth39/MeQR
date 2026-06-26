# Final Live Sync Fix Report

Date: 2026-06-26
Workspace: `/Users/hexiguan/Documents/MeQR`

## Summary

Removed live file sync and auto-backup writes that were triggered from SwiftUI `onChange` observers over live SwiftData-backed cluster state.

The remaining sync behavior is limited to:

- `MainView.onAppear` for widget sync and auto-backup
- `WidgetSyncView.onAppear` for widget sync
- `WidgetSyncView.onChange(of: scenePhase)` when the scene becomes active

This keeps file writes off the transient unsaved mutation path so rollback-capable save/import flows do not leak unsaved state into `clusters.json` or auto-backup files.

## Root Cause

`MainView` and `WidgetSyncView` each derived a `clustersSignature` computed property from live SwiftData model state and used `.onChange(of: clustersSignature)` to trigger:

- `WidgetDataHelper.sync(clusters: clusters)`
- `BackupManager.writeAutoBackup(clusters: clusters)` in `MainView`

That observer ran on model mutation, not on confirmed persistence success. If a later save/import failed and `modelContext.rollback()` executed, the observer could already have serialized transient state to shared widget JSON or auto-backup JSON.

## Test-First Evidence

### RED before Swift changes

Command:

```bash
python3 -m unittest Tests.test_review_regressions.ReviewRegressionTests.test_live_model_change_observers_do_not_write_widget_or_backup_files
```

Result:

- Failed as expected because `QRIDApp.swift` still contained `.onChange(of: clustersSignature)` in `WidgetSyncView`

### GREEN after Swift changes

Focused commands:

```bash
python3 -m unittest Tests.test_review_regressions.ReviewRegressionTests.test_swiftui_onchange_does_not_observe_swiftdata_model_arrays Tests.test_review_regressions.ReviewRegressionTests.test_live_model_change_observers_do_not_write_widget_or_backup_files
python3 -m unittest Tests/test_review_regressions.py
plutil -lint /Users/hexiguan/Documents/MeQR/QRID/Info.plist /Users/hexiguan/Documents/MeQR/MeQRWidget/Info.plist /Users/hexiguan/Documents/MeQR/QRID/QRID.entitlements /Users/hexiguan/Documents/MeQR/MeQRWidgetExtension.entitlements
```

Results:

- Focused regression tests: 2 tests passed
- Full `Tests/test_review_regressions.py`: 9 tests passed
- `plutil -lint`: all listed plist and entitlement files OK

## Files Changed

- `QRID/QRID/QRIDApp.swift`
  - Removed `clustersSignature`
  - Removed `.onChange(of: clustersSignature)` from `WidgetSyncView`
- `QRID/QRID/Views/MainView.swift`
  - Removed `clustersSignature`
  - Removed `.onChange(of: clustersSignature)` that wrote widget and backup files
- `Tests/test_review_regressions.py`
  - Replaced the prior signature-field coverage regression with direct guards against live model-change sync/backup observers
  - Kept the existing `.onChange(of: clusters)` guard

## Notes

- `scenePhase`-driven widget sync remains intentionally allowed because it is lifecycle-based rather than a live model mutation observer.
- No unrelated files were edited.
