//
//  OAuthLoopback.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 9/12/25.
//

import AppKit
import Foundation
import Network

final class OAuthLoopback {
    let forwardCallbackURL: String
    init(forwardCallbackURL: String) {
        self.forwardCallbackURL = forwardCallbackURL
    }

    private var listener: NWListener?
    private var handled = false
    private let queue = DispatchQueue(label: "oauth.loopback")

    /// Start loopback server and return the redirect URL once ready.
    /// Use the returned URL as your OAuth `redirect_uri`.
    func start(onCode: @escaping (_ code: String, _ state: String?) -> Void) async throws -> URL {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        let listener = try NWListener(using: params, on: 0)
        self.listener = listener

        listener.newConnectionHandler = { [weak self] conn in
            self?.handle(conn: conn, onCode: onCode)
        }

        // Await readiness and return the URL
        let redirectURL: URL = try await withCheckedThrowingContinuation { cont in
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard let port = listener.port?.rawValue else {
                        cont.resume(
                            throwing: NSError(
                                domain: "Loopback",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "No port assigned"]
                            )
                        )
                        return
                    }
                    cont.resume(returning: URL(string: "http://127.0.0.1:\(port)/callback")!)
                case .failed(let err):
                    cont.resume(throwing: err)
                default:
                    break
                }
            }
            listener.start(queue: self.queue)
        }

        return redirectURL
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(
        conn: NWConnection,
        onCode: @escaping (_ code: String, _ state: String?) -> Void
    ) {
        conn.start(queue: queue)

        var buffer = Data()
        func recv() {
            conn.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) {
                [weak self] data, _, isComplete, error in
                guard let self = self else { return }
                if let data = data { buffer.append(data) }
                if let range = buffer.range(of: Data([13, 10, 13, 10])) {  // \r\n\r\n
                    self.processRequest(
                        buffer.prefix(upTo: range.lowerBound),
                        conn: conn,
                        onCode: onCode
                    )
                    return
                }
                if isComplete || error != nil { conn.cancel() } else { recv() }
            }
        }
        recv()
    }

    private func processRequest(
        _ headerBytes: Data,
        conn: NWConnection,
        onCode: @escaping (_ code: String, _ state: String?) -> Void
    ) {
        guard let header = String(data: headerBytes, encoding: .utf8),
            let requestLine = header.components(separatedBy: "\r\n").first,
            requestLine.hasPrefix("GET ")
        else {
            conn.cancel()
            return
        }

        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            conn.cancel()
            return
        }
        let path = String(parts[1])

        guard let comps = URLComponents(string: "http://dummy\(path)") else {
            conn.cancel()
            return
        }
        let code = comps.queryItems?.first(where: { $0.name == "code" })?.value
        let state = comps.queryItems?.first(where: { $0.name == "state" })?.value

        let response =
            """
            HTTP/1.1 301 Moved Permanently\r
            Location: \(forwardCallbackURL)\(path)\r
            Content-Length: 0\r
            Connection: close\r
            \r
            """
        conn.send(
            content: Data(response.utf8),
            completion: .contentProcessed { _ in
                conn.cancel()
            }
        )

        if let code = code, !handled {
            handled = true
            DispatchQueue.main.async {
                onCode(code, state)
                self.stop()
            }
        }
    }
}
