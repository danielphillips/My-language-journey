import XCTest

/// End-to-end journeys. The app is launched with `-ui-testing`, which uses an isolated on-disk store
/// and a simulated microphone, and `-reset-data` to start from a clean slate.
final class CriticalJourneyUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(reset: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + (reset ? ["-reset-data"] : [])
        app.launch()
        return app
    }

    private func completeOnboarding(_ app: XCUIApplication) {
        let start = app.buttons["onboarding.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), "Onboarding should appear on first launch")
        XCTAssertTrue(app.staticTexts["A1 · Elementary"].exists, "A1 is the default goal")
        start.tap()
    }

    func testOnboardingConfiguresAnA1Goal() {
        let app = launch(reset: true)
        completeOnboarding(app)
        XCTAssertTrue(app.staticTexts["journey.goalLevel"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["journey.goalLevel"].label, "A1 · Elementary")
        XCTAssertTrue(app.staticTexts["journey.estimate"].label.contains("110"))
    }

    func testLoggingASessionUpdatesTheDashboard() {
        let app = launch(reset: true)
        completeOnboarding(app)

        app.buttons["journey.add"].tap()
        app.buttons["journey.logPastSession"].tap()
        app.buttons["log.duration.30"].tap()
        app.buttons["log.category.grammar"].tap()
        app.buttons["log.save"].tap()

        let thisWeek = app.staticTexts["journey.thisWeekValue"]
        XCTAssertTrue(thisWeek.waitForExistence(timeout: 5))
        XCTAssertEqual(thisWeek.label, "30m")
    }

    func testAddWordConfidencePronunciationNotesRecordingsAndPersistence() {
        var app = launch(reset: true)
        completeOnboarding(app)

        // Add a Russian word.
        app.tabBars.buttons["Vocabulary"].tap()
        app.buttons["vocabulary.add"].tap()
        let russian = app.textFields["addWord.russian"]
        XCTAssertTrue(russian.waitForExistence(timeout: 5))
        russian.tap()
        russian.typeText("женщины")
        let meaning = app.textFields["addWord.meaning"]
        meaning.tap()
        meaning.typeText("women")
        app.buttons["addWord.save"].tap()

        // Open it and change confidence.
        app.staticTexts["женщины"].firstMatch.tap()
        app.buttons["confidence.comfortable"].tap()
        XCTAssertTrue(app.buttons["confidence.comfortable"].isSelected)

        // French pronunciation note.
        addPronunciation(app, text: "Jène-chi-ni", languageID: "fr")
        // Brazilian Portuguese pronunciation note.
        addPronunciation(app, text: "Gente-chima", languageID: "pt-BR")
        XCTAssertTrue(app.staticTexts["Gente-chima"].exists)
        XCTAssertTrue(app.staticTexts["Jène-chi-ni"].exists)

        // Recordings section is reachable and can capture a take with the simulated microphone.
        let record = app.buttons["recordings.record"]
        if !record.isHittable { app.swipeUp() }
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()
        app.buttons["recordings.stop"].tap()
        XCTAssertTrue(app.staticTexts["Take 1"].waitForExistence(timeout: 5))

        // Relaunch without resetting: everything is still there.
        app.terminate()
        app = launch(reset: false)
        app.tabBars.buttons["Vocabulary"].tap()
        app.staticTexts["женщины"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Gente-chima"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Jène-chi-ni"].exists)
        XCTAssertTrue(app.buttons["confidence.comfortable"].isSelected)
        XCTAssertTrue(app.staticTexts["Take 1"].exists)
    }

    func testDeletingARecording() {
        var app = launch(reset: true)
        completeOnboarding(app)

        app.tabBars.buttons["Vocabulary"].tap()
        app.buttons["vocabulary.add"].tap()
        let russian = app.textFields["addWord.russian"]
        XCTAssertTrue(russian.waitForExistence(timeout: 5))
        russian.tap()
        russian.typeText("хлеб")
        let meaning = app.textFields["addWord.meaning"]
        meaning.tap()
        meaning.typeText("bread")
        app.buttons["addWord.save"].tap()
        app.staticTexts["хлеб"].firstMatch.tap()

        let record = app.buttons["recordings.record"]
        if !record.isHittable { app.swipeUp() }
        record.tap()
        app.buttons["recordings.stop"].tap()
        XCTAssertTrue(app.staticTexts["Take 1"].waitForExistence(timeout: 5))

        app.buttons["recording.actions.Take 1"].tap()
        app.buttons["recording.delete"].tap()
        XCTAssertTrue(app.staticTexts["Take 1"].waitForNonExistence(timeout: 5))

        app.terminate()
        app = launch(reset: false)
        app.tabBars.buttons["Vocabulary"].tap()
        app.staticTexts["хлеб"].firstMatch.tap()
        XCTAssertFalse(app.staticTexts["Take 1"].waitForExistence(timeout: 2))
    }

    func testTappingOutsideATextFieldDismissesTheKeyboard() {
        let app = launch(reset: true)
        completeOnboarding(app)

        app.tabBars.buttons["Vocabulary"].tap()
        app.buttons["vocabulary.add"].tap()
        let russian = app.textFields["addWord.russian"]
        XCTAssertTrue(russian.waitForExistence(timeout: 5))
        russian.tap()
        russian.typeText("кот")
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 3))

        // Tap empty space (the sheet's title area), not a control.
        app.navigationBars["New Word"].staticTexts["New Word"].tap()
        XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 3))
        XCTAssertEqual(russian.value as? String, "кот", "Dismissing the keyboard keeps what was typed")

        // Tapping straight into another field still works.
        app.textFields["addWord.meaning"].tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 3))
    }

    private func addPronunciation(_ app: XCUIApplication, text: String, languageID: String) {
        app.buttons["detail.addPronunciation"].tap()
        let field = app.textFields["pronunciation.text"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        app.buttons["pronunciation.language.\(languageID)"].tap()
        field.tap()
        field.typeText(text)
        app.buttons["pronunciation.save"].tap()
        XCTAssertTrue(app.staticTexts[text].waitForExistence(timeout: 5))
    }
}
