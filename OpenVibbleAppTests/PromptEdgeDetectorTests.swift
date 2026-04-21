import XCTest
@testable import OpenVibbleApp

final class PromptEdgeDetectorTests: XCTestCase {
    func testDetectsRisingEdge() {
        var d = PromptEdgeDetector()
        XCTAssertFalse(d.consume(false))
        XCTAssertTrue(d.consume(true), "false→true should fire")
    }

    func testIgnoresSteadyTrue() {
        var d = PromptEdgeDetector()
        _ = d.consume(true)
        XCTAssertFalse(d.consume(true), "true→true should not fire")
        XCTAssertFalse(d.consume(true))
    }

    func testIgnoresFallingEdge() {
        var d = PromptEdgeDetector()
        _ = d.consume(true)
        XCTAssertFalse(d.consume(false), "true→false should not fire")
    }

    func testRefiresAfterClear() {
        var d = PromptEdgeDetector()
        _ = d.consume(true)
        _ = d.consume(false)
        XCTAssertTrue(d.consume(true), "new prompt after clear should fire again")
    }
}
