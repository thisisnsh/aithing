//
//  McpOAuthManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 9/9/25.
//

import AppKit
import AuthenticationServices
import Foundation
import OAuthSwift
import os

public struct McpToken: Codable, Equatable {
    public var accessToken: String
    public var refreshToken: String?
    public var expiresAt: Date?
}

enum McpOAuthError: LocalizedError {
    case cancelled
    case invalidMcpUrl
    case mcpUrlDecodeFailed
    case mcpBaseUrlDecodeFailed
    case getWellKnownUrlsFailed
    case missingWellKnownUrls
    case invalidRegistrationEndpoint
    case registrationFailed
    case invalidCallbackUrl
    case authorizationFailed

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Authorization was cancelled by the user."
        case .invalidMcpUrl:
            return "Invalid MCP URL."
        case .mcpUrlDecodeFailed:
            return "Failed to decode the MCP URL."
        case .mcpBaseUrlDecodeFailed:
            return "Failed to decode the MCP base URL."
        case .getWellKnownUrlsFailed:
            return "Unable to fetch well-known OAuth endpoints."
        case .missingWellKnownUrls:
            return "Missing well-known OAuth endpoints."
        case .invalidRegistrationEndpoint:
            return "The registration endpoint is invalid."
        case .registrationFailed:
            return "Dynamic client registration failed."
        case .invalidCallbackUrl:
            return "The callback URL is invalid."
        case .authorizationFailed:
            return "Authorization failed."
        }
    }
}

struct RegisteredClient: Codable {
    let client_id: String
    let client_secret: String?
}

struct WellKnownUrls: Codable {
    let issuer: String
    let authorization_endpoint: String
    let token_endpoint: String
    let registration_endpoint: String
    let scopes_supported: [String]?
}

struct McpServer: Codable {
    let id: String?
    var image: String?
    let name: String
    let url: String
    let version: Int?
    let enabled: Bool?
}

@MainActor
final class McpOAuthManagers: ObservableObject {
    @Published var managers: [String: McpOAuthManager] = [:]
    @Published var selfManagers: [String: McpOAuthManager] = [:]
}

@MainActor
final class McpOAuthManager: ObservableObject, Identifiable {
    let id = UUID()
    @Published var user: McpToken?
    @Published var enabled: Bool = false

    private let logger = Logger(
        subsystem: "com.thisisnsh.mac.AIThing",
        category: "McpOAuthManager"
    )

    private var wellKnownUrls: WellKnownUrls?
    private var callbackURLString = ""
    private var oauth: OAuth2Swift?

    var server: McpServer
    private let forwardCallbackScheme: String
    private let forwardCallbackURL: String

    init(server: McpServer) {
        self.server = server
        self.forwardCallbackScheme = "oauth-aithing"
        self.forwardCallbackURL =
            "\(forwardCallbackScheme)://oauth-callback-\(server.name.lowercased().replacingOccurrences(of: " ", with: "-"))"

    }

    func generateToken(refresh: Bool) async -> McpToken? {
        do {
            try await getWellKnownUrls()

            AnalyticsManager.shared.customEvent(
                view: .McpOAuthManager,
                primary: .url,
                secondary: server.url,
                sev: .info
            )

            if refresh {
                if let user = self.user {
                    if tokenIsValid(user) {
                        return user
                    }
                }
                if let current = user, let rt = current.refreshToken,
                    refresh || !tokenIsValid(current)
                {
                    if let renewed = try await renewAccessToken(refreshToken: rt) {
                        self.user = userFromCreds(credential: renewed.credential)
                        return self.user
                    }
                    // fallthrough to full auth if refresh failed
                }
            }

            let loopback = OAuthLoopback(forwardCallbackURL: forwardCallbackURL)
            let redirectURL = try await loopback.start { _, _ in }

            callbackURLString = redirectURL.absoluteString
            let client = try await registerClient()
            let oauth = try makeOAuth(
                client: client,
                forwardCallbackScheme: forwardCallbackScheme
            )
            self.oauth = oauth

            let cred = try await authorizeInteractively()
            self.user = userFromCreds(credential: cred)
            return self.user
        } catch {
            logger.error("Mcp generateToken error: \(error.localizedDescription)")
            self.user = nil
            return nil
        }
    }

    func resetToken() {
        user = nil
    }
}

extension McpOAuthManager {
    private func getWellKnownUrls() async throws {
        guard let mcpUrl = URL(string: self.server.url) else {
            throw McpOAuthError.invalidMcpUrl
        }
        guard var comps = URLComponents(url: mcpUrl, resolvingAgainstBaseURL: false),
            comps.scheme != nil,
            comps.host != nil
        else {
            throw McpOAuthError.mcpUrlDecodeFailed
        }
        comps.path = ""  // strip path
        comps.query = nil  // strip query
        comps.fragment = nil  // strip fragment
        guard let baseUrl = comps.url else {
            throw McpOAuthError.mcpBaseUrlDecodeFailed
        }

        var req = URLRequest(url: baseUrl.appending(path: ".well-known/oauth-authorization-server"))
        req.httpMethod = "GET"

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw McpOAuthError.getWellKnownUrlsFailed
        }
        self.wellKnownUrls = try JSONDecoder().decode(WellKnownUrls.self, from: data)
    }

    private func registerClient() async throws -> RegisteredClient {
        guard let wellKnownUrls = wellKnownUrls else { throw McpOAuthError.missingWellKnownUrls }
        guard let registrationEndpoint = URL(string: wellKnownUrls.registration_endpoint) else {
            throw McpOAuthError.invalidRegistrationEndpoint
        }

        var req = URLRequest(url: registrationEndpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "application_type": "native",
            "client_name": "AIThing (macOS)",
            "client_uri": "https://aithing.dev",
            "redirect_uris": [callbackURLString],
            "grant_types": ["authorization_code", "refresh_token"],
            "response_types": ["code"],
            "token_endpoint_auth_method": "client_secret_post",
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw McpOAuthError.registrationFailed
        }
        let registered = try JSONDecoder().decode(RegisteredClient.self, from: data)

        return registered
    }

    private func makeOAuth(
        client: RegisteredClient,
        forwardCallbackScheme: String
    ) throws
        -> OAuth2Swift
    {
        guard let wellKnownUrls = wellKnownUrls else { throw McpOAuthError.missingWellKnownUrls }

        let oauth = OAuth2Swift(
            consumerKey: client.client_id,
            consumerSecret: client.client_secret ?? "",
            authorizeUrl: wellKnownUrls.authorization_endpoint,
            accessTokenUrl: wellKnownUrls.token_endpoint,
            responseType: "code"
        )
        oauth.accessTokenBasicAuthentification = false
        oauth.authorizeURLHandler = MyASWebAuthURLHandler(
            callbackScheme: forwardCallbackScheme
        )
        return oauth
    }

    private func authorizeInteractively() async throws -> OAuthSwiftCredential {
        guard let wellKnownUrls = wellKnownUrls else { throw McpOAuthError.missingWellKnownUrls }

        guard let callbackURL = URL(string: callbackURLString) else {
            throw McpOAuthError.invalidCallbackUrl
        }

        var scopes = ""
        if let scopesArray = wellKnownUrls.scopes_supported {
            scopes = scopesArray.joined(separator: " ")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let _ = self.oauth!.authorize(
                withCallbackURL: callbackURL,
                scope: scopes,
                state: UUID().uuidString,
                parameters: [:]
            ) { result in
                switch result {
                case .success(let (cred, _, _)):
                    continuation.resume(returning: cred)
                case .failure(let err):
                    self.logger.error("Auth failed: \(err.localizedDescription)")
                    if err.errorCode == OAuthSwiftError.cancelled.errorCode {
                        continuation.resume(throwing: McpOAuthError.cancelled)
                    } else {
                        continuation.resume(throwing: McpOAuthError.authorizationFailed)
                    }
                }
            }
        }
    }

    private func getAccessToken(code: String) async throws -> OAuthSwift.TokenSuccess? {
        guard let oauth else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            let _ = oauth.postOAuthAccessTokenWithRequestToken(
                byCode: code,
                callbackURL: URL(string: callbackURLString)!,
                headers: nil,
                completionHandler: { result in
                    switch result {
                    case .success(let success):
                        continuation.resume(returning: success)
                    case .failure(let err):
                        self.logger.error("Get token failed: \(err.localizedDescription)")
                        continuation.resume(returning: nil)  // fall back to full auth
                    }
                }
            )
        }
    }

    private func renewAccessToken(refreshToken: String) async throws -> OAuthSwift.TokenSuccess? {
        guard let oauth else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            let _ = oauth.renewAccessToken(withRefreshToken: refreshToken) { result in
                switch result {
                case .success(let success):
                    continuation.resume(returning: success)
                case .failure(let err):
                    self.logger.error("Refresh token failed: \(err.localizedDescription)")
                    continuation.resume(returning: nil)  // fall back to full auth
                }
            }
        }
    }

    private func tokenIsValid(_ user: McpToken) -> Bool {
        guard let exp = user.expiresAt else { return !user.accessToken.isEmpty }
        // Renew 60 seconds early
        return Date() < exp.addingTimeInterval(-60)
    }

    private func userFromCreds(credential: OAuthSwiftCredential) -> McpToken {
        var user = McpToken(accessToken: credential.oauthToken)
        if !credential.oauthRefreshToken.isEmpty {
            user.refreshToken = credential.oauthRefreshToken
        }
        user.expiresAt = credential.oauthTokenExpiresAt
        return user
    }

    static func hasWellKnownUrls(url: String) async -> Bool {
        do {
            guard let mcpUrl = URL(string: url) else {
                return false
            }
            guard var comps = URLComponents(url: mcpUrl, resolvingAgainstBaseURL: false),
                comps.scheme != nil,
                comps.host != nil
            else {
                return false
            }
            comps.path = ""  // strip path
            comps.query = nil  // strip query
            comps.fragment = nil  // strip fragment
            guard let baseUrl = comps.url else {
                return false
            }

            var req = URLRequest(
                url: baseUrl.appending(path: ".well-known/oauth-authorization-server")
            )
            req.httpMethod = "GET"

            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return false
            }
            return true
        } catch {
            return false
        }
    }

}
