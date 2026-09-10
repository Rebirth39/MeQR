# Tag Layout UI Tests

This isolated iOS host compiles the production `CardTagReorderView.swift` and
`ColorExtensions.swift`. Model, palette and localization fixtures avoid launching
the full app or touching user data. The host embeds tags inside a SwiftUI Form.

Run from the QRID project directory, substituting an available simulator ID:

```sh
xcodebuild -project Tests/TagLayoutHarness/TagLayout.xcodeproj \
  -scheme TagLayoutHost -destination 'platform=iOS Simulator,id=SIMULATOR_ID' \
  -derivedDataPath /tmp/meqr-taglayout-derived -parallel-testing-enabled NO test
```

Tests assert leading alignment, fixed 7pt gaps, compact default height, container
bounds, narrow wrapping, and layout with larger surrounding SwiftUI text. They
also exercise native cross-row dragging and deletion, checking layout again after
each operation. Screenshots are retained in the test result attachments.

The native reporting test compiles the production report menu and form, injects a
test receipt (no production ticket creation), and verifies long-press presentation,
required description, receipt display and no accidental tag selection.
