import XCTest
import CoreImage
import Vision

final class LayoutTests: XCTestCase {
    func testPortraitRegularMatrix() throws { try matrix([]) }
    func testPortraitCompactMatrix() throws { try matrix(["compact"]) }
    func testLandscapeRegularMatrix() throws { try matrix(["short"]) }
    func testStandardRegularMatrix() throws { try matrix(["standard"]) }
    func testMintBackgroundRegularMatrix() throws { try matrix(["mint", "background"]) }
    func testLargeTypeRegularMatrix() throws { try matrix(["large"]) }
    func testRhodesPlatformSelectionInShortWindow() throws {
        let app=XCUIApplication();app.launch();app.buttons["Short"].tap();app.buttons["W320"].tap()
        let viewport=app.otherElements["viewport"]
        let qr=app.images["rhodes-qr-panel"]
        let wechat=app.buttons["微信"]
        reveal(wechat, in:viewport, app:app)
        XCTAssertTrue(wechat.isHittable)
        wechat.tap()
        reveal(qr, in:viewport, app:app)
        let image=XCUIScreen.main.screenshot().image
        let vf=viewport.frame
        let crop=image.cgImage!.cropping(to:CGRect(x:vf.minX*image.scale,y:vf.minY*image.scale,width:vf.width*image.scale,height:vf.height*image.scale))!
        XCTAssertTrue(try decode(UIImage(cgImage:crop)).contains("https://u.wechat.com/fixture"))
        let attachment=XCTAttachment(screenshot:XCUIScreen.main.screenshot());attachment.name="short-w320-selected-wechat";attachment.lifetime = .keepAlways;add(attachment)
    }
    private func reveal(_ element:XCUIElement, in viewport:XCUIElement, app:XCUIApplication) {
        let vf=viewport.frame
        for _ in 0..<5 {
            let ef=element.frame
            let amount:CGFloat
            if ef.maxY>vf.maxY-8 { amount=min(vf.height*0.5,ef.maxY-vf.maxY+12) }
            else if ef.minY<vf.minY+8 { amount = -min(vf.height*0.5,vf.minY+12-ef.minY) }
            else { break }
            let start=app.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:vf.midX,dy:vf.midY+amount/2))
            let end=app.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:vf.midX,dy:vf.midY-amount/2))
            start.press(forDuration:0.05,thenDragTo:end)
        }
    }
    func testExchangeCodeNarrowWindows() throws {
        let app=XCUIApplication();app.launchArguments=["exchange"];app.launch()
        for width in [320,375] {
            app.buttons["W\(width)"].tap()
            let viewport=app.otherElements["viewport"]
            let qr=app.images["exchange-code-qr"]
            XCTAssertTrue(qr.waitForExistence(timeout:5))
            reveal(qr,in:viewport,app:app)
            let vf=viewport.frame;let qf=qr.frame
            let screenshot=XCUIScreen.main.screenshot();let image=screenshot.image
            let crop=image.cgImage!.cropping(to:CGRect(x:vf.minX*image.scale,y:vf.minY*image.scale,width:vf.width*image.scale,height:vf.height*image.scale))!
            let codes=try decode(UIImage(cgImage:crop))
            XCTAssertTrue(codes.contains { $0.hasPrefix("https://profile.meqrcode.cn/encounter-sessions/") && $0.contains("#offline=") })
            XCTAssertGreaterThanOrEqual(qf.minX,vf.minX-1)
            XCTAssertLessThanOrEqual(qf.maxX,vf.maxX+1)
            let attachment=XCTAttachment(screenshot:screenshot);attachment.name="exchange-w\(width)";attachment.lifetime = .keepAlways;add(attachment)
        }
    }
    private func matrix(_ flags: [String]) throws {
        continueAfterFailure = true
        let app = XCUIApplication(); app.launchArguments = flags; app.launch()
        XCTAssertTrue(app.buttons["W320"].waitForExistence(timeout: 5))
        if flags.contains("short") { app.buttons["Short"].tap() }
        for width in [320,375,480,520,620,800,900] {
            app.buttons["W\(width)"].tap()
            let viewport = app.otherElements["viewport"]
            let qr = app.images[flags.contains("standard") ? "standard-card-qr" : "rhodes-qr-panel"]
            XCTAssertTrue(qr.waitForExistence(timeout: 3))
            let vf=viewport.frame
            for _ in 0..<3 where qr.frame.maxY > vf.maxY - 8 {
                let amount=min(vf.height * 0.6, qr.frame.maxY - vf.maxY + 16)
                let start=app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx:vf.midX,dy:vf.maxY-25))
                let end=app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx:vf.midX,dy:vf.maxY-25-amount))
                start.press(forDuration:0.05,thenDragTo:end)
            }
            let qf=qr.frame
            let screenshot=XCUIScreen.main.screenshot()
            let attachment=XCTAttachment(screenshot:screenshot);attachment.name="\(flags.joined(separator:"-"))-w\(width)";attachment.lifetime = .keepAlways;add(attachment)
            let hierarchy=XCTAttachment(string: app.debugDescription);hierarchy.name="hierarchy-w\(width)";hierarchy.lifetime = .keepAlways;add(hierarchy)
            let image=screenshot.image
            let crop=image.cgImage!.cropping(to:CGRect(x:vf.minX*image.scale,y:vf.minY*image.scale,width:vf.width*image.scale,height:vf.height*image.scale))!
            let codes=try decode(UIImage(cgImage:crop))
            print("WINDOW_CHECK flags=\(flags) width=\(width) viewport=\(vf) qr=\(qf) screenshot=\(image.size) scale=\(image.scale) codes=\(codes)")
            XCTAssertGreaterThanOrEqual(qf.minX,vf.minX-1)
            XCTAssertLessThanOrEqual(qf.maxX,vf.maxX+1)
            XCTAssertLessThanOrEqual(qf.maxY,vf.maxY+1)
            XCTAssertTrue(codes.contains("https://qm.qq.com/q/lNrSSk9uFy"),"Visible QR must decode at width \(width)")
            let wechat=app.buttons["微信"]
            for _ in 0..<3 where wechat.frame.maxY > vf.maxY - 8 {
                let amount=min(vf.height*0.5,wechat.frame.maxY-vf.maxY+16)
                let start=app.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:vf.midX,dy:vf.maxY-25))
                let end=app.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:vf.midX,dy:vf.maxY-25-amount))
                start.press(forDuration:0.05,thenDragTo:end)
            }
            XCTAssertTrue(wechat.isHittable,"WeChat reachable at width \(width)")
        }
    }
    private func decode(_ image: UIImage) throws -> [String] {
        let request=VNDetectBarcodesRequest();request.symbologies=[.qr]
        do { try VNImageRequestHandler(cgImage:image.cgImage!,options:[:]).perform([request]) } catch { print("VISION_UNAVAILABLE \(error)") }
        let vision=request.results?.compactMap(\.payloadStringValue) ?? []
        let detector=CIDetector(ofType:CIDetectorTypeQRCode,context:nil,options:[CIDetectorAccuracy:CIDetectorAccuracyHigh])!
        let core=detector.features(in:CIImage(image:image)!).compactMap { ($0 as? CIQRCodeFeature)?.messageString }
        return Array(Set(vision+core))
    }
}
