import XCTest
@testable import NUSCentral
import BuddyProtocol

final class CentralInboundDecoderTests: XCTestCase {
    func testHeartbeatDecodes() {
        let line = #"{"total":3,"running":1,"waiting":1,"msg":"approve: Bash","entries":["git push"],"tokens":10,"tokens_today":2,"prompt":{"id":"r1","tool":"Bash","hint":"ls"}}"#
        guard case let .heartbeat(snapshot) = CentralInboundDecoder.decode(line) else {
            return XCTFail("expected heartbeat")
        }
        XCTAssertEqual(snapshot.total, 3)
        XCTAssertEqual(snapshot.running, 1)
        XCTAssertEqual(snapshot.waiting, 1)
        XCTAssertEqual(snapshot.prompt?.id, "r1")
        XCTAssertEqual(snapshot.prompt?.tool, "Bash")
    }

    func testAckDecodes() {
        let line = #"{"ack":"status","ok":true,"n":0}"#
        guard case let .ack(ack) = CentralInboundDecoder.decode(line) else {
            return XCTFail("expected ack")
        }
        XCTAssertEqual(ack.ack, "status")
        XCTAssertTrue(ack.ok)
    }

    func testTurnDecodes() {
        let line = #"{"evt":"turn","role":"assistant","content":[]}"#
        guard case let .turn(turn) = CentralInboundDecoder.decode(line) else {
            return XCTFail("expected turn")
        }
        XCTAssertEqual(turn.role, "assistant")
    }

    func testTimeSyncDecodes() {
        let line = #"{"time":[1775731234,-25200]}"#
        guard case let .timeSync(time) = CentralInboundDecoder.decode(line) else {
            return XCTFail("expected timeSync")
        }
        XCTAssertEqual(time.epochSeconds, 1775731234)
        XCTAssertEqual(time.timezoneOffsetSeconds, -25200)
    }

    func testUnknownFallsThrough() {
        let line = #"{"weirdo":true}"#
        guard case let .unknown(raw) = CentralInboundDecoder.decode(line) else {
            return XCTFail("expected unknown")
        }
        XCTAssertEqual(raw, line)
    }

    /// End-to-end: feed a chunked NDJSON byte stream (mimicking 180-byte BLE
    /// notify fragments) through the same `NDJSONLineFramer` used in the
    /// central service, then decode each line. Exercises the realistic path
    /// where a heartbeat straddles a chunk boundary.
    func testFramerReassemblesAcrossChunks() throws {
        let heartbeat = #"{"total":3,"running":1,"waiting":1,"msg":"approve: Bash","entries":["git push"],"tokens":10,"tokens_today":2,"prompt":{"id":"r1","tool":"Bash","hint":"ls"}}"#
        let ack = #"{"ack":"status","ok":true,"n":0}"#
        let payload = Data((heartbeat + "\n" + ack + "\n").utf8)

        var framer = NDJSONLineFramer()
        var collected: [CentralInboundMessage] = []
        let chunkSize = 32
        var offset = 0
        while offset < payload.count {
            let count = min(chunkSize, payload.count - offset)
            let slice = payload.subdata(in: offset..<(offset + count))
            let lines = try framer.ingest(slice)
            collected.append(contentsOf: lines.map(CentralInboundDecoder.decode))
            offset += count
        }

        XCTAssertEqual(collected.count, 2)
        guard case .heartbeat = collected[0] else { return XCTFail("first should be heartbeat") }
        guard case .ack = collected[1] else { return XCTFail("second should be ack") }
    }
}
