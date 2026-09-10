# Card layout regression harness

Run `node Tests/CardLayoutHarness/generate.cjs` from the iOS project root, then test `CardLayout.xcodeproj` with scheme `CardLayoutHost` on an iOS simulator.

The isolated app uses current production cards, pager, models, QR generator and Tag renderer. It substitutes language settings and supplies temporary in-memory fixtures without accessing user data or submitting reports.

Tests check short-card whitespace, unchanged card coordinates when adding/removing a second card, horizontal paging, Tags below long info, and reaching the QR/platform controls at 320pt with larger text.
