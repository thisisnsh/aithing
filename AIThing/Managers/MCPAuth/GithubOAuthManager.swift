//
//  GithubOAuthManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/25/25.
//

import AppKit
import AuthenticationServices
import Foundation
import OAuthSwift
import SwiftUI
import os

@MainActor
class GithubOAuthManager: ObservableObject {
    @Published var user: GithubUser?
    @Published var enabled: Set<GithubTool> = []

    let logger = Logger(subsystem: "com.thisisnsh.mac.AIThing", category: "GithubOAuthManager")

    private let clientID = ""
    private let clientSecret = ""
    private let callbackScheme = "oauth-aithing"
    private let callbackURLString = "oauth-aithing://oauth-callback-github"

    // OAuth engine
    private lazy var oauth: OAuth2Swift = {
        let oauth = OAuth2Swift(
            consumerKey: clientID,
            consumerSecret: clientSecret,
            authorizeUrl: "https://github.com/login/oauth/authorize",
            accessTokenUrl: "https://github.com/login/oauth/access_token",
            responseType: "code"
        )
        // GitHub expects Accept: application/json; OAuthSwift handles this when accessTokenUrl returns JSON
        oauth.accessTokenBasicAuthentification = true
        // macOS handler
        oauth.authorizeURLHandler = MyASWebAuthURLHandler(callbackScheme: callbackScheme)
        return oauth
    }()

    // MARK: Public API

    /// Generates (or refreshes) a Bearer token and returns a hydrated `GithubUser?`.
    /// - Parameter refresh: when true, tries to refresh first if a refresh token is available.
    func generateToken(refresh: Bool) async -> GithubUser? {
        do {
            // Refresh token if user already exists
            if refresh {
                if let user = self.user {
                    // Return user if token is still valid
                    if tokenIsValid(user) {
                        return user
                    }
                }
                // Refresh token if token is invalid
                if let current = user, let rt = current.refreshToken,
                    refresh || !tokenIsValid(current)
                {
                    if let renewed = try await renewAccessToken(refreshToken: rt) {
                        let profile = try await fetchProfile(
                            accessToken: renewed.credential.oauthToken
                        )
                        let merged = merge(profile: profile, credential: renewed.credential)
                        self.user = merged
                        return merged
                    }
                    // fallthrough to full auth if refresh failed
                }
            }

            // Full OAuth authorization
            let cred = try await authorizeInteractively()
            let profile = try await fetchProfile(accessToken: cred.oauthToken)
            let merged = merge(profile: profile, credential: cred)
            self.user = merged
            return self.user
        } catch {
            logger.error("GitHub generateToken (macOS) error: \(error.localizedDescription)")
            self.user = nil
            return nil
        }
    }

    func resetToken() {
        user = nil
    }

    struct GithubOAuthScopes {
        // default
        static let readUser = "read:user"
        static let userEmail = "user:email"
        static let readOrg = "read:org"
        // per tool
        static let workflow = "workflow"
        static let repo = "repo"
        static let publicRepo = "public_repo"
        static let securityEvents = "security_events"
        static let gist = "gist"
        static let notifications = "notifications"
    }

    enum GithubTool: String, CaseIterable, Identifiable {
        // default case context = "User and org context"
        case actions = "CI/CD workflows"
        case codeSecurity = "Code scanning alerts"
        case dependabot = "Dependabot alerts"
        case discussions = "Repo discussions"
        // case experiments = "Experimental features"
        case gists = "Gist operations"
        case issues = "Issue tracking"
        case notifications = "User notifications"
        case orgs = "Organization search"
        case pullRequests = "Pull requests"
        case repos = "Repository operations"
        case secretProtection = "Secret scanning"
        case securityAdvisories = "Security advisories"
        case users = "User search"

        var id: String { rawValue }
    }

    let toolScopesMap: [GithubTool: [String]] = [
        .actions: [
            GithubOAuthScopes.workflow,
            GithubOAuthScopes.repo,
        ],
        .codeSecurity: [
            GithubOAuthScopes.securityEvents
        ],
        .dependabot: [
            GithubOAuthScopes.securityEvents
        ],
        .discussions: [
            GithubOAuthScopes.repo,
            GithubOAuthScopes.publicRepo,
        ],
        .gists: [
            GithubOAuthScopes.gist
        ],
        .issues: [
            GithubOAuthScopes.repo,
            GithubOAuthScopes.publicRepo,
        ],
        .notifications: [
            GithubOAuthScopes.notifications
        ],
        .orgs: [
            GithubOAuthScopes.readOrg
        ],
        .pullRequests: [
            GithubOAuthScopes.repo,
            GithubOAuthScopes.publicRepo,
        ],
        .repos: [
            GithubOAuthScopes.repo,
            GithubOAuthScopes.publicRepo,
        ],
        .secretProtection: [
            GithubOAuthScopes.securityEvents
        ],
        .securityAdvisories: [
            GithubOAuthScopes.repo,
            GithubOAuthScopes.readOrg,
        ],
        .users: [
            GithubOAuthScopes.readUser
        ],
    ]

    let toolCapabilities: [GithubTool: [String]] = [
        .actions: [
            "cancel_workflow_run",
            "delete_workflow_run_logs",
            "download_workflow_run_artifact",
            "get_job_logs",
            "get_workflow_run",
            "get_workflow_run_logs",
            "get_workflow_run_usage",
            "list_workflow_jobs",
            "list_workflow_run_artifacts",
            "list_workflow_runs",
            "list_workflows",
            "rerun_failed_jobs",
            "rerun_workflow_run",
            "run_workflow",
        ],
        .codeSecurity: [
            "get_code_scanning_alert",
            "list_code_scanning_alerts",
        ],
        .dependabot: [
            "get_dependabot_alert",
            "list_dependabot_alerts",
        ],
        .discussions: [
            "get_discussion",
            "get_discussion_comments",
            "list_discussion_categories",
            "list_discussions",
        ],
        .gists: [
            "create_gist",
            "list_gists",
            "update_gist",
        ],
        .issues: [
            "add_issue_comment",
            "add_sub_issue",
            "assign_copilot_to_issue",
            "create_issue",
            "get_issue",
            "get_issue_comments",
            "list_issue_types",
            "list_issues",
            "list_sub_issues",
            "remove_sub_issue",
            "reprioritize_sub_issue",
            "search_issues",
            "update_issue",
        ],
        .notifications: [
            "dismiss_notification",
            "get_notification_details",
            "list_notifications",
            "manage_notification_subscription",
            "manage_repository_notification_subscription",
            "mark_all_notifications_read",
        ],
        .orgs: [
            "search_orgs"
        ],
        .pullRequests: [
            "add_comment_to_pending_review",
            "create_and_submit_pull_request_review",
            "create_pending_pull_request_review",
            "create_pull_request",
            "delete_pending_pull_request_review",
            "get_pull_request",
            "get_pull_request_comments",
            "get_pull_request_diff",
            "get_pull_request_files",
            "get_pull_request_reviews",
            "get_pull_request_status",
            "list_pull_requests",
            "merge_pull_request",
            "request_copilot_review",
            "search_pull_requests",
            "submit_pending_pull_request_review",
            "update_pull_request",
            "update_pull_request_branch",
        ],
        .repos: [
            "create_branch",
            "create_or_update_file",
            "create_repository",
            "delete_file",
            "fork_repository",
            "get_commit",
            "get_file_contents",
            "get_latest_release",
            "get_release_by_tag",
            "get_tag",
            "list_branches",
            "list_commits",
            "list_releases",
            "list_tags",
            "push_files",
            "search_code",
            "search_repositories",
        ],
        .secretProtection: [
            "get_secret_scanning_alert",
            "list_secret_scanning_alerts",
        ],
        .securityAdvisories: [
            "get_global_security_advisory",
            "list_global_security_advisories",
            "list_org_repository_security_advisories",
            "list_repository_security_advisories",
        ],
        .users: [
            "search_users"
        ],
    ]

    func additionalScopes() -> [String] {
        var s = Set(enabled.flatMap { toolScopesMap[$0] ?? [] })

        // Default
        s.insert(GithubOAuthScopes.readUser)
        s.insert(GithubOAuthScopes.readOrg)
        s.insert(GithubOAuthScopes.userEmail)

        return Array(s)
    }

    func enabledCapabilities() -> [String] {
        var s = enabled.flatMap { toolCapabilities[$0] ?? [] }
        // Default
        s.append(contentsOf: [
            "get_me",
            "get_team_members",
            "get_teams",
        ])
        return s
    }

}

extension GithubOAuthManager {
    // MARK: - Helpers

    private func tokenIsValid(_ user: GithubUser) -> Bool {
        guard let exp = user.expiresAt else { return !user.accessToken.isEmpty }
        return Date() < exp.addingTimeInterval(-60)
    }

    private func merge(profile: GithubUser, credential: OAuthSwiftCredential) -> GithubUser {
        var merged = profile
        merged.accessToken = credential.oauthToken
        if !credential.oauthRefreshToken.isEmpty {
            merged.refreshToken = credential.oauthRefreshToken
        }
        merged.expiresAt = credential.oauthTokenExpiresAt
        return merged
    }

    // MARK: - Interactive auth

    private func authorizeInteractively() async throws -> OAuthSwiftCredential {
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

    // MARK: - Refresh (if GitHub issues refresh tokens to your app)

    private func renewAccessToken(refreshToken: String) async throws -> OAuthSwift.TokenSuccess? {
        try await withCheckedThrowingContinuation { continuation in
            let _ = oauth.renewAccessToken(withRefreshToken: refreshToken) { result in
                switch result {
                case .success(let success):
                    continuation.resume(returning: success)
                case .failure(let err):
                    self.logger.error("GitHub refresh failed: \(err.localizedDescription)")
                    continuation.resume(returning: nil)  // fall back to full auth
                }
            }
        }
    }

    // MARK: - Profile fetch

    private func fetchProfile(accessToken: String) async throws -> GithubUser {
        // /user
        let profile: GithubProfile = try await githubGET(path: "user", accessToken: accessToken)
        // /user/emails (because email can be nil if not public)
        var email = profile.email
        if email == nil {
            if let emails: [GithubEmail] = try? await githubGET(
                path: "user/emails",
                accessToken: accessToken
            ) {
                email =
                    emails.first(where: { $0.primary && $0.verified })?.email ?? emails.first?.email
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

    private func githubGET<T: Decodable>(path: String, accessToken: String) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
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

    // MARK: - DTOs

    private struct GithubProfile: Decodable {
        let id: Int?
        let login: String?
        let name: String?
        let email: String?
        let avatar_url: String?
    }

    private struct GithubEmail: Decodable {
        let email: String
        let primary: Bool
        let verified: Bool
        let visibility: String?
    }
}

// MARK: - Public model

public struct GithubUser: Codable, Equatable {
    // Tokens
    public var accessToken: String
    public var refreshToken: String?
    public var expiresAt: Date?

    // Profile
    public var id: Int?
    public var login: String?
    public var name: String?
    public var email: String?
    public var avatarURL: URL?
}

// MARK: - Errors

enum GithubOAuthError: LocalizedError {
    case notConfigured
    case authorizationFailed
    case cancelled
    case invalidHTTPResponse
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "GitHub OAuth not configured."
        case .authorizationFailed: return "Authorization failed."
        case .cancelled: return "User cancelled."
        case .invalidHTTPResponse: return "Invalid response from GitHub."
        case .decodeFailed: return "Failed to decode GitHub response."
        }
    }
}

// MARK: - macOS URL handler using ASWebAuthenticationSession

/// Minimal ASWebAuthenticationSession-based handler for macOS.
final class MyASWebAuthURLHandler: NSObject, OAuthSwiftURLHandlerType,
    ASWebAuthenticationPresentationContextProviding
{
    private let callbackScheme: String
    private var authSession: ASWebAuthenticationSession?

    let logger = Logger(subsystem: "com.thisisnsh.mac.AIThing", category: "MyASWebAuthURLHandler")

    init(callbackScheme: String) {
        self.callbackScheme = callbackScheme
    }

    func handle(_ url: URL) {
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) {
            callbackURL,
            error in
            if let url = callbackURL {
                OAuthSwift.handle(url: url)
            } else {
                OAuthSwift.handle(url: URL(filePath: "Error")!)
            }
        }
        session.presentationContextProvider = self
        // set to true if you want no shared browser state
        // session.prefersEphemeralWebBrowserSession = true
        self.authSession = session
        _ = session.start()
    }

    // MARK: ASWebAuthenticationPresentationContextProviding (macOS)

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // best available window
        return NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? .init()
    }
}
