import XCTest

final class LayoutTests: XCTestCase {
    func testChineseInkAndRequestIcon() {
        let app = XCUIApplication(); app.launchArguments = ["chinese"]; app.launch()
        XCTAssertTrue(app.staticTexts["tag-label-世界计划"].waitForExistence(timeout: 5))
        capture("chinese-solid-ink")
        app.buttons["Library"].tap()
        let request = app.buttons["申请收录 Tag"]
        XCTAssertTrue(request.waitForExistence(timeout: 5))
        XCTAssertTrue(request.isHittable)
        capture("request-icon-visible")
        request.tap()
        XCTAssertTrue(app.textFields["所属作品 / IP"].waitForExistence(timeout: 3))
    }
    func testLargePalette() {
        let app = XCUIApplication(); app.launchArguments = ["palette", "narrow", "large"]; app.launch()
        app.buttons["Tag Colors"].tap()
        app.swipeUp()
        let field = app.textFields["tag-hex-0"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        let handle = app.images["tag-color-handle-Project Sekai-0"]
        XCTAssertGreaterThanOrEqual(field.frame.width, 78)
        XCTAssertLessThanOrEqual(handle.frame.maxX, field.frame.minX)
        XCTAssertLessThanOrEqual(field.frame.maxX, 361)
        capture("custom-large-narrow")
    }
    func testDragAndCopy() {
        let app = XCUIApplication(); app.launchArguments = ["palette", "narrow"]; app.launch()
        app.buttons["Tag Colors"].tap()
        app.swipeUp()
        let first = app.images["tag-color-handle-Project Sekai-0"]
        let second = app.images["tag-color-handle-Project Sekai-1"]
        XCTAssertTrue(first.waitForExistence(timeout: 3))
        first.press(forDuration: 1, thenDragTo: second)
        capture("custom-five-drag")
        app.buttons["Copy Colors To…"].firstMatch.tap()
        app.buttons["Hatsune Miku"].firstMatch.tap()
        app.swipeUp()
        app.swipeUp()
        XCTAssertEqual(app.staticTexts["stored-palette"].label, "#ABCDEF,#123456,#FF9900,#EE1166,#FFFFFF")
        XCTAssertEqual(app.staticTexts["copied-palette"].label, app.staticTexts["stored-palette"].label)
        capture("copied-five")
    }
    func testDragPairCancelAndChangeKind() {
        let app = XCUIApplication(); app.launchArguments = ["chinese", "pairs"]; app.launch()
        let first = app.staticTexts["tag-label-星乃一歌"]
        let second = app.staticTexts["tag-label-天马咲希"]
        XCTAssertTrue(first.waitForExistence(timeout: 6))
        first.press(forDuration: 0.8, thenDragTo: second)
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 4))
        app.alerts.buttons["取消"].tap()
        XCTAssertTrue(first.exists); XCTAssertTrue(second.exists)
        first.press(forDuration: 0.8, thenDragTo: second)
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 4))
        app.alerts.buttons["CB"].tap()
        let combined = app.staticTexts["tag-label-一歌&咲希"]
        XCTAssertTrue(combined.waitForExistence(timeout: 4))
        XCTAssertFalse(first.exists); XCTAssertFalse(second.exists)
        capture("cb-pair-editor")
        app.buttons["标签颜色"].tap()
        let picker = app.segmentedControls["tag-pair-kind-一歌&咲希"]
        XCTAssertTrue(picker.waitForExistence(timeout: 4))
        picker.buttons["CP"].tap()
        XCTAssertTrue(combined.label.contains("CP"))
        capture("cp-pair-editor")
        app.swipeUp(); app.swipeUp()
        app.buttons["Reopen Stored Tags"].tap()
        let stored = app.staticTexts["pair-state"]
        XCTAssertTrue(stored.label.contains("一歌&咲希"))
        XCTAssertEqual(stored.label.components(separatedBy: "\n").count, 3)
        app.swipeDown(); app.swipeDown()
        XCTAssertTrue(combined.waitForExistence(timeout: 4))
        XCTAssertTrue(combined.label.contains("CP"))
        capture("pair-reopened")
    }
    func testReverseDragAndSwapSides() {
        let app = XCUIApplication(); app.launchArguments = ["chinese", "pairs"]; app.launch()
        let ichika = app.staticTexts["tag-label-星乃一歌"]
        let saki = app.staticTexts["tag-label-天马咲希"]
        XCTAssertTrue(saki.waitForExistence(timeout: 6))
        saki.press(forDuration: 0.8, thenDragTo: ichika)
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 4))
        app.alerts.buttons["CP"].tap()
        let reverse = app.staticTexts["tag-label-咲希&一歌"]
        XCTAssertTrue(reverse.waitForExistence(timeout: 4))
        XCTAssertTrue(reverse.label.contains("CP"))
        app.buttons["标签颜色"].tap()
        XCTAssertFalse(app.segmentedControls["tag-appearance-咲希&一歌"].exists)
        let swap = app.buttons["tag-pair-swap-咲希&一歌"]
        XCTAssertTrue(swap.waitForExistence(timeout: 4))
        let bold = app.buttons["tag-weight-咲希&一歌"]
        XCTAssertGreaterThan(swap.frame.midX, bold.frame.midX)
        bold.tap()
        let weight = bold.value as? String
        capture("reverse-pair-controls")
        swap.tap()
        let forward = app.staticTexts["tag-label-一歌&咲希"]
        XCTAssertTrue(forward.waitForExistence(timeout: 4))
        XCTAssertTrue(forward.label.contains("CP"))
        XCTAssertEqual(app.buttons["tag-weight-一歌&咲希"].value as? String, weight)
        let picker = app.segmentedControls["tag-pair-kind-一歌&咲希"]
        picker.buttons["CB"].tap()
        app.buttons["tag-pair-swap-一歌&咲希"].tap()
        XCTAssertTrue(reverse.waitForExistence(timeout: 4))
        XCTAssertTrue(reverse.label.contains("CB"))
        XCTAssertFalse(app.segmentedControls["tag-appearance-咲希&一歌"].exists)
        capture("swapped-cb-pair")
        app.swipeUp(); app.swipeUp()
        app.buttons["Reopen Stored Tags"].tap()
        XCTAssertTrue(app.staticTexts["pair-state"].label.contains("咲希&一歌"))
        app.swipeDown(); app.swipeDown()
        XCTAssertTrue(reverse.waitForExistence(timeout: 4))
        XCTAssertTrue(reverse.label.contains("CB"))
        capture("swapped-pair-reopened")
    }
    func testOrdinaryWhiteStyleAndReopen() {
        let app = XCUIApplication(); app.launchArguments = ["chinese", "white"]; app.launch()
        XCTAssertTrue(app.staticTexts["tag-label-星乃一歌"].waitForExistence(timeout: 6))
        app.buttons["标签颜色"].tap()
        for tag in ["星乃一歌", "世界计划", "Pure White"] {
            let appearance = app.segmentedControls["tag-appearance-" + tag]
            for _ in 0..<6 { if appearance.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(appearance.waitForExistence(timeout: 3))
            appearance.buttons["白底"].tap()
            XCTAssertTrue(appearance.buttons["白底"].isSelected)
        }
        capture("white-ordinary-custom")
        app.swipeUp(); app.swipeUp()
        app.buttons["Reopen Stored Tags"].tap()
        let state = app.staticTexts["appearance-state"]
        XCTAssertTrue(state.label.contains("星乃一歌:white:2"))
        XCTAssertTrue(state.label.contains("世界计划:white:6"))
        XCTAssertTrue(state.label.contains("Pure White:white:1"))
        for _ in 0..<6 { if app.segmentedControls["tag-appearance-星乃一歌"].isHittable { break }; app.swipeDown() }
        capture("white-ordinary-reopened")
        let appearance = app.segmentedControls["tag-appearance-星乃一歌"]
        appearance.buttons["实心"].tap()
        XCTAssertTrue(appearance.buttons["实心"].isSelected)
        app.swipeUp(); app.swipeUp(); app.swipeUp()
        XCTAssertTrue(state.label.contains("星乃一歌:filled:2"))
        XCTAssertTrue(state.label.contains("世界计划:white:6"))
    }
    func testOtherIPStaysSeparate() {
        let app = XCUIApplication(); app.launchArguments = ["chinese", "pairs"]; app.launch()
        let first = app.staticTexts["tag-label-星乃一歌"]
        let other = app.staticTexts["tag-label-高松灯"]
        XCTAssertTrue(first.waitForExistence(timeout: 6))
        first.press(forDuration: 0.8, thenDragTo: other)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertTrue(first.exists); XCTAssertTrue(other.exists)
        capture("other-ip-reorder")
    }





    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: directory.appendingPathComponent(name + ".png"))
        try? XCUIApplication().debugDescription.write(to: directory.appendingPathComponent(name + ".txt"), atomically: true, encoding: .utf8)
    }
    func testCustomPaletteNarrow() {
        let app = XCUIApplication(); app.launchArguments = ["narrow"]; app.launch()
        XCTAssertTrue(app.staticTexts["Storage passed"].waitForExistence(timeout: 10))
        app.buttons["Tag Colors"].tap()
        let custom = app.buttons["Custom"].firstMatch
        XCTAssertTrue(custom.waitForExistence(timeout: 3)); custom.tap()
        let field = app.textFields["tag-hex-0"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap(); field.press(forDuration: 1)
        field.doubleTap()
        if app.menuItems["Select All"].exists { app.menuItems["Select All"].tap() }
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12) + "#123456")
        app.swipeUp()
        capture("custom-narrow")
        XCTAssertTrue(app.staticTexts["stored-palette"].label.contains("#123456"))
    }
    func testSearchFavoritesAndRequest() {
        let app = XCUIApplication(); app.launch()
        app.buttons["Library"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("Saki")
        capture("ambiguous-search")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Leo/need")).firstMatch.waitForExistence(timeout: 3))
        if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
        else if app.buttons["close"].exists { app.buttons["close"].tap() }
        app.buttons["Done"].tap()
        app.buttons["New Request"].tap()
        let work = app.textFields["Work / IP"]
        XCTAssertTrue(work.waitForExistence(timeout: 3)); work.tap(); work.typeText("Example IP")
        let description = app.textViews.firstMatch
        if description.exists { description.tap(); description.typeText("Please add this character") }
        else { let field = app.textFields["tag-report-description"]; field.tap(); field.typeText("Please add this character") }
        capture("native-request")
        app.buttons["Submit"].tap()
        XCTAssertTrue(app.staticTexts["tag-report-receipt"].waitForExistence(timeout: 3))
    }
}
