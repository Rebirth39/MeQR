import XCTest

final class LayoutTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testReturningToCardEditsSelectedPlatform() {
        let app = launch()
        selectWechatAndReturn(app)
        openMenu(app, action: "编辑二维码")
        XCTAssertTrue(app.navigationBars["编辑二维码"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.textFields.firstMatch.value as? String, "https://u.wechat.com/audit")
        capture("return-edits-wechat", app)
    }

    func testReturningToCardDeletesSelectedPlatform() {
        let app = launch()
        selectWechatAndReturn(app)
        openMenu(app, action: "删除卡片")
        app.buttons["删除这个二维码"].tap()
        let deletion = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS 'profiles=3'"),
            object: app.staticTexts["audit-store"]
        )
        XCTAssertEqual(XCTWaiter.wait(for: [deletion], timeout: 3), .completed)
        openMenu(app, action: "编辑二维码")
        XCTAssertTrue(app.navigationBars["编辑二维码"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.textFields.firstMatch.value as? String, "https://qm.qq.com/q/audit")
        capture("return-deletes-wechat-keeps-qq", app)
    }

    func testDeletingQRCancelPreservesStoredProfiles() {
        let app = launch()
        openMenu(app, action: "编辑卡片")
        deleteRow(app, content: "https://u.wechat.com/audit")
        XCTAssertTrue(app.staticTexts["audit-store"].label.contains("profiles=4"))
        cancelAndDiscard(app)
        XCTAssertTrue(app.staticTexts["Audit One"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["微信"].exists)
        openMenu(app, action: "编辑卡片")
        scrollToRow(app, content: "https://u.wechat.com/audit")
        capture("cancel-preserves-wechat", app)
    }

    func testDeletingQRSaveCommitsAndKeepsWidgetPlatform() {
        let app = launch(["three"])
        app.buttons["微信"].tap()
        openMenu(app, action: "编辑卡片")
        deleteRow(app, content: "https://qm.qq.com/q/audit")
        XCTAssertTrue(app.staticTexts["audit-store"].label.contains("profiles=6"))
        app.navigationBars["编辑卡片"].buttons["保存"].tap()
        XCTAssertTrue(app.staticTexts["Audit One"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["audit-store"].label.contains("profiles=5;widget=1"))
        openMenu(app, action: "编辑二维码")
        XCTAssertTrue(app.navigationBars["编辑二维码"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.textFields.firstMatch.value as? String, "https://u.wechat.com/audit")
        capture("save-deletes-qq-keeps-selected-wechat", app)
    }

    func testDeletingLastQRCancelKeepsCard() {
        let app = launch(["single"])
        openMenu(app, action: "编辑卡片")
        deleteRow(app, content: "https://qm.qq.com/q/audit")
        XCTAssertTrue(app.navigationBars["编辑卡片"].exists)
        XCTAssertTrue(app.staticTexts["audit-store"].label.contains("clusters=2;profiles=2"))
        cancelAndDiscard(app)
        XCTAssertTrue(app.staticTexts["Audit One"].waitForExistence(timeout: 3))
        capture("last-qr-cancel-keeps-card", app)
    }

    func testDeletingLastQRSaveDeletesOnlyThatCard() {
        let app = launch(["single"])
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["Audit Two"].waitForExistence(timeout: 3))
        openMenu(app, action: "编辑卡片")
        deleteRow(app, content: "https://qm.qq.com/q/audit")
        app.navigationBars["编辑卡片"].buttons["保存"].tap()
        XCTAssertTrue(app.staticTexts["Audit One"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["audit-store"].label.contains("clusters=1;profiles=1"))
        capture("last-page-save-removes-card", app)
    }

    func testDeletingLastQRInSyncedCardRequiresStoppingSync() {
        let app = launch(["single", "synced"])
        openMenu(app, action: "编辑卡片")
        deleteRow(app, content: "https://qm.qq.com/q/audit")
        app.navigationBars["编辑卡片"].buttons["保存"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.alerts.staticTexts.containing(NSPredicate(format: "label CONTAINS '停止此卡片的同步'")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["audit-store"].label.contains("clusters=2;profiles=2"))
        capture("synced-card-delete-blocked", app)
        app.alerts.buttons.firstMatch.tap()
        cancelAndDiscard(app)
        XCTAssertTrue(app.staticTexts["Audit One"].waitForExistence(timeout: 3))
    }

    func testEditCancelConfirmsDiscard() {
        let app = launch()
        openMenu(app, action: "编辑卡片")
        XCTAssertTrue(app.navigationBars["编辑卡片"].waitForExistence(timeout: 3))
        app.navigationBars["编辑卡片"].buttons["取消"].tap()
        XCTAssertTrue(app.staticTexts["Audit One"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.alerts.firstMatch.exists, "A clean edit must close without a prompt")

        openMenu(app, action: "编辑卡片")
        let name = app.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("X")
        app.navigationBars["编辑卡片"].buttons["取消"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 3))
        app.alerts.buttons["继续编辑"].tap()
        XCTAssertTrue(app.navigationBars["编辑卡片"].exists)
        app.swipeDown()
        XCTAssertTrue(app.navigationBars["编辑卡片"].exists, "Dirty edits must not dismiss by swipe")
        app.navigationBars["编辑卡片"].buttons["取消"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 3))
        app.alerts.buttons["放弃更改"].tap()
        XCTAssertTrue(app.staticTexts["Audit One"].waitForExistence(timeout: 3))
        capture("edit-cancel-confirms-discard", app)
    }

    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(app.staticTexts["Audit One"].waitForExistence(timeout: 5))
        return app
    }

    private func selectWechatAndReturn(_ app: XCUIApplication) {
        app.buttons["微信"].tap()
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["Audit Two"].waitForExistence(timeout: 3))
        app.swipeRight()
        XCTAssertTrue(app.staticTexts["Audit One"].waitForExistence(timeout: 3))
    }

    private func openMenu(_ app: XCUIApplication, action: String) {
        // iOS 27 exposes Menu as PopUpButton and localizes its SF Symbol label.
        let menu = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier == 'line.3.horizontal.circle' OR label == 'Three Horizontal Lines In A Circle'"
        )).firstMatch
        menu.tap()
        app.buttons[action].tap()
    }

    private func cancelAndDiscard(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        app.navigationBars["编辑卡片"].buttons["取消"].tap()
        if app.alerts.firstMatch.waitForExistence(timeout: 1.5) {
            let discard = app.alerts.buttons["放弃更改"].exists
                ? app.alerts.buttons["放弃更改"] : app.alerts.buttons.element(boundBy: 0)
            discard.tap()
        }
    }

    private func row(_ app: XCUIApplication, content: String) -> XCUIElement {
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", content)).firstMatch
    }

    private func deleteRow(_ app: XCUIApplication, content: String) {
        let qr = scrollToRow(app, content: content)
        qr.swipeLeft()
        let delete = app.buttons["Delete"].firstMatch.exists
            ? app.buttons["Delete"].firstMatch : app.buttons["删除"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 2))
        delete.tap()
    }

    @discardableResult
    private func scrollToRow(_ app: XCUIApplication, content: String) -> XCUIElement {
        XCTAssertTrue(app.navigationBars["编辑卡片"].waitForExistence(timeout: 3))
        let qr = row(app, content: content)
        for _ in 0..<7 where !qr.isHittable { app.swipeUp() }
        XCTAssertTrue(qr.isHittable, app.debugDescription)
        return qr
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = name + "-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }
}
