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
        let begin = reveal(UITag.beginRosary)
        XCTAssertTrue(begin.waitForExistence(timeout: 2), "Missing \(UITag.beginRosary)")
        begin.tap()
        let end = app.descendants(matching: .any)[UITag.sessionEnd]
        if !end.waitForExistence(timeout: 10) {
            let texts = app.staticTexts.allElementsBoundByIndex.prefix(12).map(\.label).joined(separator: " | ")
            let buttons = app.buttons.allElementsBoundByIndex.prefix(12).map { "\($0.identifier):\($0.label)" }.joined(separator: " | ")
            XCTFail("Missing \(UITag.sessionEnd). buttons=\(buttons). texts=\(texts)")
            return
        }
        tap(UITag.sessionPause)
        tap(UITag.sessionBack)
        tap(UITag.sessionSurface)
        tap(UITag.sessionEnd)
        tapLabel("End now")
        XCTAssertTrue(app.tabBars.buttons["Pray"].waitForExistence(timeout: 5))
    }

    /// The painting and the Scripture can be touched while meditating. Only the beads move on.
    func testImageAndTextTapsDoNotAdvanceBeads() {
        app.segmentedControls.buttons["One decade"].tap()
        let begin = reveal(UITag.beginRosary)
        XCTAssertTrue(begin.waitForExistence(timeout: 2))
        begin.tap()
        let prayer = app.descendants(matching: .any)[UITag.sessionPrayer]
        XCTAssertTrue(prayer.waitForExistence(timeout: 10), "Missing \(UITag.sessionPrayer)")
        let before = prayer.label
        XCTAssertFalse(before.isEmpty)
        tapInside(UITag.sessionArt, y: 0.4)
        let viewer = app.descendants(matching: .any)[UITag.sessionArtViewer]
        XCTAssertTrue(viewer.waitForExistence(timeout: 4), "Tapping the painting did not open it")
        tap(UITag.sessionArtClose)
        waitUntilGone(UITag.sessionArtViewer)
        tap(UITag.sessionScripture)
        let reader = app.descendants(matching: .any)[UITag.sessionScriptureReader]
        XCTAssertTrue(reader.waitForExistence(timeout: 4), "Tapping the Scripture did not open it")
        tap(UITag.sessionScriptureClose)
        waitUntilGone(UITag.sessionScriptureReader)
        XCTAssertEqual(prayer.label, before, "Tapping the image or the Scripture moved the prayer")
        tapInside(UITag.sessionBeads, y: 0.45)
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", before),
            object: prayer
        )
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed, "Tapping the beads left the prayer on \"\(prayer.label)\"")
    }

    /// The chapel shows the opening of the passage. The reader has the rest, and it scrolls.
    func testScriptureReaderShowsTheWholePassage() {
        beginOneDecade()
        let prayer = prayerLabel()
        let before = prayer.label
        let preview = reveal(UITag.sessionScripture)
        XCTAssertTrue(preview.waitForExistence(timeout: 4))
        let previewHeight = preview.frame.height
        preview.tap()
        let reader = app.descendants(matching: .any)[UITag.sessionScriptureReader]
        XCTAssertTrue(reader.waitForExistence(timeout: 4))
        XCTAssertGreaterThan(reader.frame.height, previewHeight + 40, "The reader is not larger than the chapel preview")
        let body = app.descendants(matching: .any)[UITag.sessionScriptureBody]
        XCTAssertTrue(body.waitForExistence(timeout: 2))
        XCTAssertGreaterThan(body.label.count, 20)
        XCTAssertTrue(body.label.contains(where: \.isNumber), "The passage has no verse number: \(body.label)")
        if body.frame.height > reader.frame.height {
            reader.swipeUp()
            XCTAssertTrue(body.exists, "Scrolling the passage dismissed the reader")
        }
        tap(UITag.sessionScriptureClose)
        waitUntilGone(UITag.sessionScriptureReader)
        XCTAssertEqual(prayer.label, before, "Reading the passage moved the prayer")
    }

    /// Pinch leaves the painting up. The credit stays visible. X and a downward drag each close it.
    func testPaintingViewerZoomsAndCloses() {
        beginOneDecade()
        let prayer = prayerLabel()
        let before = prayer.label
        tapInside(UITag.sessionArt, y: 0.4)
        let viewer = app.descendants(matching: .any)[UITag.sessionArtViewer]
        XCTAssertTrue(viewer.waitForExistence(timeout: 4))
        let credit = app.descendants(matching: .any)[UITag.sessionArtCredit]
        XCTAssertTrue(credit.waitForExistence(timeout: 2))
        XCTAssertFalse(credit.label.isEmpty)
        viewer.pinch(withScale: 2, velocity: 1)
        XCTAssertTrue(viewer.exists, "Pinch closed the painting")
        tap(UITag.sessionArtClose)
        waitUntilGone(UITag.sessionArtViewer)

        tapInside(UITag.sessionArt, y: 0.4)
        XCTAssertTrue(viewer.waitForExistence(timeout: 4))
        let start = viewer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.32))
        let end = viewer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.94))
        start.press(forDuration: 0.2, thenDragTo: end)
        waitUntilGone(UITag.sessionArtViewer)
        XCTAssertEqual(prayer.label, before, "Looking at the painting moved the prayer")
    }

    /// A wide picture and a tall picture each stay inside the gold frame.
    func testTallAndWideImagesStayInsideTheFrame() {
        beginOneDecade()
        let prayer = prayerLabel()
        let before = prayer.label
        let frame = app.descendants(matching: .any)[UITag.sessionArtFrame]
        let image = app.descendants(matching: .any)[UITag.sessionArtImage]
        if !frame.waitForExistence(timeout: 8) {
            let names = app.descendants(matching: .any).allElementsBoundByIndex.prefix(24).map { "\($0.identifier):\($0.label)" }.joined(separator: " | ")
            XCTFail("Missing \(UITag.sessionArtFrame). elements=\(names)")
            return
        }
        XCTAssertTrue(image.waitForExistence(timeout: 4), "Missing \(UITag.sessionArtImage)")
        waitUntil("bundled image reports its size") { self.parsedSize(of: image) != nil }
        assertImageFits(image, in: frame)

        let bundled = image.value as? String
        tap(UITag.sessionRefreshArt)
        waitUntil("wide image") {
            guard let size = self.parsedSize(of: image), (image.value as? String) != bundled else { return false }
            return size.width > size.height * 1.4
        }
        assertImageFits(image, in: frame)

        let wide = image.value as? String
        tap(UITag.sessionRefreshArt)
        waitUntil("tall image") {
            guard let size = self.parsedSize(of: image), (image.value as? String) != wide else { return false }
            return size.height > size.width * 1.4
        }
        assertImageFits(image, in: frame)
        XCTAssertEqual(prayer.label, before, "Changing the painting moved the prayer")
    }

    /// Home is the catalogue: a star on a prayer, then the read-aloud controls.
    func testCatalogueFavoritesAndReadAloud() {
        shot("home")
        let search = reveal(UITag.homeSearch)
        XCTAssertTrue(search.waitForExistence(timeout: 4), "Missing \(UITag.homeSearch)")
        let ourLady = reveal("home.category.ourLady")
        XCTAssertTrue(ourLady.waitForExistence(timeout: 4), "Missing the Our Lady category")
        ourLady.tap()
        let star = reveal("home.favorite.memorare")
        XCTAssertTrue(star.waitForExistence(timeout: 4), "Missing the Memorare star")
        star.tap()
        if app.descendants(matching: .any)[UITag.libraryBody].waitForExistence(timeout: 2) {
            goBack("Rosary")
        }
        let marked = app.buttons["home.favorite.memorare"].firstMatch
        XCTAssertTrue(marked.waitForExistence(timeout: 4))
        XCTAssertEqual(marked.label, "Remove from favorites")
        let header = app.staticTexts["Favorites"].firstMatch
        for _ in 0..<8 where !header.isHittable {
            app.swipeDown()
        }
        shot("favorites")

        let oneDecade = app.segmentedControls.buttons["One decade"]
        XCTAssertTrue(oneDecade.waitForExistence(timeout: 4))
        if !oneDecade.isHittable { app.swipeDown() }
        oneDecade.tap()
        let begin = reveal(UITag.beginRosary)
        XCTAssertTrue(begin.waitForExistence(timeout: 2))
        begin.tap()
        let read = app.descendants(matching: .any)[UITag.sessionReadMeditation]
        XCTAssertTrue(read.waitForExistence(timeout: 10), "Missing \(UITag.sessionReadMeditation)")
        let rate = app.descendants(matching: .any)[UITag.sessionRate]
        XCTAssertTrue(rate.waitForExistence(timeout: 4), "Missing \(UITag.sessionRate)")
        shot("read-aloud")
    }

    /// Next, previous, and a sideways swipe move through the sacred art without leaving the viewer.
    func testArtViewerPagesWithButtonsAndSwipe() {
        beginOneDecade()
        tapInside(UITag.sessionArt, y: 0.4)
        let page = app.descendants(matching: .any)[UITag.sessionArtPage]
        XCTAssertTrue(page.waitForExistence(timeout: 4), "Missing \(UITag.sessionArtPage)")
        let before = page.label
        XCTAssertTrue(before.contains(" of "), "Page indicator was \"\(before)\"")
        let credit = app.descendants(matching: .any)[UITag.sessionArtCredit]
        XCTAssertTrue(credit.waitForExistence(timeout: 2))
        let firstCredit = credit.label
        XCTAssertFalse(firstCredit.isEmpty)
        tap(UITag.sessionArtNext)
        XCTAssertNotEqual(page.label, before)
        XCTAssertTrue(page.label.contains(" of "))
        XCTAssertNotEqual(credit.label, firstCredit)
        let viewer = app.descendants(matching: .any)[UITag.sessionArtViewer]
        let afterNext = page.label
        viewer.swipeLeft()
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", afterNext),
            object: page
        )
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 3), .completed, "Swipe left left the page on \"\(page.label)\"")
        shot("art-viewer")
        tap(UITag.sessionArtPrevious)
        tap(UITag.sessionArtClose)
        waitUntilGone(UITag.sessionArtViewer)
    }

    /// A one-decade prayer can still move to another mystery, and lands on its Our Father.
    func testMysteryJumpLandsOnTheOurFather() {
        app.segmentedControls.buttons["One decade"].tap()
        let begin = reveal(UITag.beginRosary)
        XCTAssertTrue(begin.waitForExistence(timeout: 2))
        begin.tap()
        let chip = app.buttons[UITag.sessionMystery(4)]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "Missing mystery 4")
        let mysteryTitle = chip.label
        XCTAssertFalse(mysteryTitle.isEmpty)
        let beads = app.descendants(matching: .any)[UITag.sessionBeads]
        XCTAssertTrue(beads.waitForExistence(timeout: 4))
        chip.tap()
        let prayer = prayerLabel()
        let onOurFather = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Our Father"), object: prayer)
        XCTAssertEqual(XCTWaiter.wait(for: [onOurFather], timeout: 5), .completed, "Mystery jump left the prayer on \"\(prayer.label)\"")
        let surface = app.descendants(matching: .any)[UITag.sessionSurface]
        XCTAssertTrue(surface.label.contains(mysteryTitle), "The header does not name \(mysteryTitle): \(surface.label)")
        XCTAssertEqual(beads.label, "10 beads", "The beads moved before a bead was tapped: \(beads.label)")
        let beforeBead = prayer.label
        tapInside(UITag.sessionBeads, y: 0.45)
        let hailed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", beforeBead), object: prayer)
        XCTAssertEqual(XCTWaiter.wait(for: [hailed], timeout: 5), .completed, "Tapping the beads left the prayer on \"\(prayer.label)\"")
    }

    func testTodayAndAFullPrayer() {
        tap(UITag.tabToday)
        XCTAssertTrue(app.descendants(matching: .any)[UITag.readingsDay].waitForExistence(timeout: 8))
        let link = app.descendants(matching: .any)[UITag.readingsLink]
        XCTAssertTrue(link.waitForExistence(timeout: 4))
        let address = "\(link.label) \(link.value as? String ?? "")"
        XCTAssertTrue(address.contains("bible.usccb.org"), "USCCB link was \(address)")
        goBack("Rosary")
        app.tabBars.buttons["Devotions"].tap()
        let search = app.textFields[UITag.librarySearch]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Memorare")
        tap(UITag.libraryMemorare)
        let body = app.descendants(matching: .any)[UITag.libraryBody]
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        XCTAssertTrue(body.label.contains("Remember, O most gracious"), body.label)
        goBack("Devotions")
    }

    func testDevotionScreens() {
        app.tabBars.buttons["Devotions"].tap()
        open(UITag.devotionSorrows)
        let sorrows = app.descendants(matching: .any)[UITag.devotionFullText]
        XCTAssertTrue(sorrows.waitForExistence(timeout: 10), "The chaplet did not open as one page")
        XCTAssertTrue(sorrows.label.contains("Offering") || sorrows.label.contains("SIMEON"), sorrows.label)
        tap(UITag.devotionStep)
        tap(UITag.devotionNext)
        tap(UITag.devotionNext)
        tap(UITag.devotionBack)
        tap(UITag.devotionEnd)
        open(UITag.devotionMercy)
        tap(UITag.devotionStep)
        tap(UITag.devotionNext)
        tap(UITag.devotionEnd)
        open(UITag.devotionLitany)
        let litany = app.descendants(matching: .any)[UITag.litanyFullText]
        XCTAssertTrue(litany.waitForExistence(timeout: 5))
        XCTAssertTrue(litany.label.contains("Lord have mercy"), litany.label)
        tap(UITag.litanyStep)
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

    private func beginOneDecade() {
        app.segmentedControls.buttons["One decade"].tap()
        let begin = reveal(UITag.beginRosary)
        XCTAssertTrue(begin.waitForExistence(timeout: 2))
        begin.tap()
    }

    private func prayerLabel() -> XCUIElement {
        let prayer = app.descendants(matching: .any)[UITag.sessionPrayer]
        XCTAssertTrue(prayer.waitForExistence(timeout: 10), "Missing \(UITag.sessionPrayer)")
        return prayer
    }

    private func waitUntilGone(_ identifier: String) {
        let element = app.descendants(matching: .any)[identifier]
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 4), .completed, "\(identifier) stayed open")
    }

    private func waitUntil(_ description: String, timeout: TimeInterval = 5, _ condition: @escaping () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed, description)
    }

    private func parsedSize(of element: XCUIElement) -> (width: CGFloat, height: CGFloat)? {
        guard let raw = element.value as? String else { return nil }
        let parts = raw.split(separator: "x", omittingEmptySubsequences: false)
        guard parts.count == 2, let width = Double(parts[0]), let height = Double(parts[1]), width > 0, height > 0 else {
            return nil
        }
        return (CGFloat(width), CGFloat(height))
    }

    private func assertImageFits(
        _ image: XCUIElement,
        in frame: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let box = frame.frame
        let shown = image.frame
        let slack: CGFloat = 2
        XCTAssertGreaterThan(shown.width, 1, file: file, line: line)
        XCTAssertGreaterThan(shown.height, 1, file: file, line: line)
        XCTAssertGreaterThanOrEqual(shown.minX, box.minX - slack, "image left of the frame", file: file, line: line)
        XCTAssertGreaterThanOrEqual(shown.minY, box.minY - slack, "image above the frame", file: file, line: line)
        XCTAssertLessThanOrEqual(shown.maxX, box.maxX + slack, "image right of the frame", file: file, line: line)
        XCTAssertLessThanOrEqual(shown.maxY, box.maxY + slack, "image below the frame", file: file, line: line)
        guard let stated = parsedSize(of: image) else {
            XCTFail("Image value \(String(describing: image.value)) is not WxH", file: file, line: line)
            return
        }
        XCTAssertEqual(stated.width, shown.width, accuracy: 4, file: file, line: line)
        XCTAssertEqual(stated.height, shown.height, accuracy: 4, file: file, line: line)
        XCTAssertLessThanOrEqual(stated.width, box.width + slack, file: file, line: line)
        XCTAssertLessThanOrEqual(stated.height, box.height + slack, file: file, line: line)
    }

    private func tap(_ identifier: String) {
        let element = reveal(identifier)
        XCTAssertTrue(element.waitForExistence(timeout: 2), "Missing \(identifier)")
        element.tap()
    }

    /// Hits the visible part of a tall passage instead of the middle, which can sit under the beads.
    private func tapInside(_ identifier: String, y: CGFloat) {
        let element = reveal(identifier)
        XCTAssertTrue(element.waitForExistence(timeout: 4), "Missing \(identifier)")
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: y)).tap()
    }

    /// A toolbar item and a list row can publish the same identifier on both the
    /// control and its container. Prefer the button, then the first match, and
    /// scroll a lazy form until the row is realized.
    private func reveal(_ identifier: String) -> XCUIElement {
        let button = app.buttons[identifier].firstMatch
        if button.waitForExistence(timeout: 1) { return button }
        let any = app.descendants(matching: .any)[identifier].firstMatch
        if any.waitForExistence(timeout: 1) { return any }
        for _ in 0..<14 {
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
        let element = reveal(identifier)
        XCTAssertTrue(element.waitForExistence(timeout: 2), "Missing \(identifier)")
        let height = app.windows.firstMatch.frame.height
        if !element.isHittable, height > 1 {
            if element.frame.minY > height * 0.75 {
                for _ in 0..<5 where !element.isHittable {
                    app.swipeUp()
                }
            } else if element.frame.maxY < 64 {
                for _ in 0..<5 where !element.isHittable {
                    app.swipeDown()
                }
            }
        }
        element.tap()
    }

    private func goBack(_ previousTitle: String) {
        let back = app.navigationBars.buttons[previousTitle]
        if back.waitForExistence(timeout: 3) {
            back.tap()
            return
        }
        app.navigationBars.buttons.firstMatch.tap()
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func toggle(_ identifier: String) {
        let toggle = app.switches[identifier].firstMatch
        let target = toggle.waitForExistence(timeout: 1) ? toggle : reveal(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: 2), "Missing \(identifier)")
        target.tap()
    }
}
