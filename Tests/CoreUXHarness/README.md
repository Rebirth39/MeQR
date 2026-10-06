# Core UI regressions

The harness compiles the current production MainView, card pager, card view,
and edit screens, together with their dependencies. It replaces only the app
entry point, uses an in-memory SwiftData store, a separate bundle/App Group,
synthetic profiles, and blocked networking. The sync fixture writes a synthetic
credential in the test app's keychain; each launch resets that fixture only.

Generate into a temporary directory so build outputs stay outside the repository:

```sh
python3 Tests/CoreUXHarness/generate.py /private/tmp/meqr-core-ui-regressions
xcodebuild test \
  -project /private/tmp/meqr-core-ui-regressions/CoreUX.xcodeproj \
  -scheme CoreUXHost \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' \
  -derivedDataPath /private/tmp/meqr-core-ui-regressions/derived \
  -resultBundlePath /private/tmp/meqr-core-ui-regressions/result.xcresult \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-
```

Run on iPad as well by changing the destination. The seven tests cover returning
to a card before editing/deleting its selected platform; canceling pending QR
deletion; saving deletion while preserving a surviving selection and widget
platform; canceling or saving deletion of the last QR; and rejecting whole-card
deletion until sync has stopped. The last-page deletion test also checks that the
remaining card becomes visible. Screenshots and accessibility hierarchies are
kept in the result bundle.

Use simulator signing: the test app's dedicated Keychain entitlement is needed
to exercise the production sync guard and synthetic binding fixture. This harness
is for simulators only and has no device provisioning configuration.
