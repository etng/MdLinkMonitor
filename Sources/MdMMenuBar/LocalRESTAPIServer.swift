import Foundation
import Network

struct LocalRESTAPIConfiguration: Equatable, Sendable {
    var enabled: Bool
    var bindAddress: String
    var port: Int
    var token: String
}

struct LocalRESTAPIServerResponse: Sendable {
    var statusCode: Int
    var body: Data
}

final class LocalRESTAPIServer: @unchecked Sendable {
    typealias CaptureHandler = (_ markdown: String, _ completion: @escaping @Sendable (LocalRESTAPIServerResponse) -> Void) -> Void
    typealias DailyHandler = (_ date: String?, _ completion: @escaping @Sendable (LocalRESTAPIServerResponse) -> Void) -> Void
    typealias StatusHandler = (_ message: String) -> Void

    private struct HTTPRequest {
        let method: String
        let path: String
        let query: [String: String]
        let headers: [String: String]
        let body: Data
    }

    private enum ParseResult {
        case complete(HTTPRequest)
        case incomplete
        case invalid(String)
    }

    private static let headerDelimiter = Data("\r\n\r\n".utf8)

    private let queue = DispatchQueue(label: "com.y10n.mdmonitor.rest-api", qos: .utility)
    private var listener: NWListener?
    private var currentConfiguration = LocalRESTAPIConfiguration(
        enabled: false,
        bindAddress: "127.0.0.1",
        port: 18731,
        token: ""
    )
    private var captureHandler: CaptureHandler?
    private var dailyHandler: DailyHandler?
    private var statusHandler: StatusHandler?

    func apply(
        configuration: LocalRESTAPIConfiguration,
        captureHandler: CaptureHandler?,
        dailyHandler: DailyHandler?,
        statusHandler: StatusHandler?
    ) {
        self.captureHandler = captureHandler
        self.dailyHandler = dailyHandler
        self.statusHandler = statusHandler

        let normalized = LocalRESTAPIConfiguration(
            enabled: configuration.enabled,
            bindAddress: configuration.bindAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            port: configuration.port,
            token: configuration.token.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        let shouldRestart = normalized != currentConfiguration || (normalized.enabled && listener == nil) || (!normalized.enabled && listener != nil)
        currentConfiguration = normalized
        guard shouldRestart else { return }

        restartListener()
    }

    func stop() {
        stopListener()
    }

    private func restartListener() {
        stopListener()

        guard currentConfiguration.enabled else {
            statusHandler?("REST API disabled")
            return
        }

        guard (1...65535).contains(currentConfiguration.port),
              let port = NWEndpoint.Port(rawValue: UInt16(currentConfiguration.port))
        else {
            statusHandler?("REST API failed: invalid port \(currentConfiguration.port)")
            return
        }

        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            parameters.requiredLocalEndpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(currentConfiguration.bindAddress),
                port: port
            )
            let listener = try NWListener(using: parameters, on: port)

            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    self.statusHandler?(
                        "REST API listening on \(self.currentConfiguration.bindAddress):\(self.currentConfiguration.port)"
                    )
                case .failed(let error):
                    self.statusHandler?("REST API failed: \(error.localizedDescription)")
                case .cancelled:
                    self.statusHandler?("REST API stopped")
                default:
                    break
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection: connection)
            }

            self.listener = listener
            listener.start(queue: queue)
        } catch {
            statusHandler?("REST API failed to start: \(error.localizedDescription)")
        }
    }

    private func stopListener() {
        listener?.cancel()
        listener = nil
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(on: connection, buffer: Data())
    }

    private func receiveRequest(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }

            var merged = buffer
            if let content {
                merged.append(content)
            }

            switch self.parseRequest(from: merged) {
            case .complete(let request):
                self.handle(request: request, on: connection)
                return
            case .invalid(let reason):
                self.send(
                    self.jsonResponse(statusCode: 400, jsonObject: ["error": reason]),
                    on: connection
                )
                return
            case .incomplete:
                break
            }

            if isComplete {
                self.send(
                    self.jsonResponse(statusCode: 400, jsonObject: ["error": "incomplete request"]),
                    on: connection
                )
                return
            }

            if let error {
                self.send(
                    self.jsonResponse(statusCode: 500, jsonObject: ["error": error.localizedDescription]),
                    on: connection
                )
                return
            }

            self.receiveRequest(on: connection, buffer: merged)
        }
    }

    private func parseRequest(from data: Data) -> ParseResult {
        guard let headersRange = data.range(of: Self.headerDelimiter) else {
            return .incomplete
        }

        let headerData = data[..<headersRange.lowerBound]
        guard let headerText = String(data: headerData, encoding: .utf8) else {
            return .invalid("invalid request headers encoding")
        }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first, !requestLine.isEmpty else {
            return .invalid("missing request line")
        }

        let requestParts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard requestParts.count >= 2 else {
            return .invalid("invalid request line")
        }

        let method = String(requestParts[0]).uppercased()
        let target = String(requestParts[1])

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let name = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            headers[name] = value
        }

        let contentLength = Int(headers["content-length"] ?? "") ?? 0
        let bodyStart = headersRange.upperBound
        let totalExpected = bodyStart + contentLength
        guard data.count >= totalExpected else {
            return .incomplete
        }

        let body = data[bodyStart..<totalExpected]
        let pathAndQuery = parsePathAndQuery(target: target)

        return .complete(
            HTTPRequest(
                method: method,
                path: normalizePath(pathAndQuery.path),
                query: pathAndQuery.query,
                headers: headers,
                body: Data(body)
            )
        )
    }

    private func handle(request: HTTPRequest, on connection: NWConnection) {
        if !isAuthorized(request: request) {
            send(
                jsonResponse(statusCode: 401, jsonObject: ["error": "unauthorized"]),
                on: connection
            )
            return
        }

        if request.method == "GET", request.path == "/api/v1/health" {
            send(
                jsonResponse(
                    statusCode: 200,
                    jsonObject: [
                        "ok": true,
                        "bindAddress": currentConfiguration.bindAddress,
                        "port": currentConfiguration.port,
                    ]
                ),
                on: connection
            )
            return
        }

        if request.method == "POST", request.path == "/api/v1/capture" {
            let markdown = extractMarkdown(from: request)
            guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                send(
                    jsonResponse(statusCode: 400, jsonObject: ["error": "missing markdown content"]),
                    on: connection
                )
                return
            }

            guard let captureHandler else {
                send(
                    jsonResponse(statusCode: 503, jsonObject: ["error": "capture handler unavailable"]),
                    on: connection
                )
                return
            }

            captureHandler(markdown) { [weak self] response in
                guard let self else {
                    connection.cancel()
                    return
                }
                self.send(response, on: connection)
            }
            return
        }

        if request.method == "GET", request.path == "/api/v1/daily" {
            guard let dailyHandler else {
                send(
                    jsonResponse(statusCode: 503, jsonObject: ["error": "daily handler unavailable"]),
                    on: connection
                )
                return
            }

            dailyHandler(request.query["date"]) { [weak self] response in
                guard let self else {
                    connection.cancel()
                    return
                }
                self.send(response, on: connection)
            }
            return
        }

        send(
            jsonResponse(statusCode: 404, jsonObject: ["error": "endpoint not found"]),
            on: connection
        )
    }

    private func send(_ response: LocalRESTAPIServerResponse, on connection: NWConnection) {
        let body = response.body
        let reason = reasonPhrase(for: response.statusCode)
        var packet = Data()
        packet.append(Data("HTTP/1.1 \(response.statusCode) \(reason)\r\n".utf8))
        packet.append(Data("Content-Type: application/json; charset=utf-8\r\n".utf8))
        packet.append(Data("Content-Length: \(body.count)\r\n".utf8))
        packet.append(Data("Connection: close\r\n\r\n".utf8))
        packet.append(body)

        connection.send(content: packet, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func reasonPhrase(for statusCode: Int) -> String {
        switch statusCode {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 404: return "Not Found"
        case 422: return "Unprocessable Entity"
        case 500: return "Internal Server Error"
        case 503: return "Service Unavailable"
        default: return "OK"
        }
    }

    private func jsonResponse(statusCode: Int, jsonObject: [String: Any]) -> LocalRESTAPIServerResponse {
        let body: Data
        if JSONSerialization.isValidJSONObject(jsonObject),
           let encoded = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) {
            body = encoded
        } else {
            body = Data("{\"error\":\"invalid json response\"}".utf8)
        }

        return LocalRESTAPIServerResponse(statusCode: statusCode, body: body)
    }

    private func isAuthorized(request: HTTPRequest) -> Bool {
        let expectedToken = currentConfiguration.token
        guard !expectedToken.isEmpty else { return false }

        if let auth = request.headers["authorization"] {
            let lowercased = auth.lowercased()
            if lowercased.hasPrefix("bearer ") {
                let index = auth.index(auth.startIndex, offsetBy: 7)
                let candidate = String(auth[index...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if candidate == expectedToken {
                    return true
                }
            }
        }

        if request.headers["x-mdm-token"] == expectedToken {
            return true
        }

        if request.query["token"] == expectedToken {
            return true
        }

        return false
    }

    private func extractMarkdown(from request: HTTPRequest) -> String {
        let contentType = request.headers["content-type"]?.lowercased() ?? ""
        if contentType.contains("application/json"),
           let object = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any] {
            if let markdown = object["markdown"] as? String {
                return markdown
            }
            if let content = object["content"] as? String {
                return content
            }
        }

        return String(data: request.body, encoding: .utf8) ?? ""
    }

    private func parsePathAndQuery(target: String) -> (path: String, query: [String: String]) {
        let normalizedTarget = target.hasPrefix("/") ? target : "/\(target)"
        guard let components = URLComponents(string: "http://localhost\(normalizedTarget)") else {
            return (normalizedTarget, [:])
        }

        var query: [String: String] = [:]
        for item in components.queryItems ?? [] {
            query[item.name] = item.value ?? ""
        }
        return (components.path, query)
    }

    private func normalizePath(_ path: String) -> String {
        if path.count > 1, path.hasSuffix("/") {
            return String(path.dropLast())
        }
        return path
    }
}
