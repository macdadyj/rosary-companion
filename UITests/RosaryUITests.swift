import RosaryCore
import XCTest

final class RosaryUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Pray"].waitForExistence(timeout: 15))
    }

    func testPrayTabControlsAndSession() {
        tap(UITag.modeTracking)
        tap(UITag.modeGuided)
        app.segmentedControls.buttons["Five decades"].tap()
        app.segmentedControls.buttons["One decade"].tap()
        tap(UITag.offerIntentions)
        tapLabel("Done")
        tap(UITag.openAngelus)
        goBack("Rosary")
        tap(UITag.openCalendar)
        XCTAssertTrue(app.descendants(matching: .any)[UITag.calendarToday].waitForExistence(timeout: 5))
        goBack("Rosary")
        tap(UITag.openJournal)
        goBack("Rosary")
        tap(UITag.beginRosary)
        XCTAssertTrue(app.descendants(matching: .any)[UITag.sessionEnd].waitForExistence(timeout: 10))
        tap(UITag.sessionPause)
        tap(UITag.sessionBack)
        tap(UITag.sessionSurface)
        tap(UITag.sessionEnd)
        tapLabel("End now")
        XCTAssertTrue(app.tabBars.buttons["Pray"].waitForExistence(timeout: 5))
    }

    func testDevotionScreens() {
        app.tabBars.buttons["Devotions"].tap()
        open(UITag.devotionSorrows)
        tap(UITag.devotionNext)
        tap(UITag.devotionNext)
        tap(UITag.devotionBack)
        tap(UITag.devotionEnd)
        open(UITag.devotionMercy)
        tap(UITag.devotionNext)
        tap(UITag.devotionEnd)
        open(UITag.devotionLitany)
        tap(UITag.litanyNext)
        tap(UITag.litanyBack)
        goBack("Devotions")
        open(UITag.devotionHours)
        goBack("Devotions")
        open(UITag.devotionConsecration)
        tap(UITag.consecrationBegin)
        tap(UITag.consecrationDay)
        goBack("Devotions")
        open(UITag.devotionCalendar)
        XCTAssertTrue(app.descendants(matching: .any)[UITag.calendarToday].waitForExistence(timeout: 5))
        goBack("Devotions")
        open(UITag.devotionJournal)
        goBack("Devotions")
    }

    func testIntentionsJournalPath() {
        app.tabBars.buttons["Intentions"].tap()
        let field = app.textFields[UITag.intentionField]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Aunt Mae")
        tap(UITag.intentionAdd)
        app.staticTexts["Aunt Mae"].firstMatch.tap()
        tap(UITag.intentionAnswered)
        tap("intention.save")
        app.buttons["Answered"].tap()
        XCTAssertTrue(app.staticTexts["Aunt Mae"].waitForExistence(timeout: 5))
    }

    func testSaintsScreen() {
        app.tabBars.buttons["Saints"].tap()
        tap(UITag.saintMystery)
        goBack("Saints")
    }

    func testSettingsControlsAndBuildNumber() {
        app.tabBars.buttons["Settings"].tap()
        toggle(UITag.settingsVoice)
        toggle(UITag.settingsVoice)
        toggle(UITag.settingsHaptics)
        toggle(UITag.settingsHaptics)
        toggle(UITag.settingsChant)
        toggle(UITag.settingsChant)
        toggle(UITag.settingsArt)
        toggle(UITag.settingsArt)
        toggle(UITag.settingsHolyGhost)
        toggle(UITag.settingsHolyGhost)
        toggle(UITag.settingsSeasonal)
        toggle(UITag.settingsSeasonal)
        toggle(UITag.settingsFamily)
        tap(UITag.settingsMembers)
        let name = app.textFields[UITag.familyField]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Jon")
        tap(UITag.familyAdd)
        goBack("Settings")
        tap(UITag.settingsVoicePicker)
        goBack("Settings")
        let build = reveal(UITag.settingsBuild)
        XCTAssertTrue(build.waitForExistence(timeout: 2))
        XCTAssertFalse(build.label.isEmpty)
    }

    private func tap(_ identifier: String) {
        let element = reveal(identifier)
        XCTAssertTrue(element.waitForExistence(timeout: 2), "Missing \(identifier)")
        element.tap()
    }

    /// A toolbar item and a list row can publish the same identifier on both the
    /// control and its container. Prefer the button, then the first match, and
    /// scroll a lazy form until the row is realized.
    private func reveal(_ identifier: String) -> XCUIElement {
        let button = app.buttons[identifier].firstMatch
        if button.waitForExistence(timeout: 1) { return button }
        let any = app.descendants(matching: .any)[identifier].firstMatch
        if any.waitForExistence(timeout: 1) { return any }
        for _ in 0..<4 {
            app.swipeDown()
            if button.exists { return button }
            if any.exists { return any }
        }
        for _ in 0..<8 {
            app.swipeUp()
            if button.exists { return button }
            if any.exists { return any }
        }
        return any
    }

    private func tapLabel(_ label: String) {
        let element = app.buttons[label]
        XCTAssertTrue(element.waitForExistence(timeout: 8), "Missing button \(label)")
        element.tap()
    }

    private func open(_ identifier: String) {
        tap(identifier)
    }

    private func goBack(_ previousTitle: String) {
        let back = app.navigationBars.buttons[previousTitle]
        if back.waitForExistence(timeout: 3) {
            back.tap()
            return
        }
        app.navigationBars.buttons.firstMatch.tap()
    }

    private func toggle(_ identifier: String) {
        let toggle = app.switches[identifier].firstMatch
        let target = toggle.waitForExistence(timeout: 1) ? toggle : reveal(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: 2), "Missing \(identifier)")
        target.tap()
    }
}
