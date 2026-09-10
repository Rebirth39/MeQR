import XCTest

final class LayoutTests: XCTestCase {
    func testTagWeightLayout() {
        let app = XCUIApplication()
        app.launchArguments = ["weights", "narrow"]
        app.launch()
        for index in 0..<4 {
            let button = app.buttons["weight-cycle"]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            XCTAssertEqual(button.label, "Weight \(index % 3)")
            XCTAssertTrue(app.staticTexts["tag-label-Project SEKAI"].exists)
            assertScreenBounds(app)
            attach(app, "tag-weight-\(index % 3)")
            button.tap()
        }
    }
    func testQRDestinationConsent() {
        let app = XCUIApplication()
        app.launchArguments = ["qr-review", "unsafe"]
        app.launch()
        app.buttons["Review"].tap()
        XCTAssertTrue(app.staticTexts["javascript:alert(1)"].exists)
        XCTAssertFalse(app.buttons["Open"].exists)
        attach(app, "qr-unsafe")
        app.buttons["Cancel"].tap()
        XCTAssertEqual(app.staticTexts["opened"].label, "none")
        app.terminate()
        app.launchArguments = ["qr-review"]
        app.launch()
        app.buttons["Review"].tap()
        XCTAssertTrue(app.staticTexts["example.com"].exists)
        XCTAssertTrue(app.staticTexts["https://example.com/path?qq.com"].exists)
        attach(app, "qr-destination")
        app.buttons["Open"].tap()
        XCTAssertEqual(app.staticTexts["opened"].label, "https://example.com/path?qq.com")
    }

    func testProductionSELocalizedWelcome() {
        for (language, startLabel) in [("zhHans", "开始建档"), ("ja", "カードを作る")] {
            let app = XCUIApplication(bundleIdentifier: "com.lucasli.meqr")
            app.launchArguments = ["-app_language", language]
            app.launch()
            let start = app.buttons[startLabel]
            XCTAssertTrue(start.waitForExistence(timeout: 10))
            assertScreenBounds(app)
            attach(app, "se-welcome-" + language)
            start.tap()
            XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
            assertScreenBounds(app)
            attach(app, "se-identity-" + language)
            app.terminate()
        }
    }

    func testProductionSEOnboarding() {
        let app = XCUIApplication(bundleIdentifier: "com.lucasli.meqr")
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-app_language", "en"]
        app.launch()
        let start = app.buttons["开始建档"].exists ? app.buttons["开始建档"] : app.buttons["Start My Card"]
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        assertScreenBounds(app)
        attach(app, "se-welcome")
        start.tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        assertScreenBounds(app)
        attach(app, "se-identity")
        field.tap()
        field.typeText("SE Test")
        assertScreenBounds(app)
        attach(app, "se-identity-keyboard")
        app.buttons["Continue"].tap()
        app.buttons["Generate from Text"].tap()
        let qr = app.textFields["URL or text to encode"]
        XCTAssertTrue(qr.waitForExistence(timeout: 5))
        qr.tap()
        qr.typeText("https://example.com")
        app.buttons["Continue"].tap()
        assertScreenBounds(app)
        attach(app, "se-appearance")
        app.buttons["Continue"].tap()
        assertScreenBounds(app)
        attach(app, "se-tags")
        app.buttons["Continue"].tap()
        assertScreenBounds(app)
        attach(app, "se-preview")
    }

    private func assertScreenBounds(_ app: XCUIApplication) {
        let width = app.frame.width
        for element in app.staticTexts.allElementsBoundByIndex + app.buttons.allElementsBoundByIndex + app.textFields.allElementsBoundByIndex {
            guard element.exists else { continue }
            let frame = element.frame
            guard element.isHittable, frame.width > 0 else { continue }
            XCTAssertGreaterThanOrEqual(frame.minX, -1, element.label)
            XCTAssertLessThanOrEqual(frame.maxX, width + 1, element.label)
        }
    }

    func testNativeReportMenuAndForm() {
        let app = XCUIApplication()
        app.launchArguments = ["report"]
        app.launch()
        let tag = app.buttons["Project SEKAI"]
        XCTAssertTrue(tag.waitForExistence(timeout: 10))
        tag.press(forDuration: 1)
        app.buttons["Report Tag Issue"].tap()
        XCTAssertFalse(app.buttons["Submit"].isEnabled)
        let description = app.textViews["tag-report-description"]
        let field = description.exists ? description : app.textFields["tag-report-description"]
        field.tap()
        field.typeText("Wrong colors")
        attach(app, "native-report-form")
        app.buttons["Submit"].tap()
        let receipt = app.descendants(matching: .any)["tag-report-receipt"].firstMatch
        XCTAssertTrue(receipt.waitForExistence(timeout: 5))
        XCTAssertTrue(receipt.label.contains("MEQR-20260907-ABCDEF"))
        attach(app, "native-report-receipt")
        app.buttons["Done"].tap()
        XCTAssertEqual(app.staticTexts["selections"].label, "Selections: 0")
    }

    func assertLayout(_ app: XCUIApplication, compact: Bool = true) {
        let collection = app.collectionViews["selected-tags"]
        let cells = collection.cells.allElementsBoundByIndex.sorted {
            abs($0.frame.minY - $1.frame.minY) < 1 ? $0.frame.minX < $1.frame.minX : $0.frame.minY < $1.frame.minY
        }
        XCTAssertFalse(cells.isEmpty)
        var previous: CGRect?
        for cell in cells {
            let frame = cell.frame
            if let previous, abs(previous.minY - frame.minY) < 1 {
                XCTAssertEqual(frame.minX - previous.maxX, 7, accuracy: 1)
            } else {
                XCTAssertEqual(frame.minX, collection.frame.minX, accuracy: 1)
            }
            if compact { XCTAssertLessThanOrEqual(frame.height, 26) }
            XCTAssertLessThanOrEqual(frame.maxX, collection.frame.maxX + 1)
            previous = frame
        }
        XCTAssertLessThan(collection.frame.maxY, app.staticTexts["following"].frame.minY)
    }

    func testCompactLayoutAndDrag() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["tag-label-Hatsune Miku"].waitForExistence(timeout: 10))
        assertLayout(app)
        attach(app, "compact-before")
        let before = app.staticTexts["order"].label
        app.staticTexts["tag-label-Hatsune Miku"].press(forDuration: 1, thenDragTo: app.staticTexts["tag-label-maimai 14500+"], withVelocity: .slow, thenHoldForDuration: 1)
        XCTAssertNotEqual(app.staticTexts["order"].label, before)
        XCTAssertEqual(Set(app.staticTexts["order"].label.components(separatedBy: "|")).count, 7)
        assertLayout(app)
        attach(app, "compact-after-drag")
        app.buttons["tag-remove-Project SEKAI"].tap()
        XCTAssertEqual(app.staticTexts["order"].label.components(separatedBy: "|").count, 6)
        assertLayout(app)
    }

    func testNarrowLayout() {
        let app = XCUIApplication()
        app.launchArguments = ["narrow"]
        app.launch()
        XCTAssertTrue(app.staticTexts["tag-label-Hatsune Miku"].waitForExistence(timeout: 10))
        assertLayout(app)
        attach(app, "narrow")
    }

    func testLargerTextLayout() {
        let app = XCUIApplication()
        app.launchArguments = ["large"]
        app.launch()
        XCTAssertTrue(app.staticTexts["tag-label-Hatsune Miku"].waitForExistence(timeout: 10))
        assertLayout(app, compact: false)
        attach(app, "larger-text")
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
