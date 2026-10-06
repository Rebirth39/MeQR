# SwiftData relationship crash regressions

This isolated app compiles the current production models, onboarding, add-card
screen, card renderer, backup, migration, and sync code. It uses a separate bundle
and App Group, its own disk store, synthetic data, and blocked networking.
Only that test app's store is reset. The `readback` launch preserves it.

Generate and run on the oldest installed simulator:

```sh
python3 Tests/SwiftDataRelationshipHarness/generate.py /private/tmp/meqr-relationship-regression
xcodebuild test \
  -project /private/tmp/meqr-relationship-regression/CoreUX.xcodeproj \
  -scheme CoreUXHost \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
  -derivedDataPath /private/tmp/meqr-relationship-regression/derived \
  -resultBundlePath /private/tmp/meqr-relationship-regression/results.xcresult \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-
```

The image import test expects the synthetic exact-QQ QR photo already present in
the audit simulator, labeled `Photo, October 04, 21:25`. For another simulator,
import `Documents/TestsScreenshot/ios-qq-save-audit-20261004/exact-qq-fixture.png`
and adjust that selector to the Photos accessibility label. Other tests need no
photo setup.

Coverage:
- New-card manual and Photos-import saves, and adding to an existing card, all
  followed by app relaunch and persisted content/count checks.
- Both onboarding appearance templates, backtracking, final preview with no
  persisted drafts, final save and relaunch.
- Managed parent/child registration, inverse integrity, idempotent attach,
  refetch, reparenting, orphan migration, backup restore, sync growth/shrink,
  cascade deletion, and decoding the actual unpersisted preview rendering.

The two original failures are iOS 17.3.1 SwiftData SIGTRAPs. Passing on iOS 18.5
verifies regression behavior but does not substitute for testing the corrected
build on the affected iOS 17.3.1 device.
