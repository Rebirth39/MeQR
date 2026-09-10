# Tag UX Harness

Run `node Tests/TagUXHarness/generate.cjs` from the iOS project directory before building `TagUX.xcodeproj` with scheme `TagUXHost`. The generator copies current production Tag views, localization, catalog, outbox and SwiftData model into the isolated harness. Generated files are ignored.

The harness substitutes only application settings and the unrelated QRProfile model. Report form tests inject a receipt transport and do not submit live tickets. Persistent-state tests are in `../TagStateTests.swift` and `../test_tag_state.py`.

UI tests cover narrow HEX entry, actual long-press color dragging, five-color copy, large-text geometry, ambiguous search context and native new-tag request validation/submission. The host also saves and reopens the production QRCluster model using an isolated temporary SwiftData store.

September 8 evidence: `Documents/debug/tag-ux-20260908/ios-ui-final.xcresult` (4 tests passed), with exported screenshots in `ios-ui-final-images`. Earlier v1-v6 results are diagnostic failures; v7 verifies the final drag fix in isolation.
