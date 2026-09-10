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
