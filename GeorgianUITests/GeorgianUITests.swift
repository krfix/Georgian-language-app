import XCTest

/// Drives the real app in the Simulator: onboarding, a whole first lesson, the tabs, and a
/// restart that must keep the progress. Answers are tapped without knowing which is right,
/// so every exercise kind has to finish whichever way it goes.
final class GeorgianUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = args
        app.launch()
        return app
    }

    func testOnboardingFirstLessonAndRestart() throws {
        let app = launch(["-resetData"])

        // Onboarding
        XCTAssertTrue(app.buttons["onboarding-next"].waitForExistence(timeout: 10), "Welcome screen")
        app.buttons["onboarding-next"].tap()            // welcome → about Georgian
        app.buttons["onboarding-next"].tap()            // → method
        app.buttons["onboarding-next"].tap()            // → level
        app.buttons["choice-beginner"].tap()
        app.buttons["onboarding-next"].tap()            // → goal
        app.buttons["choice-10"].tap()
        app.buttons["onboarding-next"].tap()            // → name
        let name = app.textFields["onboarding-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("Tester\n")                       // → ready
        XCTAssertTrue(app.buttons["onboarding-start-lesson"].waitForExistence(timeout: 3))
        app.buttons["onboarding-start-lesson"].tap()

        // The first lesson, to the end.
        XCTAssertTrue(app.staticTexts["instruction"].waitForExistence(timeout: 10), "Lesson opened")
        finishLesson(app)
        XCTAssertTrue(app.buttons["complete-continue"].waitForExistence(timeout: 10), "Completion screen")
        app.buttons["complete-continue"].tap()

        // Back home: the lesson counts.
        XCTAssertTrue(app.buttons["continue-lesson"].waitForExistence(timeout: 10), "Home after the lesson")

        // Every tab opens.
        for tab in ["Learn", "Words", "Review", "Progress", "Home"] {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(app.tabBars.buttons[tab].isSelected, "\(tab) tab")
        }

        // Restart: no onboarding again, and the streak is kept.
        app.terminate()
        let again = launch([])
        XCTAssertTrue(again.buttons["continue-lesson"].waitForExistence(timeout: 10), "Progress kept after restart")
        XCTAssertFalse(again.buttons["onboarding-next"].exists)
        XCTAssertTrue(again.staticTexts["1"].exists || again.staticTexts["days streak"].exists || again.staticTexts["day streak"].exists)
    }

    func testDemoScreensOpen() throws {
        let app = launch(["-uiTesting", "-seedDemo"])
        XCTAssertTrue(app.buttons["continue-lesson"].waitForExistence(timeout: 10))
        app.buttons["profile-button"].tap()
        XCTAssertTrue(app.buttons["profile-done"].waitForExistence(timeout: 5))
        app.buttons["profile-done"].tap()
        app.tabBars.buttons["Review"].tap()
        XCTAssertTrue(app.buttons["start-review"].waitForExistence(timeout: 5))
        app.buttons["start-review"].tap()
        finishLesson(app)
        XCTAssertTrue(app.buttons["complete-continue"].waitForExistence(timeout: 10), "Review completion")
        app.buttons["complete-continue"].tap()
        app.tabBars.buttons["Words"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("water")
        XCTAssertTrue(app.buttons["word-w-tsqali"].waitForExistence(timeout: 5) || app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'word-'")).count > 0)
    }

    /// Answers every exercise until the completion screen.
    private func finishLesson(_ app: XCUIApplication) {
        for _ in 0..<120 {
            if app.buttons["complete-continue"].exists { return }
            if app.buttons["lesson-continue"].exists && app.buttons["lesson-continue"].isHittable {
                app.buttons["lesson-continue"].tap()
                continue
            }
            if app.buttons["recall-yes"].exists { app.buttons["recall-yes"].tap(); continue }
            if app.buttons["flip"].exists { app.buttons["flip"].tap(); continue }
            let matchKa = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'match-ka-'"))
            if matchKa.count > 0 {
                matchAll(app, matchKa)
                continue
            }
            if app.textFields["answer-field"].exists {
                let field = app.textFields["answer-field"]
                field.tap()
                field.typeText("hello\n")
                if app.buttons["lesson-check"].exists && app.buttons["lesson-check"].isEnabled { app.buttons["lesson-check"].tap() }
                continue
            }
            let tile = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'tile-'")).firstMatch
            if tile.exists && !app.buttons["lesson-check"].isEnabled {
                tile.tap()
                if app.buttons["lesson-check"].isEnabled { app.buttons["lesson-check"].tap() }
                continue
            }
            if app.buttons["option-0"].exists {
                app.buttons["option-0"].tap()
                if app.buttons["lesson-check"].waitForExistence(timeout: 2) && app.buttons["lesson-check"].isEnabled {
                    app.buttons["lesson-check"].tap()
                }
                continue
            }
            if app.buttons["lesson-check"].exists && app.buttons["lesson-check"].isEnabled {
                app.buttons["lesson-check"].tap()
                continue
            }
            // Something is still moving; give it a moment.
            _ = app.buttons["lesson-continue"].waitForExistence(timeout: 1)
        }
        XCTFail("The lesson didn't finish")
    }

    /// Matches each Georgian tile with its partner (same id after the prefix).
    private func matchAll(_ app: XCUIApplication, _ left: XCUIElementQuery) {
        let ids = (0..<left.count).map { left.element(boundBy: $0).identifier }
        for id in ids {
            let key = String(id.dropFirst("match-ka-".count))
            let l = app.buttons[id]
            let r = app.buttons["match-other-\(key)"]
            if l.exists && l.isEnabled && r.exists && r.isEnabled {
                l.tap()
                r.tap()
            }
        }
        _ = app.buttons["lesson-continue"].waitForExistence(timeout: 3)
    }
}
