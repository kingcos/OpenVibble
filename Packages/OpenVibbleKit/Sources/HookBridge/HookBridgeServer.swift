import Foundation
import Network

public enum HookBridgeAction: Sendable {
    case ignore
    case pendingApproval(id: UUID, payload: PreToolUsePayload)
    case fireAndForget(HookEvent, payload: Data)
}

public actor HookBridgeServer {
    public enum ServerError: Error { case notStarted, portUnknown, alreadyStarted }

    public let token: String
    private let queue: DispatchQueue = .init(label: "hookbridge.server")
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var port: UInt16?
    private var pending: [UUID: CheckedContinuation<HookEvent.PermissionDecisionKind, Never>] = [:]
    private var pendingPayloads: [UUID: PreToolUsePayload] = [:]

    private let router: @Sendable (_ event: HookEvent, _ body: Data) -> HookBridgeAction

    public init(
        token: String,
        router: @escaping @Sendable (HookEvent, Data) -> HookBridgeAction
    ) {
        self.token = token
        self.router = router
    }

    @discardableResult
    public func start() async throws -> UInt16 {
        if listener != nil { throw ServerError.alreadyStarted }
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: .ipv4(.loopback), port: .any)
        let l = try NWListener(using: params)
        self.listener = l

        l.newConnectionHandler = { [weak self] conn in
            guard let self else { conn.cancel(); return }
            conn.start(queue: self.queueForHandler())
            Task { await self.handle(conn) }
        }

        let port: UInt16 = try await withCheckedThrowingContinuation { cont in
            let resumed = ResumeGuard()
            l.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard resumed.claim() else { return }
                    if let p = l.port?.rawValue {
                        cont.resume(returning: p)
                    } else {
                        cont.resume(throwing: ServerError.portUnknown)
                    }
                case .failed(let err):
                    guard resumed.claim() else { return }
                    cont.resume(throwing: err)
                default: break
                }
            }
            l.start(queue: self.queue)
        }
        self.port = port
        return port
    }

    nonisolated private func queueForHandler() -> DispatchQueue {
        DispatchQueue(label: "hookbridge.conn")
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
        for (_, cont) in pending { cont.resume(returning: .ask) }
        pending.removeAll()
        pendingPayloads.removeAll()
    }

    public var currentPort: UInt16? { port }
    public var pendingCount: Int { pending.count }
    public var pendingIDs: [UUID] { Array(pending.keys) }
    public func pendingPayload(id: UUID) -> PreToolUsePayload? { pendingPayloads[id] }

    public func resolvePending(id: UUID, decision: HookEvent.PermissionDecisionKind) {
        guard let cont = pending.removeValue(forKey: id) else { return }
        pendingPayloads.removeValue(forKey: id)
        cont.resume(returning: decision)
    }

    public func cancelAllPending() {
        for (_, cont) in pending { cont.resume(returning: .ask) }
        pending.removeAll()
        pendingPayloads.removeAll()
    }

    private func handle(_ conn: NWConnection) async {
        connections.append(conn)
        let request = await HookHTTPReader.read(connection: conn)
        guard let request else {
            await send(conn, status: 400, body: Data())
            return
        }

        switch (request.method, request.path) {
        case ("GET", "/health"):
            let body = try? JSONSerialization.data(withJSONObject: [
                "name": "OpenVibbleDesktop",
                "version": "0.2.0",
                "ready": true
            ], options: [.sortedKeys])
            await send(conn, status: 200, contentType: "application/json", body: body ?? Data())

        case ("POST", "/permission-request"):
            guard verifyToken(request) else { await send(conn, status: 401, body: Data()); return }
            await handlePermissionRequest(conn: conn, body: request.body)

        case ("POST", "/pretooluse"):
            guard verifyToken(request) else { await send(conn, status: 401, body: Data()); return }
            _ = router(.preToolUse, request.body)
            await send(conn, status: 204, body: Data())

        case ("POST", "/prompt"):
            guard verifyToken(request) else { await send(conn, status: 401, body: Data()); return }
            _ = router(.userPromptSubmit, request.body)
            await send(conn, status: 204, body: Data())

        case ("POST", "/stop"):
            guard verifyToken(request) else { await send(conn, status: 401, body: Data()); return }
            _ = router(.stop, request.body)
            await send(conn, status: 204, body: Data())

        case ("POST", "/stop-failure"):
            guard verifyToken(request) else { await send(conn, status: 401, body: Data()); return }
            _ = router(.stopFailure, request.body)
            await send(conn, status: 204, body: Data())

        case ("POST", "/notification"):
            guard verifyToken(request) else { await send(conn, status: 401, body: Data()); return }
            _ = router(.notification, request.body)
            await send(conn, status: 204, body: Data())

        case ("POST", "/session-start"):
            guard verifyToken(request) else { await send(conn, status: 401, body: Data()); return }
            _ = router(.sessionStart, request.body)
            await send(conn, status: 204, body: Data())

        case ("POST", "/session-end"):
            guard verifyToken(request) else { await send(conn, status: 401, body: Data()); return }
            _ = router(.sessionEnd, request.body)
            await send(conn, status: 204, body: Data())

        case ("POST", "/subagent-start"):
            guard verifyToken(request) else { await send(conn, status: 401, body: Data()); return }
            _ = router(.subagentStart, request.body)
            await send(conn, status: 204, body: Data())

        case ("POST", "/subagent-stop"):
            guard verifyToken(request) else { await send(conn, status: 401, body: Data()); return }
            _ = router(.subagentStop, request.body)
            await send(conn, status: 204, body: Data())

        default:
            await send(conn, status: 404, body: Data())
        }
    }

    private func handlePermissionRequest(conn: NWConnection, body: Data) async {
        let action = router(.permissionRequest, body)
        switch action {
        case .pendingApproval(let id, let payload):
            pendingPayloads[id] = payload
            let decision: HookEvent.PermissionDecisionKind = await withCheckedContinuation { cont in
                self.pending[id] = cont
            }
            let responseBody = Self.encodePermissionRequestResponse(decision: decision)
            await send(conn, status: 200, contentType: "application/json", body: responseBody)
        case .ignore, .fireAndForget:
            let fallback = Self.encodePermissionRequestResponse(decision: .ask)
            await send(conn, status: 200, contentType: "application/json", body: fallback)
        }
    }

    private static func encodePermissionRequestResponse(decision: HookEvent.PermissionDecisionKind) -> Data {
        // PermissionRequest hook schema: hookSpecificOutput.decision.behavior must be "allow" or "deny".
        // If the user chose "ask", we return empty hookSpecificOutput so Claude falls back to the
        // native permission dialog.
        let output: [String: Any]
        switch decision {
        case .allow:
            output = [
                "hookEventName": "PermissionRequest",
                "decision": [
                    "behavior": "allow"
                ]
            ]
        case .deny:
            output = [
                "hookEventName": "PermissionRequest",
                "decision": [
                    "behavior": "deny",
                    "message": "Denied from OpenVibbleDesktop"
                ]
            ]
        case .ask:
            output = [
                "hookEventName": "PermissionRequest"
            ]
        }
        let payload: [String: Any] = ["hookSpecificOutput": output]
        return (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? Data()
    }

    private func verifyToken(_ req: HookHTTPRequest) -> Bool {
        req.headers["x-ovd-token"] == token
    }

    private func send(_ conn: NWConnection, status: Int, contentType: String = "text/plain", body: Data) async {
        let statusText = Self.statusText(status)
        var head = "HTTP/1.1 \(status) \(statusText)\r\n"
        head += "Content-Type: \(contentType)\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Connection: close\r\n\r\n"
        var data = Data(head.utf8)
        data.append(body)
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            conn.send(content: data, completion: .contentProcessed { _ in
                conn.cancel()
                cont.resume()
            })
        }
    }

    private static func statusText(_ code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 204: return "No Content"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 404: return "Not Found"
        default: return "Status"
        }
    }
}

private final class ResumeGuard: @unchecked Sendable {
    private var resumed = false
    private let lock = NSLock()
    func claim() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if resumed { return false }
        resumed = true
        return true
    }
}

struct HookHTTPRequest: Sendable {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data
}

enum HookHTTPReader {
    static func read(connection: NWConnection) async -> HookHTTPRequest? {
        var accumulated = Data()
        while true {
            let chunk: Data? = await withCheckedContinuation { (cont: CheckedContinuation<Data?, Never>) in
                connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { data, _, isComplete, _ in
                    if let data, !data.isEmpty {
                        cont.resume(returning: data)
                    } else if isComplete {
                        cont.resume(returning: nil)
                    } else {
                        cont.resume(returning: Data())
                    }
                }
            }
            guard let chunk else { return parse(accumulated) }
            accumulated.append(chunk)
            if let parsed = parse(accumulated), parsed.body.count >= expectedBodyLength(accumulated) {
                return parsed
            }
        }
    }

    private static func expectedBodyLength(_ data: Data) -> Int {
        guard let headEnd = range(of: "\r\n\r\n", in: data) else { return 0 }
        let head = data.subdata(in: 0..<headEnd.lowerBound)
        guard let headStr = String(data: head, encoding: .utf8) else { return 0 }
        for line in headStr.split(separator: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 && parts[0].lowercased() == "content-length" {
                return Int(parts[1]) ?? 0
            }
        }
        return 0
    }

    private static func parse(_ data: Data) -> HookHTTPRequest? {
        guard let headEnd = range(of: "\r\n\r\n", in: data) else { return nil }
        let head = data.subdata(in: 0..<headEnd.lowerBound)
        let body = data.subdata(in: headEnd.upperBound..<data.count)
        guard let headStr = String(data: head, encoding: .utf8) else { return nil }
        let lines = headStr.components(separatedBy: "\r\n")
        guard let first = lines.first else { return nil }
        let parts = first.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        let method = String(parts[0])
        let path = String(parts[1])
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let kv = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if kv.count == 2 { headers[kv[0].lowercased()] = kv[1] }
        }
        let expected = Int(headers["content-length"] ?? "0") ?? 0
        let trimmedBody = body.count >= expected ? body.subdata(in: 0..<expected) : body
        return HookHTTPRequest(method: method, path: path, headers: headers, body: trimmedBody)
    }

    private static func range(of needle: String, in data: Data) -> Range<Data.Index>? {
        let needleBytes = Data(needle.utf8)
        return data.range(of: needleBytes)
    }
}
