import XCTest

@MainActor
final class ParrotiOSUITests: XCTestCase {
    func testUnderstandToExpressFlowPreservesDraft() {
        let app = launchApp()

        app.tabBars.buttons["Understand"].tap()
        XCTAssertTrue(app.navigationBars["Understand"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textViews["UnderstandSourceEditor"].waitForExistence(timeout: 5))

        app.buttons["Reply"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Express"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Generate replies"].exists)
        XCTAssertTrue(app.textViews["ExpressIntentEditor"].exists)
    }

    func testReplyComposerToneSwitchingAndCopyFeedback() {
        let app = launchApp()

        app.tabBars.buttons["Express"].tap()
        XCTAssertTrue(app.navigationBars["Express"].waitForExistence(timeout: 5))
        app.buttons["Friendly"].tap()
        app.buttons["Generate replies"].tap()

        XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 5))
        app.buttons["Copy"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Copied"].waitForExistence(timeout: 3))
    }

    func testOCRCleanupMutatesTextAndKeepsDraftEditable() {
        let app = launchApp(arguments: ["--ui-test-ocr"])

        XCTAssertTrue(app.staticTexts["OCR Cleanup"].waitForExistence(timeout: 5))
        let editor = app.textViews["OCRTextEditor"]
        XCTAssertTrue(editor.exists)
        XCTAssertTrue(String(describing: editor.value ?? "").contains("@confused_user"))
        XCTAssertTrue(app.buttons["OCRCopySource"].exists)

        app.buttons["Remove usernames"].tap()
        XCTAssertTrue(app.staticTexts["OCR text cleaned"].waitForExistence(timeout: 3))
        XCTAssertFalse(String(describing: editor.value ?? "").contains("@confused_user"))
        app.buttons["OCRCopySource"].tap()
        XCTAssertTrue(app.staticTexts["Copied"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Understand"].exists)
    }

    func testHistoryItemReopensEditableSession() {
        let app = launchApp(arguments: ["--ui-test-history"])

        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "History seed")).firstMatch.tap()

        XCTAssertTrue(app.navigationBars["Understand"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textViews["UnderstandSourceEditor"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["UnderstandCopySource"].exists)
        XCTAssertTrue(app.staticTexts["UnderstandTranslation"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["UnderstandCopyTranslation"].exists)
    }

    func testQuickLensAutoTranslatesFixtureAndSwitchesCandidate() {
        let app = launchApp(arguments: ["--ui-test-quick-lens"])

        XCTAssertTrue(app.otherElements["QuickLensView"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["QuickLensCopySource"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["QuickLensTranslation"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["QuickLensCopyTranslation"].exists)
        XCTAssertTrue(app.staticTexts["QuickLensMeaning"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "产品有价值")).firstMatch.exists)

        let second = app.buttons["QuickLensCandidate1"].firstMatch
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        second.tap()

        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "ship the feature")).firstMatch.waitForExistence(timeout: 5))
    }

    func testQuickLensEditSourceKeepsEditablePath() {
        let app = launchApp(arguments: ["--ui-test-quick-lens"])

        XCTAssertTrue(app.otherElements["QuickLensView"].waitForExistence(timeout: 5))
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.textViews["QuickLensSourceEditor"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Rerun Explain"].exists)
    }

    func testCopyRecognizedAndTranslatedTextShowsFeedback() {
        let app = launchApp(arguments: ["--ui-test-quick-lens"])

        XCTAssertTrue(app.otherElements["QuickLensView"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["QuickLensCopySource"].waitForExistence(timeout: 5))
        app.buttons["QuickLensCopySource"].tap()
        XCTAssertTrue(app.staticTexts["Copied"].waitForExistence(timeout: 3))

        XCTAssertTrue(app.buttons["QuickLensCopyTranslation"].waitForExistence(timeout: 5))
        app.buttons["QuickLensCopyTranslation"].tap()
        XCTAssertTrue(app.staticTexts["Copied"].waitForExistence(timeout: 3))
    }

    func testQuickLensNoRecentScreenshotRecovery() {
        let app = launchApp(arguments: ["--ui-test-quick-lens-empty"])

        XCTAssertTrue(app.otherElements["QuickLensView"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["QuickLensNoRecent"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Try latest screenshot again"].exists)
        XCTAssertTrue(app.buttons["Enter text manually"].exists)
    }

    func testQuickLensPermissionRecovery() {
        let app = launchApp(arguments: ["--ui-test-quick-lens-permission"])

        XCTAssertTrue(app.otherElements["QuickLensView"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Photos access needed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Open Settings"].exists)
        XCTAssertTrue(app.buttons["Enter text manually"].exists)
    }

    private func launchApp(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-offline-social"] + arguments
        app.launch()
        return app
    }
}
