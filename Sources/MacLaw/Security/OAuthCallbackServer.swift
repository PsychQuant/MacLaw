import Foundation
import Network
import os

/// Lightweight HTTP server that listens on localhost:1455 for a single OAuth callback.
final class OAuthCallbackServer: Sendable {
    private let port: UInt16
    private let lock = OSAllocatedUnfairLock(initialState: NWListener?.none)

    init(port: UInt16 = 1455) {
        self.port = port
    }

    /// Wait for the OAuth callback and return the authorization code.
    func waitForCode(timeoutSeconds: Int = 120) async throws -> String {
        let (stream, continuation) = AsyncStream<Result<String, Error>>.makeStream()
        let didResume = OSAllocatedUnfairLock(initialState: false)

        @Sendable func emitOnce(_ result: Result<String, Error>) {
            let first = didResume.withLock { r -> Bool in
                if r { return false }
                r = true
                return true
            }
            if first {
                continuation.yield(result)
                continuation.finish()
            }
        }

        let params = NWParameters.tcp
        let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        lock.withLock { $0 = listener }

        listener.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                emitOnce(.failure(OAuthError.serverFailed(error.localizedDescription)))
            }
        }

        listener.newConnectionHandler = { connection in
            connection.start(queue: .global())
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
                guard let data, let request = String(data: data, encoding: .utf8) else {
                    connection.cancel()
                    return
                }

                let code = Self.extractCode(from: request)

                let html = """
                HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n\
                <html><body><h2>Authentication successful!</h2>\
                <p>You can close this tab and return to the terminal.</p></body></html>
                """
                connection.send(content: html.data(using: .utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })

                if let code {
                    emitOnce(.success(code))
                } else {
                    emitOnce(.failure(OAuthError.noCodeInCallback))
                }
            }
        }

        listener.start(queue: .global())

        // Timeout
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(timeoutSeconds)) {
            emitOnce(.failure(OAuthError.timeout))
        }

        // Wait for the first result
        for await result in stream {
            stop()
            return try result.get()
        }

        stop()
        throw OAuthError.timeout
    }

    func stop() {
        lock.withLock { listener in
            listener?.cancel()
            listener = nil
        }
    }

    /// Check if the port is available.
    static func isPortAvailable(_ port: UInt16) -> Bool {
        let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socket >= 0 else { return false }
        defer { Darwin.close(socket) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = UInt32(INADDR_LOOPBACK).bigEndian

        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return result == 0
    }

    private static func extractCode(from request: String) -> String? {
        guard let urlLine = request.split(separator: "\r\n").first ?? request.split(separator: "\n").first else {
            return nil
        }
        let parts = urlLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        let path = String(parts[1])
        guard let components = URLComponents(string: "http://localhost\(path)") else { return nil }
        return components.queryItems?.first(where: { $0.name == "code" })?.value
    }
}

enum OAuthError: Error, LocalizedError {
    case serverFailed(String)
    case noCodeInCallback
    case timeout
    case tokenExchangeFailed(String)
    case refreshFailed(String)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .serverFailed(let msg): "Callback server failed: \(msg)"
        case .noCodeInCallback: "No authorization code in callback"
        case .timeout: "OAuth login timed out (120s). Try again."
        case .tokenExchangeFailed(let msg): "Token exchange failed: \(msg)"
        case .refreshFailed(let msg): "Token refresh failed: \(msg). Run 'maclaw auth login' again."
        case .notAuthenticated: "Not authenticated. Run 'maclaw auth login' first."
        }
    }
}
