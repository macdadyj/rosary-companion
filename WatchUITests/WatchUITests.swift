import RosaryCore
import XCTest

final class WatchUITests: XCTestCase {
    func testEveryBeadButton() {
        let app = XCUIApplication()
        app.launch()
        let count = app.staticTexts[UITag.watchCount]
        XCTAssertTrue(count.waitForExistence(timeout: 20))
        XCTAssertEqual(count.label, "Ready")
        app.buttons[UITag.watchAdvance].tap()
        XCTAssertEqual(count.label, "1 of 10")
        app.buttons[UITag.watchAdvance].tap()
        XCTAssertEqual(count.label, "2 of 10")
        app.buttons[UITag.watchBack].tap()
        XCTAssertEqual(count.label, "1 of 10")
        app.buttons[UITag.watchReset].tap()
        XCTAssertEqual(count.label, "Ready")
    }
}
