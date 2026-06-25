import XCTest

@MainActor
final class ParrotiOSUITests: XCTestCase {
    func testUnderstandToExpressFlowPreservesDraft() {
        let app = launchApp()

        app.buttons["TabWork"].tap()
        XCTAssertTrue(app.staticTexts["Workspace"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textViews["UnderstandSourceEditor"].waitForExistence(timeout: 5))

        app.buttons["WorkspaceModeReply"].tap()
        XCTAssertTrue(app.buttons["Generate replies"].exists)
        XCTAssertTrue(app.textViews["ExpressIntentEditor"].exists)
    }

    func testReplyComposerToneSwitchingAndCopyFeedback() {
        let app = launchApp(arguments: ["--ui-test-work"])

        XCTAssertTrue(app.staticTexts["Workspace"].waitForExistence(timeout: 5))
        app.buttons["WorkspaceModeReply"].tap()
        XCTAssertTrue(app.textViews["ExpressIntentEditor"].waitForExistence(timeout: 5))
        app.buttons["Friendly"].tap()
        app.buttons["Generate replies"].tap()

        XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 5))
        app.buttons["Copy"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Copied"].waitForExistence(timeout: 3))
    }

    func testNativePolishReplacesDraft() {
        let app = launchApp(arguments: ["--ui-test-polish"])

        XCTAssertTrue(app.staticTexts["Workspace"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["WorkspaceModePolish"].exists)
        XCTAssertTrue(app.staticTexts["NativePolishPrimary"].waitForExistence(timeout: 5))

        app.buttons["NativePolishReplaceDraftPrimary"].tap()
        XCTAssertTrue(app.staticTexts["Draft replaced"].waitForExistence(timeout: 3))

        let editor = app.textViews["UnderstandSourceEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertTrue(String(describing: editor.value ?? "").contains("onboarding"))
    }

    func testNativePolishTodayEntryOpensEditablePolishWorkspace() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["Parrot"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["NativePolishButton"].waitForExistence(timeout: 5))
        app.buttons["NativePolishButton"].tap()

        XCTAssertTrue(app.staticTexts["Workspace"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["WorkspaceModePolish"].exists)
        XCTAssertTrue(app.textViews["UnderstandSourceEditor"].exists)
        XCTAssertTrue(app.buttons["NativePolishRun"].exists)

        app.buttons["NativePolishRun"].tap()
        XCTAssertTrue(app.staticTexts["Add a draft to polish."].waitForExistence(timeout: 3))
    }

    func testNativePolishGeneratesFromDraftAndPreservesSource() {
        let app = launchApp(arguments: ["--ui-test-polish-draft"])

        XCTAssertTrue(app.staticTexts["Workspace"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["NativePolishRun"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["NativePolishPrimary"].exists)

        app.buttons["NativePolishRun"].tap()

        XCTAssertTrue(app.staticTexts["NativePolishPrimary"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["NativePolishVariant"].waitForExistence(timeout: 5))
        let editor = app.textViews["UnderstandSourceEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertTrue(String(describing: editor.value ?? "").contains("i think this product"))
    }

    func testNativePolishCopyAndRefinementFeedback() {
        let app = launchApp(arguments: ["--ui-test-polish"])

        XCTAssertTrue(app.staticTexts["Workspace"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["NativePolishPrimary"].waitForExistence(timeout: 5))

        app.buttons["NativePolishCopyPrimary"].tap()
        XCTAssertTrue(app.staticTexts["Copied"].waitForExistence(timeout: 3))

        app.buttons["NativePolishRefinePrimaryshorter"].tap()
        XCTAssertTrue(app.staticTexts["Refined"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Useful product, confusing onboarding.")).firstMatch.waitForExistence(timeout: 5))
    }

    func testNativePolishHistoryItemReopensPolishSession() {
        let app = launchApp(arguments: ["--ui-test-polish-history"])

        XCTAssertTrue(app.staticTexts["History"].waitForExistence(timeout: 5))
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "History polish seed")).firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Workspace"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["WorkspaceModePolish"].exists)
        XCTAssertTrue(app.textViews["UnderstandSourceEditor"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["NativePolishPrimary"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["NativePolishReplaceDraftPrimary"].exists)
    }

    func testTerminologySettingsShowsEditor() {
        let app = launchApp(arguments: ["--ui-test-terminology"])

        XCTAssertTrue(app.staticTexts["Engines"].waitForExistence(timeout: 5))
        app.buttons["Terms"].tap()

        let source = app.textFields["源词"]
        let target = app.textFields["译法"]
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        XCTAssertTrue(target.exists)
        XCTAssertTrue(app.buttons["保存术语"].exists)
        XCTAssertTrue(app.buttons["忽略大小写"].exists)
        XCTAssertTrue(app.staticTexts["还没有术语"].exists)
    }

    func testOCRCleanupMutatesTextAndKeepsDraftEditable() {
        let app = launchApp(arguments: ["--ui-test-ocr"])

        XCTAssertTrue(app.staticTexts["Workspace"].waitForExistence(timeout: 5))
        let editor = app.textViews["UnderstandSourceEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertTrue(String(describing: editor.value ?? "").contains("@confused_user"))
        XCTAssertTrue(app.buttons["UnderstandCopySource"].exists)

        app.buttons["Clean lines"].tap()
        XCTAssertTrue(app.staticTexts["OCR text cleaned"].waitForExistence(timeout: 3))
        XCTAssertTrue(String(describing: editor.value ?? "").contains("This onboarding is not bad"))
        app.buttons["UnderstandCopySource"].tap()
        XCTAssertTrue(app.staticTexts["Copied"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Understand"].exists)
    }

    func testHistoryItemReopensEditableSession() {
        let app = launchApp(arguments: ["--ui-test-history"])

        XCTAssertTrue(app.staticTexts["History"].waitForExistence(timeout: 5))
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "History seed")).firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Workspace"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textViews["UnderstandSourceEditor"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["UnderstandCopySource"].exists)
        XCTAssertTrue(app.staticTexts["UnderstandTranslation"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["UnderstandCopyTranslation"].exists)
    }

    func testQuickLensAutoTranslatesFixtureAndSwitchesCandidate() {
        let app = launchApp(arguments: ["--ui-test-quick-lens"])

        XCTAssertTrue(app.staticTexts["Quick Lens"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["QuickLensCopySource"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["QuickLensTranslation"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["QuickLensCopyTranslation"].exists)
        XCTAssertTrue(app.staticTexts["QuickLensMeaning"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "产品有价值")).firstMatch.exists)

        let second = app.buttons["QuickLensCandidate1"].firstMatch
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        second.tap()

        let editor = app.textViews["QuickLensSourceEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertTrue(String(describing: editor.value ?? "").contains("ship the feature"))
    }

    func testQuickLensEditSourceKeepsEditablePath() {
        let app = launchApp(arguments: ["--ui-test-quick-lens"])

        XCTAssertTrue(app.staticTexts["Quick Lens"].waitForExistence(timeout: 5))
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.textViews["QuickLensSourceEditor"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Rerun translation"].exists)
    }

    func testCopyRecognizedAndTranslatedTextShowsFeedback() {
        let app = launchApp(arguments: ["--ui-test-quick-lens"])

        XCTAssertTrue(app.staticTexts["Quick Lens"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["QuickLensCopySource"].waitForExistence(timeout: 5))
        app.buttons["QuickLensCopySource"].tap()
        XCTAssertTrue(app.staticTexts["Copied"].waitForExistence(timeout: 3))

        XCTAssertTrue(app.buttons["QuickLensCopyTranslation"].waitForExistence(timeout: 5))
        app.buttons["QuickLensCopyTranslation"].tap()
        XCTAssertTrue(app.staticTexts["Copied"].waitForExistence(timeout: 3))
    }

    func testQuickLensNoRecentScreenshotRecovery() {
        let app = launchApp(arguments: ["--ui-test-quick-lens-empty"])

        XCTAssertTrue(app.staticTexts["Quick Lens"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["QuickLensNoRecent"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Try latest screenshot again"].exists)
        XCTAssertTrue(app.buttons["Enter text manually"].exists)
    }

    func testQuickLensPermissionRecovery() {
        let app = launchApp(arguments: ["--ui-test-quick-lens-permission"])

        XCTAssertTrue(app.staticTexts["Quick Lens"].waitForExistence(timeout: 5))
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
