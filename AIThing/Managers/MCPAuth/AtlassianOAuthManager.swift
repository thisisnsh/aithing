//
//  AtlassianOAuthManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 9/9/25.
//

import AppKit
import AuthenticationServices
import Foundation
import OAuthSwift
import os

@MainActor
final class AtlassianOAuthManager: ObservableObject {
    @Published var user: AtlassianUser?
    @Published var enabled: Set<AtlassianTool> = []

    private let logger = Logger(
        subsystem: "com.thisisnsh.mac.AIThing",
        category: "AtlassianOAuthManager"
    )

    // MARK: - OAuth endpoints (MCP)
    private let issuer = URL(
        string:
            "https://atlassian-remote-mcp-production.atlassian-remote-mcp-server-production.workers.dev"
    )!
    private var authorizationEndpoint = URL(string: "https://mcp.atlassian.com/v1/authorize")!
    private var tokenEndpoint: URL { issuer.appending(path: "v1/token") }
    private var registrationEndpoint: URL { issuer.appending(path: "v1/register") }

    // MARK: - Redirect / callback
    private let callbackScheme = "oauth-aithing"
    private let callbackURLString = "oauth-aithing://oauth-callback-atlassian"

    // MARK: - Client cache (Keychain)
    private let kc = Keychain(service: "com.thisisnsh.mac.AIThing.atlassian.oauth")
    private let kcClientIDKey = "atlassian.client_id"
    private let kcClientSecretKey = "atlassian.client_secret"

    // MARK: - OAuth engine (created lazily after registration)
    private var oauth: OAuth2Swift?

    // MARK: - Public API

    /// Generates (or refreshes) a Bearer token and returns a hydrated `AtlassianUser?`.
    /// - Parameter refresh: when true, tries to refresh first if a refresh token is available.
    func generateToken(refresh: Bool) async -> AtlassianUser? {
        do {
            // Ensure we have a registered client (cached or newly registered)
            let creds = try await ensureClientRegistered()

            // Build OAuth engine using the dynamic client
            let oauth = makeOAuth(creds: creds)
            self.oauth = oauth

            // Try refresh if requested and possible
            if refresh {
                if let existing = self.user, tokenIsValid(existing) {
                    return existing
                }
                if let rt = self.user?.refreshToken {
                    if let renewed = try await renewAccessToken(refreshToken: rt) {
                        let profile = try await fetchProfile(
                            accessToken: renewed.credential.oauthToken
                        )
                        let merged = merge(profile: profile, credential: renewed.credential)
                        self.user = merged
                        return merged
                    }
                }
                // fall through to interactive auth
            }

            // Full OAuth authorization
            let cred = try await authorizeInteractively(oauth: oauth)
            let profile = try await fetchProfile(accessToken: cred.oauthToken)
            let merged = merge(profile: profile, credential: cred)
            self.user = merged
            return self.user
        } catch {
            logger.error("Atlassian generateToken error: \(error.localizedDescription)")
            self.user = nil
            return nil
        }
    }

    func resetToken() {
        user = nil
    }

    enum AtlassianTool: String, CaseIterable, Identifiable {
        case search = "Search"
        case pages = "Pages"
        case databases = "Databases"
        case comments = "Comments"

        var id: String { rawValue }
    }

    let toolScopesMap: [AtlassianTool: [String]] = [
        .search: [],
        .pages: [],
        .databases: [],
        .comments: [],
    ]

    let toolCapabilities: [AtlassianTool: [String]] = [
        .search: [
            "search",
            "fetch",
        ],
        .pages: [
            "notion-create-pages",
            "notion-update-page",
            "notion-move-pages",
            "notion-duplicate-page",
        ],
        .databases: [
            "notion-create-database",
            "notion-update-database",
        ],
        .comments: [
            "notion-create-comment",
            "notion-get-comments",
        ],
    ]

    func enabledCapabilities() -> [String] {
        var s = enabled.flatMap { toolCapabilities[$0] ?? [] }
        // Default
        s.append(contentsOf: [
            "notion-get-self",
            "notion-get-users",
            "notion-get-user",
            "notion-get-teams",
        ])
        return s
    }
}

// MARK: - Helpers
extension AtlassianOAuthManager {
    private func tokenIsValid(_ user: AtlassianUser) -> Bool {
        guard let exp = user.expiresAt else { return !user.accessToken.isEmpty }
        // Renew 60 seconds early
        return Date() < exp.addingTimeInterval(-60)
    }

    private func merge(profile: AtlassianUser, credential: OAuthSwiftCredential) -> AtlassianUser {
        var merged = profile
        merged.accessToken = credential.oauthToken
        if !credential.oauthRefreshToken.isEmpty {
            merged.refreshToken = credential.oauthRefreshToken
        }
        merged.expiresAt = credential.oauthTokenExpiresAt
        return merged
    }
}

// MARK: - Dynamic Client Registration
extension AtlassianOAuthManager {
    struct RegisteredClient: Codable {
        let client_id: String
        let client_secret: String?
        // Additional fields from RFC 7591 may exist; ignore for now
    }

    private func ensureClientRegistered() async throws -> RegisteredClient {
        // 1) Try Keychain first
        if let id = try? kc.read(kcClientIDKey), !id.isEmpty {
            let secret = try? kc.read(kcClientSecretKey)
            return RegisteredClient(client_id: id, client_secret: secret)
        }

        // 2) Register new client
        var req = URLRequest(url: registrationEndpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Choose confidential client using client_secret_post
        // If you prefer public client + PKCE, change token_endpoint_auth_method to "none"
        let body: [String: Any] = [
            "application_type": "native",
            "client_name": "AIThing (macOS)",
            "redirect_uris": [callbackURLString],
            "grant_types": ["authorization_code", "refresh_token"],
            "response_types": ["code"],
            "token_endpoint_auth_method": "client_secret_post",
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AtlassianOAuthError.registrationFailed
        }
        let registered = try JSONDecoder().decode(RegisteredClient.self, from: data)

        // 3) Cache to Keychain
        try kc.write(registered.client_id, key: kcClientIDKey)
        if let secret = registered.client_secret {
            try kc.write(secret, key: kcClientSecretKey)
        }

        return registered
    }
}

// MARK: - Interactive auth + Refresh
extension AtlassianOAuthManager {
    private func makeOAuth(creds: RegisteredClient) -> OAuth2Swift {
        let oauth = OAuth2Swift(
            consumerKey: creds.client_id,
            consumerSecret: creds.client_secret ?? "",
            authorizeUrl: authorizationEndpoint.absoluteString,
            accessTokenUrl: tokenEndpoint.absoluteString,
            responseType: "code"
        )

        // Use POSTing client_secret instead of Basic (matches client_secret_post)
        oauth.accessTokenBasicAuthentification = false

        // macOS handler (reuse your ASWebAuthURLHandler)
        oauth.authorizeURLHandler = MyASWebAuthURLHandler(callbackScheme: callbackScheme)
        return oauth
    }

    private func authorizeInteractively(oauth: OAuth2Swift) async throws -> OAuthSwiftCredential {
        guard let callbackURL = URL(string: callbackURLString) else {
            throw AtlassianOAuthError.notConfigured
        }

        // Atlassian doesn't use granular scopes the same way as GitHub;
        // send an empty scope (or customize if MCP adds scopes later)
        let scope = ""

        return try await withCheckedThrowingContinuation { continuation in
            let _ = oauth.authorize(
                withCallbackURL: callbackURL,
                scope: scope,
                state: UUID().uuidString,
                parameters: [:]
            ) { result in
                switch result {
                case .success(let (cred, _, _)):
                    continuation.resume(returning: cred)
                case .failure(let err):
                    if err.errorCode == OAuthSwiftError.cancelled.errorCode {
                        continuation.resume(throwing: AtlassianOAuthError.cancelled)
                    } else {
                        self.logger.error("Atlassian authorize failed: \(err.localizedDescription)")
                        continuation.resume(throwing: AtlassianOAuthError.authorizationFailed)
                    }
                }
            }
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
                    self.logger.error("Atlassian refresh failed: \(err.localizedDescription)")
                    continuation.resume(returning: nil)  // fall back to full auth
                }
            }
        }
    }
}

// MARK: - Profile fetch (Atlassian Public API)
extension AtlassianOAuthManager {
    private func fetchProfile(accessToken: String) async throws -> AtlassianUser {
        // Exit early. No profile fetching
        return AtlassianUser(
            accessToken: accessToken,
            refreshToken: nil,
            expiresAt: nil,
            id: nil,
            name: nil,
            email: nil,
            avatarURL: nil
        )
    }
}

// MARK: - Public model
public struct AtlassianUser: Codable, Equatable {
    // Tokens
    public var accessToken: String
    public var refreshToken: String?
    public var expiresAt: Date?

    // Profile
    public var id: String?
    public var name: String?
    public var email: String?
    public var avatarURL: URL?
}

// MARK: - Errors
enum AtlassianOAuthError: LocalizedError {
    case notConfigured
    case registrationFailed
    case authorizationFailed
    case cancelled
    case invalidHTTPResponse
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Atlassian OAuth not configured."
        case .registrationFailed: return "Client registration failed."
        case .authorizationFailed: return "Authorization failed."
        case .cancelled: return "User cancelled."
        case .invalidHTTPResponse: return "Invalid response from Atlassian."
        case .decodeFailed: return "Failed to decode Atlassian response."
        }
    }
}

// MARK: - Minimal Keychain helper
private struct Keychain {
    let service: String

    func write(_ value: String, key: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)  // replace if exists
        var add = query
        add[kSecValueData as String] = data
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw KCError(status: status) }
    }

    func read(_ key: String) throws -> String {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data,
            let str = String(data: data, encoding: .utf8)
        else {
            throw KCError(status: status)
        }
        return str
    }

    struct KCError: Error, LocalizedError {
        let status: OSStatus
        var errorDescription: String? { "Keychain error: \(status)" }
    }
}
