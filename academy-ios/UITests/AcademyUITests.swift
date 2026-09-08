import XCTest

final class AcademyUITests: XCTestCase {
    let app=XCUIApplication()
    override func setUp() { continueAfterFailure=false }
    func reveal(_ element:XCUIElement) {
        for _ in 0..<7 { if element.isHittable { return };app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
    func testPracticeAnswerFeedbackAndResumeAfterRelaunch() {
        app.launchArguments=["-snapshot-reset","-snapshot-question"];app.launch()
        XCTAssertTrue(app.staticTexts["study.position"].waitForExistence(timeout:12))
        let answer=app.buttons["answer.0"];reveal(answer);answer.tap()
        XCTAssertFalse(app.buttons["Check my answer"].isEnabled)
        let confidence=app.buttons["confidence.confident"];reveal(confidence);confidence.tap()
        app.buttons["Check my answer"].tap()
        XCTAssertTrue(app.descendants(matching:.any).matching(identifier:"study.feedback").firstMatch.waitForExistence(timeout:5))
        app.buttons["Next challenge"].tap()
        XCTAssertEqual(app.staticTexts["study.position"].label,"QUESTION 2 / 5")
        app.buttons["Save and close session"].tap()
        app.terminate();app.launchArguments=[];app.launch()
        let resume=app.buttons["Continue session"];XCTAssertTrue(resume.waitForExistence(timeout:10));reveal(resume);resume.tap()
        XCTAssertEqual(app.staticTexts["study.position"].label,"QUESTION 2 / 5")
        app.buttons["End"].tap();app.buttons["Finish session"].tap()
        XCTAssertTrue(app.staticTexts["results.score"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["results.score"].label.hasSuffix(" / 1"))
    }
    func testMockAllowsFlagNavigationAndScoresOnlyOnSubmission() {
        app.launchArguments=["-snapshot-reset","-snapshot-exam"];app.launch()
        XCTAssertTrue(app.staticTexts["study.position"].waitForExistence(timeout:12))
        let answer=app.buttons["answer.0"];reveal(answer);answer.tap()
        XCTAssertFalse(app.descendants(matching:.any).matching(identifier:"study.feedback").firstMatch.exists)
        app.swipeDown()
        let flag=app.buttons["Flag for review"];if !flag.isHittable { app.swipeDown() };flag.tap()
        app.buttons["exam.navigator"].tap()
        XCTAssertTrue(app.buttons["exam.question.0"].label.contains("answered, flagged"))
        app.buttons["exam.question.4"].tap()
        XCTAssertEqual(app.staticTexts["study.position"].label,"QUESTION 5 / 40")
        app.buttons["Finish"].tap();app.buttons["Submit and see results"].tap()
        XCTAssertTrue(app.staticTexts["results.score"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["results.score"].label.hasSuffix(" / 40"))
    }
}
