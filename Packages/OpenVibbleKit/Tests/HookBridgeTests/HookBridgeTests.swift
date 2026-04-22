import Testing
@testable import HookBridge

@Suite("HookBridge module")
struct HookBridgeModuleTests {
    @Test("protocol version is 1")
    func protocolVersion() {
        #expect(HookBridge.protocolVersion == 1)
    }
}
