import XCTest
@testable import OpenVibbleApp

final class SmokeTests: XCTestCase {
    @MainActor
    func testAppModelBootstraps() {
        let model = BridgeAppModel()
        XCTAssertNotNil(model)
    }
}
