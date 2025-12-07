//
//  GithubAuthManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 12/5/25.
//

import AppKit
import AuthenticationServices
import Foundation
import OAuthSwift
import SwiftUI
import os

// MARK: - GitHub Auth Manager

/// Manages GitHub OAuth authentication flow.
/// Handles token generation, refresh, and user profile fetching.
@MainActor
class GithubAuthManager: ObservableObject, OAuthManagerProtocol {
    typealias TokenType = GithubUser

    // MARK: - Published Properties

    @Published var user: GithubUser? = getGithubUser()
    @Published var enabled: Set<GithubTool> = getGithubTools()

    var hasEnabledTools: Bool { !enabled.isEmpty }

    // MARK: - Private Properties

    private let callbackScheme = "oauth-aithing"
    private let callbackURLString = "oauth-aithing://oauth-callback-github"
    private var generating = false
    private(set) var oauth: OAuth2Swift?

    // MARK: - Initialization

    init() {
        Task { [weak self] in
            await self?.configureOAuth()
        }
    }

    // MARK: - OAuth Configuration

    /// Configures the OAuth client with credentials from Firestore
    func configureOAuth() async {
        let agent = await FirestoreManager().getManagedGitHubAgent()
        let oauth = OAuth2Swift(
            consumerKey: agent?.clientId ?? "",
            consumerSecret: agent?.clientSecret ?? "",
            authorizeUrl: "https://github.com/login/oauth/authorize",
            accessTokenUrl: "https://github.com/login/oauth/access_token",
            responseType: "code"
        )
        oauth.accessTokenBasicAuthentification = true
        oauth.authorizeURLHandler = MyASWebAuthURLHandler(callbackScheme: callbackScheme)
        self.oauth = oauth
    }

    // MARK: - OAuthManagerProtocol

    /// Generates or refreshes a GitHub OAuth token
    /// - Parameter refresh: When true, attempts to refresh existing token first
    /// - Returns: The authenticated user if successful
    func generateToken(refresh: Bool) async -> GithubUser? {
        guard !generating else { return nil }
        generating = true
        defer { generating = false }

        do {
            if refresh {
                if let user = self.user, tokenIsValid(user) {
                    return user
                }

                if let current = user,
                    let refreshToken = current.refreshToken,
                    !tokenIsValid(current)
                {
                    if let renewed = try await renewAccessToken(refreshToken: refreshToken) {
                        let profile = try await fetchProfile(accessToken: renewed.credential.oauthToken)
                        let merged = merge(profile: profile, credential: renewed.credential)
                        self.user = merged
                        setGithubUser(value: self.user)
                        return merged
                    }
                }
            }

            let credential = try await authorizeInteractively()
            let profile = try await fetchProfile(accessToken: credential.oauthToken)
            let merged = merge(profile: profile, credential: credential)
            self.user = merged
            setGithubUser(value: self.user)
            return self.user
        } catch {
            logger.error("GitHub generateToken error: \(error.localizedDescription)")
            self.user = nil
            setGithubUser(value: nil)
            return nil
        }
    }

    /// Clears the current authentication
    func resetToken() {
        user = nil
        setGithubUser(value: nil)
    }

    // MARK: - Scope Management

    /// Returns OAuth scopes based on enabled tools
    func additionalScopes() -> [String] {
        guard !enabled.isEmpty else { return [] }

        var scopes = Set(enabled.flatMap { GithubToolModels.toolScopesMap[$0] ?? [] })

        // Add default scopes
        scopes.insert(GithubToolModels.Scopes.readUser)
        scopes.insert(GithubToolModels.Scopes.readOrg)
        scopes.insert(GithubToolModels.Scopes.userEmail)

        return Array(scopes)
    }

    /// Returns API capabilities based on enabled tools
    func enabledCapabilities() -> [String] {
        guard !enabled.isEmpty else { return [] }

        var capabilities = enabled.flatMap { GithubToolModels.toolCapabilities[$0] ?? [] }
        capabilities.append(contentsOf: ["get_me", "get_team_members", "get_teams"])
        return capabilities
    }
}

// MARK: - Private Helpers

extension GithubAuthManager {

    fileprivate func tokenIsValid(_ user: GithubUser) -> Bool {
        guard let exp = user.expiresAt else {
            return !user.accessToken.isEmpty
        }
        return Date() < exp.addingTimeInterval(-60)
    }

    fileprivate func merge(profile: GithubUser, credential: OAuthSwiftCredential) -> GithubUser {
        var merged = profile
        merged.accessToken = credential.oauthToken
        if !credential.oauthRefreshToken.isEmpty {
            merged.refreshToken = credential.oauthRefreshToken
        }
        merged.expiresAt = credential.oauthTokenExpiresAt
        return merged
    }

    fileprivate func authorizeInteractively() async throws -> OAuthSwiftCredential {
        guard let oauth = self.oauth else {
            throw GithubOAuthError.noClient
        }

        guard let callbackURL = URL(string: callbackURLString) else {
            throw GithubOAuthError.notConfigured
        }

        let scope = additionalScopes().joined(separator: " ")

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
                        continuation.resume(throwing: GithubOAuthError.cancelled)
                    } else {
                        continuation.resume(throwing: GithubOAuthError.authorizationFailed)
                    }
                }
            }
        }
    }

    fileprivate func renewAccessToken(refreshToken: String) async throws -> OAuthSwift.TokenSuccess? {
        try await withCheckedThrowingContinuation { continuation in
            guard let oauth = oauth else {
                continuation.resume(throwing: GithubOAuthError.noClient)
                return
            }

            let _ = oauth.renewAccessToken(withRefreshToken: refreshToken) { result in
                switch result {
                case .success(let success):
                    continuation.resume(returning: success)
                case .failure(let err):
                    logger.error("GitHub refresh failed: \(err.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    fileprivate func fetchProfile(accessToken: String) async throws -> GithubUser {
        let profile: GithubProfile = try await githubGET(path: "user", accessToken: accessToken)

        var email = profile.email
        if email == nil {
            if let emails: [GithubEmail] = try? await githubGET(
                path: "user/emails",
                accessToken: accessToken
            ) {
                email =
                    emails.first(where: { $0.primary && $0.verified })?.email
                    ?? emails.first?.email
            }
        }

        return GithubUser(
            accessToken: accessToken,
            refreshToken: nil,
            expiresAt: nil,
            id: profile.id,
            login: profile.login,
            name: profile.name,
            email: email,
            avatarURL: profile.avatar_url.flatMap(URL.init(string:))
        )
    }

    fileprivate func githubGET<T: Decodable>(path: String, accessToken: String) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            guard let oauth = oauth else {
                continuation.resume(throwing: GithubOAuthError.getFailed)
                return
            }

            let client = oauth.client
            let url = "https://api.github.com/\(path)"
            let headers = ["Accept": "application/vnd.github+json"]

            let _ = client.get(url, headers: headers) { result in
                switch result {
                case .success(let response):
                    do {
                        guard (200..<300).contains(response.response.statusCode) else {
                            throw GithubOAuthError.invalidHTTPResponse
                        }
                        let obj = try JSONDecoder().decode(T.self, from: response.data)
                        continuation.resume(returning: obj)
                    } catch {
                        continuation.resume(throwing: GithubOAuthError.decodeFailed)
                    }
                case .failure:
                    continuation.resume(throwing: GithubOAuthError.invalidHTTPResponse)
                }
            }
        }
    }
}

// MARK: - Private DTOs

extension GithubAuthManager {

    fileprivate struct GithubProfile: Decodable {
        let id: Int?
        let login: String?
        let name: String?
        let email: String?
        let avatar_url: String?
    }

    fileprivate struct GithubEmail: Decodable {
        let email: String
        let primary: Bool
        let verified: Bool
        let visibility: String?
    }
}
