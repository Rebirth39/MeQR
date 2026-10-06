import XCTest

final class LayoutTests: XCTestCase {
    let qq = "https://qm.qq.com/q/lNrSSk9uFy"
    override func setUp() { continueAfterFailure = false }
    func launch(_ args: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = args; app.launch()
        XCTAssertTrue(app.buttons["New Card"].waitForExistence(timeout: 10))
        return app
    }
    func waitLabel(_ app: XCUIApplication, id: String, value: String) {
        let e = app.staticTexts[id]
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", value), object: e)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 15), .completed, app.debugDescription)
    }
    func capture(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
        let tree = XCTAttachment(string: app.debugDescription); tree.name = name + "-tree"; tree.lifetime = .keepAlways; add(tree)
    }
    func checkReadback(_ app: XCUIApplication, cards: Int, profiles: Int) {
        let expected = "cards=\(cards);profiles=\(profiles);qq=1"
        waitLabel(app, id: "audit-store", value: expected)
        capture(app, "saved")
        app.terminate(); app.launchArguments = ["readback"]; app.launch()
        waitLabel(app, id: "audit-store", value: expected)
    }
    func reach(_ app: XCUIApplication, _ field: XCUIElement) {
        for _ in 0..<10 where !field.isHittable {
            let list = app.collectionViews.firstMatch
            let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.48))
            let end = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(field.isHittable, app.debugDescription)
    }
    func testModelRelationshipsAndPersistence() {
        let app = launch(["model-checks"])
        waitLabel(app, id: "model-result", value: "PASS: registration,inverse,idempotence,refetch,reparent,migration,backup,sync,cascade,preview")
    }
    func testNewCardManualQQSaveAndRelaunch() {
        let app = launch(); app.buttons["New Card"].tap()
        let name = app.textFields["卡片名称"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), app.debugDescription)
        name.tap(); name.typeText("QQ Regression")
        let input = app.textFields["URL 或文本"]
        reach(app, input); input.tap(); input.typeText(qq)
        app.navigationBars.buttons["保存"].tap()
        XCTAssertTrue(app.buttons["New Card"].waitForExistence(timeout: 5), app.debugDescription)
        checkReadback(app, cards: 1, profiles: 1)
    }
    func testAddQQToExistingCardAndRelaunch() {
        let app = launch(["existing"]); app.buttons["Add To Existing"].tap()
        let input = app.textFields["URL 或文本"]
        XCTAssertTrue(input.waitForExistence(timeout: 5)); reach(app, input); input.tap(); input.typeText(qq)
        app.navigationBars.buttons["保存"].tap()
        XCTAssertTrue(app.buttons["New Card"].waitForExistence(timeout: 5), app.debugDescription)
        checkReadback(app, cards: 1, profiles: 2)
    }
    func testNewCardImportedQQSaveAndRelaunch() {
        let app = launch(); app.buttons["New Card"].tap()
        let name = app.textFields["卡片名称"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Photo QQ")
        let mode = app.buttons["导入二维码图片"]
        reach(app, mode); mode.tap()
        let picker = app.buttons["选择二维码图片"]
        reach(app, picker); picker.tap()
        let photo = app.images["Photo, October 04, 21:25"].firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 8), app.debugDescription); photo.tap()
        if app.buttons["Continue"].exists { app.buttons["Continue"].tap() }
        let decoded = app.textFields.matching(NSPredicate(format: "value == %@", qq)).firstMatch
        reach(app, decoded)
        XCTAssertTrue(decoded.exists, app.debugDescription)
        capture(app, "photo-decoded-exact-qq")
        app.navigationBars.buttons["保存"].tap()
        XCTAssertTrue(app.buttons["New Card"].waitForExistence(timeout: 5), app.debugDescription)
        checkReadback(app, cards: 1, profiles: 1)
    }
    func testOnboardingPreviewBacktrackingAndSave() {
        let app = launch(); app.buttons["Guide"].tap()
        app.buttons["开始建档"].tap()
        let name = app.textFields["Miku39"]; XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Guide QQ")
        app.buttons["继续"].tap()
        app.buttons["从文本生成"].tap()
        let input = app.textFields["URL 或文本"]; XCTAssertTrue(input.waitForExistence(timeout: 5)); input.tap(); input.typeText(qq)
        app.buttons["继续"].tap()
        XCTAssertTrue(app.staticTexts["现在，让它看起来像你。"].waitForExistence(timeout: 5), app.debugDescription)
        waitLabel(app, id: "audit-store", value: "cards=0;profiles=0;qq=0")
        capture(app, "onboarding-appearance")
        app.buttons["明日方舟通行证"].tap()
        waitLabel(app, id: "audit-store", value: "cards=0;profiles=0;qq=0")
        capture(app, "onboarding-pass-preview")
        app.buttons["标准"].tap()
        // Re-entering the formerly crashing preview must not insert draft cards.
        app.buttons["上一步"].tap(); app.buttons["继续"].tap()
        app.buttons["继续"].tap(); app.buttons["继续"].tap()
        XCTAssertTrue(app.buttons["创建我的卡片"].waitForExistence(timeout: 5))
        waitLabel(app, id: "audit-store", value: "cards=0;profiles=0;qq=0")
        capture(app, "onboarding-final-preview")
        app.buttons["创建我的卡片"].tap()
        XCTAssertTrue(app.staticTexts["你的卡片，准备好了。"].waitForExistence(timeout: 5), app.debugDescription)
        checkReadback(app, cards: 1, profiles: 1)
    }
}
