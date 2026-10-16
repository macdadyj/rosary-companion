import RosaryCore
import XCTest

final class WatchUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testEveryBeadButton() {
        let count = app.staticTexts[UITag.watchCount]
        XCTAssertTrue(count.waitForExistence(timeout: 20))
        XCTAssertEqual(count.label, "Ready")
        tap(UITag.watchAdvance, until: "1 of 10")
        tap(UITag.watchAdvance, until: "2 of 10")
        tap(UITag.watchBack, until: "1 of 10")
        tap(UITag.watchReset, until: "Ready")
    }

    /// The watch simulator sometimes treats the first click as focus and leaves
    /// the count unchanged. Wait for the label, and send a second click only
    /// when that one never arrived.
    private func tap(_ identifier: String, until expected: String) {
        let count = app.staticTexts[UITag.watchCount]
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing \(identifier)")
        let predicate = NSPredicate(format: "label == %@", expected)
        for attempt in 1...2 {
            if count.label == expected { return }
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let expectation = XCTNSPredicateExpectation(predicate: predicate, object: count)
            if XCTWaiter.wait(for: [expectation], timeout: 4) == .completed { return }
            if attempt == 2 {
                XCTFail("Tapping \(identifier) left the count at \"\(count.label)\", expected \"\(expected)\"")
            }
        }
    }
}
