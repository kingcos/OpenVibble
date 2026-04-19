import XCTest
@testable import ClaudeBuddyBridgeApp

final class SmokeTests: XCTestCase {
    @MainActor
    func testAppModelBootstraps() {
        let model = BridgeAppModel()
        XCTAssertNotNil(model)
    }
}
