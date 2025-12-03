//
//  MCPAuthManager.swift
//  AIThing
//
//  Handles MCP server OAuth authentication.
//

import AppKit
import AuthenticationServices
import Foundation
import OAuthSwift
import os

// MARK: - MCP Auth Managers Container

/// Container for managing multiple MCP OAuth managers
@MainActor
final class MCPAuthManagers: ObservableObject {
    /// OAuth servers provided by AI Thing
    @Published var managers: [String: MCPAuthManager] = [:]
    
    /// OAuth servers added by user
    @Published var selfManagers: [String: MCPAuthManager] = [:]
    
    /// OAuth servers provided by AI Thing with custom handlers
    @Published var customManagers: [String: McpServer] = [:]
}

// MARK: - MCP Auth Manager

/// Manages OAuth authentication for individual MCP servers.
/// Handles dynamic client registration and token management.
@MainActor
final class MCPAuthManager: ObservableObject, Identifiable, OAuthManagerProtocol {
    typealias TokenType = McpToken
    
    // MARK: - Properties
    
    let id = UUID()
    @Published var user: McpToken?
    @Published var enabled: Bool = false
    
    var hasEnabledTools: Bool { enabled }
    var server: McpServer
    
    // MARK: - Private Properties
    
    private let logger = Logger(
        subsystem: "com.thisisnsh.mac.AIThing",
        category: "MCPAuthManager"
    )
    
    private var wellKnownUrls: WellKnownUrls?
    private var callbackURLString = ""
    private var oauth: OAuth2Swift?
    private var generating = false
    
    private let forwardCallbackScheme: String
    private let forwardCallbackURL: String
    
    // MARK: - Initialization
    
    init(server: McpServer) {
        self.server = server
        self.forwardCallbackScheme = "oauth-aithing"
        
        let sanitizedName = server.name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        self.forwardCallbackURL = "\(forwardCallbackScheme)://oauth-callback-\(sanitizedName)"
        
        enabled = getMcpEnabled(clientName: server.id)
        user = getMcpToken(clientName: server.id)
    }
    
    // MARK: - OAuthManagerProtocol
    
    /// Generates or refreshes an MCP OAuth token
    /// - Parameter refresh: When true, attempts to refresh existing token first
    /// - Returns: The token if successful
    func generateToken(refresh: Bool) async -> McpToken? {
        guard !generating else { return nil }
        generating = true
        defer { generating = false }
        
        do {
            try await fetchWellKnownUrls()
            
            AnalyticsManager.shared.customEvent(
                view: .McpOAuthManager,
                primary: .url,
                secondary: server.url,
                sev: .info
            )
            
            // Try to use existing valid token
            if refresh {
                if let user = self.user, tokenIsValid(user) {
                    return user
                }
                
                // Try to refresh existing token
                if let current = user,
                   let refreshToken = current.refreshToken,
                   !tokenIsValid(current) {
                    if let renewed = try await renewAccessToken(refreshToken: refreshToken) {
                        self.user = userFromCredential(renewed.credential)
                        persistToken()
                        return self.user
                    }
                }
            }
            
            // Full OAuth flow
            let loopback = OAuthLoopback(forwardCallbackURL: forwardCallbackURL)
            let redirectURL = try await loopback.start { _, _ in }
            
            callbackURLString = redirectURL.absoluteString
            let client = try await registerClient()
            let oauthClient = try makeOAuthClient(client: client)
            self.oauth = oauthClient
            
            let credential = try await authorizeInteractively()
            self.user = userFromCredential(credential)
            persistToken()
            return self.user
        } catch {
            logger.error("MCP generateToken error: \(error.localizedDescription)")
            self.user = nil
            persistToken()
            return nil
        }
    }
    
    /// Clears the current authentication
    func resetToken() {
        user = nil
        persistToken()
    }
    
    // MARK: - Static Helpers
    
    /// Checks if a server supports OAuth by looking for well-known URLs
    static func hasWellKnownUrls(url: String) async -> Bool {
        do {
            guard let mcpUrl = URL(string: url),
                  var comps = URLComponents(url: mcpUrl, resolvingAgainstBaseURL: false),
                  comps.scheme != nil,
                  comps.host != nil else {
                return false
            }
            
            comps.path = ""
            comps.query = nil
            comps.fragment = nil
            
            guard let baseUrl = comps.url else { return false }
            
            var request = URLRequest(
                url: baseUrl.appending(path: ".well-known/oauth-authorization-server")
            )
            request.httpMethod = "GET"
            
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                return false
            }
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Private Helpers

private extension MCPAuthManager {
    
    func persistToken() {
        setMcpToken(value: user, clientName: server.id)
    }
    
    func tokenIsValid(_ user: McpToken) -> Bool {
        guard let exp = user.expiresAt else {
            return !user.accessToken.isEmpty
        }
        return Date() < exp.addingTimeInterval(-60)
    }
    
    func userFromCredential(_ credential: OAuthSwiftCredential) -> McpToken {
        var user = McpToken(accessToken: credential.oauthToken)
        if !credential.oauthRefreshToken.isEmpty {
            user.refreshToken = credential.oauthRefreshToken
        }
        user.expiresAt = credential.oauthTokenExpiresAt
        return user
    }
    
    func fetchWellKnownUrls() async throws {
        guard let mcpUrl = URL(string: server.url) else {
            throw McpOAuthError.invalidMcpUrl
        }
        
        guard var comps = URLComponents(url: mcpUrl, resolvingAgainstBaseURL: false),
              comps.scheme != nil,
              comps.host != nil else {
            throw McpOAuthError.mcpUrlDecodeFailed
        }
        
        comps.path = ""
        comps.query = nil
        comps.fragment = nil
        
        guard let baseUrl = comps.url else {
            throw McpOAuthError.mcpBaseUrlDecodeFailed
        }
        
        var request = URLRequest(
            url: baseUrl.appending(path: ".well-known/oauth-authorization-server")
        )
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw McpOAuthError.getWellKnownUrlsFailed
        }
        
        self.wellKnownUrls = try JSONDecoder().decode(WellKnownUrls.self, from: data)
    }
    
    func registerClient() async throws -> RegisteredClient {
        guard let wellKnownUrls = wellKnownUrls else {
            throw McpOAuthError.missingWellKnownUrls
        }
        
        guard let registrationEndpoint = URL(string: wellKnownUrls.registration_endpoint) else {
            throw McpOAuthError.invalidRegistrationEndpoint
        }
        
        var request = URLRequest(url: registrationEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "application_type": "native",
            "client_name": "AIThing (macOS)",
            "client_uri": "https://aithing.dev",
            "redirect_uris": [callbackURLString],
            "grant_types": ["authorization_code", "refresh_token"],
            "response_types": ["code"],
            "token_endpoint_auth_method": "client_secret_post"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw McpOAuthError.registrationFailed
        }
        
        return try JSONDecoder().decode(RegisteredClient.self, from: data)
    }
    
    func makeOAuthClient(client: RegisteredClient) throws -> OAuth2Swift {
        guard let wellKnownUrls = wellKnownUrls else {
            throw McpOAuthError.missingWellKnownUrls
        }
        
        let oauth = OAuth2Swift(
            consumerKey: client.client_id,
            consumerSecret: client.client_secret ?? "",
            authorizeUrl: wellKnownUrls.authorization_endpoint,
            accessTokenUrl: wellKnownUrls.token_endpoint,
            responseType: "code"
        )
        oauth.accessTokenBasicAuthentification = false
        oauth.authorizeURLHandler = MyASWebAuthURLHandler(callbackScheme: forwardCallbackScheme)
        
        return oauth
    }
    
    func authorizeInteractively() async throws -> OAuthSwiftCredential {
        guard let wellKnownUrls = wellKnownUrls else {
            throw McpOAuthError.missingWellKnownUrls
        }
        
        guard let callbackURL = URL(string: callbackURLString) else {
            throw McpOAuthError.invalidCallbackUrl
        }
        
        let scopes = wellKnownUrls.scopes_supported?.joined(separator: " ") ?? ""
        
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
    
    func renewAccessToken(refreshToken: String) async throws -> OAuthSwift.TokenSuccess? {
        guard let oauth = oauth else { return nil }
        
        return try await withCheckedThrowingContinuation { continuation in
            let _ = oauth.renewAccessToken(withRefreshToken: refreshToken) { result in
                switch result {
                case .success(let success):
                    continuation.resume(returning: success)
                case .failure(let err):
                    self.logger.error("Refresh token failed: \(err.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

