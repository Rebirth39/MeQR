import XCTest
import CoreImage

final class LayoutTests: XCTestCase {
    func testRhodesFrontTagsAndInsetQRCodeRemainUsable() {
        for narrow in [false, true] {
            let app = XCUIApplication()
            app.launchArguments = ["rhodes-front", "tags"] + (narrow ? ["narrow"] : [])
            app.launch()
            let qr = app.images["rhodes-qr-panel"]
            XCTAssertTrue(qr.waitForExistence(timeout: 5))
            let tag = app.staticTexts["世界计划"]
            for _ in 0..<3 where !tag.isHittable { app.swipeUp() }
            XCTAssertTrue(tag.isHittable)
            XCTAssertGreaterThan(tag.frame.minY, qr.frame.maxY)
            XCTAssertTrue(app.buttons["微信"].isHittable)
            let wechat = app.buttons["微信"].frame
            XCTAssertLessThanOrEqual(wechat.maxX, app.frame.maxX)
            XCTAssertGreaterThanOrEqual(wechat.minX, app.frame.minX)
            if narrow { XCTAssertGreaterThan(wechat.minY, qr.frame.maxY) }
            XCTAssertEqual(qr.frame.width, 170, accuracy: 1)
            let screenshot = XCUIScreen.main.screenshot()
            let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])!
            let codes = detector.features(in: CIImage(image: screenshot.image)!).compactMap { ($0 as? CIQRCodeFeature)?.messageString }
            XCTAssertTrue(codes.contains("https://qm.qq.com/q/lNrSSk9uFy"), "Displayed QR must still decode")
            capture(narrow ? "rhodes-front-narrow" : "rhodes-front")
            app.buttons["微信"].tap()
            XCTAssertTrue(tag.isHittable, "Platform selection must keep front tags visible")
            app.terminate()
        }
    }
    func testEncounterBackgroundKeepsTopVisibleAndScrollDoesNotDismiss() {
        for large in [false, true] {
            let app = XCUIApplication()
            app.launchArguments = ["scanner-sheet", "preview-images", "long"] + (large ? ["large"] : [])
            app.launch()
            app.buttons["Scan session fixture"].tap()
            let name = app.staticTexts["encounter-preview-name"]
            XCTAssertTrue(name.waitForExistence(timeout: 5))
            XCTAssertTrue(name.isHittable)
            XCTAssertGreaterThanOrEqual(name.frame.minY, app.navigationBars["发现 MeQR 名片"].frame.maxY)
            capture(large ? "preview-large-top" : "preview-top")
            app.swipeDown()
            XCTAssertTrue(app.navigationBars["发现 MeQR 名片"].exists, "Scrolling must not return to scanner")
            for _ in 0..<5 where !app.buttons["保存记录"].isHittable { app.swipeUp() }
            XCTAssertTrue(app.buttons["保存记录"].isHittable)
            capture(large ? "preview-large-bottom" : "preview-bottom")
            for _ in 0..<5 where !name.isHittable { app.swipeDown() }
            XCTAssertTrue(name.isHittable)
            app.navigationBars["发现 MeQR 名片"].buttons["取消"].tap()
            XCTAssertTrue(app.buttons["Scan session fixture"].exists)
            app.terminate()
        }
    }

    func testEncounterPlatformButtonsOpenTrustedDestinationsWithoutReview() {
        for (platform, expected) in [("QQ", "https://qm.qq.com/q/fixture"), ("微信", "weixin://scanqrcode"), ("GitHub", "https://github.com/fixture")] {
            let app = XCUIApplication()
            app.launchArguments = ["scanner-sheet", "preview-images", "long"]
            app.launch()
            app.buttons["Scan session fixture"].tap()
            XCTAssertTrue(app.staticTexts["encounter-preview-name"].waitForExistence(timeout: 5))
            for _ in 0..<4 where !app.buttons[platform].isHittable { app.swipeUp() }
            app.buttons[platform].tap()
            let open = app.buttons["交换的平台 · " + platform]
            for _ in 0..<4 where !open.isHittable { app.swipeUp() }
            open.tap()
            XCTAssertTrue(app.navigationBars["发现 MeQR 名片"].exists)
            app.navigationBars["发现 MeQR 名片"].buttons["取消"].tap()
            XCTAssertEqual(app.staticTexts["last-opened-url"].label, expected)
            app.terminate()
        }
    }

    func testEncounterUnknownDestinationStillRequiresReview() {
        let app = XCUIApplication()
        app.launchArguments = ["scanner-sheet", "preview-images", "untrusted-link"]
        app.launch()
        app.buttons["Scan session fixture"].tap()
        XCTAssertTrue(app.staticTexts["encounter-preview-name"].waitForExistence(timeout: 5))
        for _ in 0..<4 where !app.buttons["GitHub"].isHittable { app.swipeUp() }
        app.buttons["GitHub"].tap()
        let open = app.buttons["交换的平台 · GitHub"]
        for _ in 0..<4 where !open.isHittable { app.swipeUp() }
        open.tap()
        XCTAssertTrue(app.staticTexts["github.com.evil.test"].waitForExistence(timeout: 5))
    }

    func testREDRedirectsValidateEveryHop() {
        let app = XCUIApplication()
        app.launchArguments = ["redirect-test"]
        app.launch()
        XCTAssertTrue(app.staticTexts["RED redirects passed"].waitForExistence(timeout: 30), app.staticTexts["redirect-result"].label)
    }
    func testFirstScannerPreviewSavesMatchingSession() {
        let app = XCUIApplication()
        app.launchArguments = ["scanner-sheet"]
        app.launch()
        XCTAssertTrue(app.buttons["Scan session fixture"].waitForExistence(timeout: 5))
        app.buttons["Scan session fixture"].tap()
        let save = app.buttons["保存记录"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertEqual(app.staticTexts["saved-session"].label, "NativeSheet01")
    }
    func testOfflineScannerPreviewKeepsSessionAndQueuesOnlyShortIntro() {
        let app = XCUIApplication()
        app.launchArguments = ["scanner-sheet", "offline-scan", "custom-subtitle"]
        app.launch()
        XCTAssertTrue(app.buttons["Scan session fixture"].waitForExistence(timeout: 5))
        app.buttons["Scan session fixture"].tap()
        let save = app.buttons["保存记录"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertEqual(app.staticTexts["saved-session"].label, "NativeSheet01")
        XCTAssertEqual(app.staticTexts["pending-intro"].label, "Only shared intro")
    }
    func testEncounterDeliverySurvivesFailureAndSupportsRelease110() {
        let app = XCUIApplication()
        app.launchArguments = ["encounter-delivery"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Encounter delivery and 1.1.0 compatibility passed"].waitForExistence(timeout: 15))
    }
    func testExchangeUsesFullOnlineAndConfiguredOfflineIntroductions() {
        let app = XCUIApplication()
        app.launchArguments = ["exchange-ui", "custom-subtitle"]
        app.launch()
        app.buttons["Exchange"].tap()
        XCTAssertTrue(app.staticTexts["交换码已保存，在线与离线使用同一码。"].waitForExistence(timeout: 10))
        app.buttons["完成"].tap()
        let result = app.staticTexts["subtitle-result"]
        XCTAssertTrue(result.waitForExistence(timeout: 3))
        let expected = "Full card introduction\nSecond line belongs online\nThird line also belongs online|Only shared intro|"
        XCTAssertEqual(result.label, expected)
        let firstCode = app.staticTexts["exchange-result"].label
        app.buttons["Seed incorrect online intro"].tap()
        app.buttons["Exchange"].tap()
        XCTAssertTrue(app.staticTexts["交换码已保存，在线与离线使用同一码。"].waitForExistence(timeout: 10))
        app.buttons["完成"].tap()
        XCTAssertEqual(result.label, expected)
        let repairedCode = app.staticTexts["exchange-result"].label
        XCTAssertNotEqual(repairedCode, firstCode)
        XCTAssertTrue(repairedCode.hasSuffix(":2"))
        app.buttons["Exchange"].tap()
        XCTAssertTrue(app.staticTexts["交换码已保存，在线与离线使用同一码。"].waitForExistence(timeout: 10))
        app.buttons["完成"].tap()
        XCTAssertEqual(app.staticTexts["exchange-result"].label, repairedCode)
        XCTAssertEqual(result.label, expected)
    }

    func testEncounterSyncKeepsOriginalEvent() {
        let app = XCUIApplication()
        app.launchArguments = ["encounter-sync"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Encounter event sync passed"].waitForExistence(timeout: 10))
    }

    func testExchangeScreenReusesCodeAndUpdatesOnEdit() {
        let app = XCUIApplication()
        app.launchArguments = ["exchange-ui"]
        app.launch()
        app.buttons["Exchange"].tap()
        XCTAssertTrue(app.staticTexts["交换码已保存，在线与离线使用同一码。"].waitForExistence(timeout: 10))
        app.buttons["完成"].tap()
        let result = app.staticTexts["exchange-result"]
        XCTAssertTrue(result.waitForExistence(timeout: 3))
        let first = result.label
        app.buttons["Exchange"].tap()
        XCTAssertTrue(app.staticTexts["交换码已保存，在线与离线使用同一码。"].waitForExistence(timeout: 5))
        app.buttons["完成"].tap()
        XCTAssertEqual(result.label, first)
        app.buttons["Change name"].tap()
        app.buttons["Exchange"].tap()
        XCTAssertTrue(app.staticTexts["交换码已保存，在线与离线使用同一码。"].waitForExistence(timeout: 5))
        app.buttons["完成"].tap()
        XCTAssertNotEqual(result.label, first)
        XCTAssertTrue(result.label.hasSuffix(":2"))
    }
    func testExchangeCachePersistsWithoutChangingPayload() {
        let app = XCUIApplication()
        app.launchArguments = ["exchange"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Exchange cache passed"].waitForExistence(timeout: 10))
    }

    func testExchangeScreenUsesReadableCodeScale() {
        let app = XCUIApplication()
        app.launchArguments = ["exchange-ui"]
        app.launch()
        app.buttons["Exchange"].tap()
        let qr = app.images["exchange-code-qr"]
        XCTAssertTrue(qr.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(qr.frame.width, 210)
        XCTAssertLessThan(qr.frame.width, 235)
        XCTAssertTrue(app.buttons["保存交换码到相册"].isHittable)
        capture("exchange-code-scale")
    }

    func testShortCardAndStablePaging() {
        let app = XCUIApplication()
        app.launch()
        let name = app.staticTexts["重生 Rebirth"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let originalName = name.frame
        let originalQR = app.images["standard-card-qr"].frame
        XCTAssertLessThan(originalQR.minY - originalName.maxY, 35)
        app.buttons["Toggle second"].tap()
        XCTAssertEqual(name.frame.minY, originalName.minY, accuracy: 1)
        XCTAssertEqual(app.images["standard-card-qr"].frame.minY, originalQR.minY, accuracy: 1)
        capture("short-two-cards")
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["Second"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["Second"].frame.minY, originalName.minY, accuracy: 1)
        app.swipeRight()
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        app.buttons["Toggle second"].tap()
        XCTAssertEqual(name.frame.minY, originalName.minY, accuracy: 1)
        capture("short-one-card")
    }

    func testLongInfoAndTags() {
        let app = XCUIApplication()
        app.launchArguments = ["long", "tags"]
        app.launch()
        let tag = app.staticTexts["世界计划"]
        XCTAssertTrue(tag.waitForExistence(timeout: 5))
        let info = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "生理男")).firstMatch
        XCTAssertGreaterThan(tag.frame.minY, info.frame.maxY)
        XCTAssertLessThan(tag.frame.minY - info.frame.maxY, 25)
        XCTAssertTrue(app.buttons["微信"].isHittable)
        capture("long-info-tags")
    }

    func testNarrowLargeTextCanReachQR() {
        let app = XCUIApplication()
        app.launchArguments = ["long", "tags", "narrow", "large"]
        app.launch()
        XCTAssertTrue(app.staticTexts["重生 Rebirth"].waitForExistence(timeout: 5))
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(app.buttons["微信"].isHittable)
        let qr = app.images["standard-card-qr"]
        XCTAssertTrue(qr.isHittable)
        XCTAssertEqual(qr.frame.width, 180, accuracy: 1)
        capture("narrow-large-scrolled")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
