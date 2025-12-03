//
//  OAuthModels.swift
//  AIThing
//
//  Models for OAuth functionality.
//

import Foundation

// MARK: - MCP OAuth Models

struct McpServer: Codable {
    let id: String?
    var image: String?
    let name: String
    let url: String
    let version: Int?
    let enabled: Bool?
    let custom: Bool?
}

public struct McpToken: Codable, Equatable {
    public var accessToken: String
    public var refreshToken: String?
    public var expiresAt: Date?
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

// MARK: - GitHub OAuth Models

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

enum GithubTool: String, CaseIterable, Identifiable, Codable {
    // default case context = "User and org context"
    case actions = "CI/CD Workflows"
    case codeSecurity = "Code Scanning Alerts"
    case dependabot = "Dependabot Alerts"
    case discussions = "Discussions"
    case gists = "Gists"
    case issues = "Issues"
    case notifications = "Notifications"
    case orgs = "Organizations"
    case pullRequests = "Pull Requests"
    case repos = "Repository"
    case secretProtection = "Secret Scanning"
    case securityAdvisories = "Security Advisories"
    case users = "User Search"

    var id: String { rawValue }
}

enum GithubOAuthError: LocalizedError {
    case notConfigured
    case authorizationFailed
    case cancelled
    case invalidHTTPResponse
    case decodeFailed
    case noClient
    case refreshFailed
    case getFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "GitHub OAuth not configured."
        case .authorizationFailed: return "Authorization failed."
        case .cancelled: return "User cancelled."
        case .invalidHTTPResponse: return "Invalid response from GitHub."
        case .decodeFailed: return "Failed to decode GitHub response."
        case .noClient: return "Failed to get GitHub client."
        case .refreshFailed: return "Failed to refresh the GitHub token."
        case .getFailed: return "Failed to fetch GitHub profile."
        }
    }
}

// MARK: - Google OAuth Models

enum GoogleTool: String, CaseIterable, Identifiable, Codable {
    case gmail = "Gmail"
    case drive = "Drive"
    case calendar = "Calendar"
    case docs = "Docs"
    case sheets = "Sheets"
    case forms = "Form"
    case slides = "Slides"
    case tasks = "Tasks"

    var id: String { rawValue }
}

// MARK: - MCP Token Storage Functions

func getMcpEnabled(clientName: String?) -> Bool {
    guard let clientName = clientName else { return false }
    return UserDefaults.standard.bool(forKey: "McpEnabled-\(clientName)")
}

func setMcpEnabled(value: Bool, clientName: String?) {
    guard let clientName = clientName else { return }
    UserDefaults.standard.set(value, forKey: "McpEnabled-\(clientName)")
}

func getMcpToken(clientName: String?) -> McpToken? {
    guard let clientName = clientName else { return nil }
    if let data = UserDefaults.standard.data(forKey: "McpToken-\(clientName)"),
        let decoded = try? JSONDecoder().decode(McpToken.self, from: data)
    {
        return decoded
    }
    return nil
}

func setMcpToken(value: McpToken?, clientName: String?) {
    guard let clientName = clientName else { return }
    if let data = try? JSONEncoder().encode(value) {
        UserDefaults.standard.set(data, forKey: "McpToken-\(clientName)")
    }
}

// MARK: - GitHub Storage Functions

func getGithubTools() -> Set<GithubTool> {
    if let data = UserDefaults.standard.data(forKey: "GithubTools"),
        let decoded = try? JSONDecoder().decode(Set<GithubTool>.self, from: data)
    {
        return decoded
    }
    return []
}

func setGithubTools(value: Set<GithubTool>) {
    if let data = try? JSONEncoder().encode(value) {
        UserDefaults.standard.set(data, forKey: "GithubTools")
    }
}

func getGithubUser() -> GithubUser? {
    if let data = UserDefaults.standard.data(forKey: "GithubUser"),
        let decoded = try? JSONDecoder().decode(GithubUser.self, from: data)
    {
        return decoded
    }
    return nil
}

func setGithubUser(value: GithubUser?) {
    if let data = try? JSONEncoder().encode(value) {
        UserDefaults.standard.set(data, forKey: "GithubUser")
    }
}

// MARK: - Google Storage Functions

func getGoogleTools() -> Set<GoogleTool> {
    if let data = UserDefaults.standard.data(forKey: "GoogleTools"),
        let decoded = try? JSONDecoder().decode(Set<GoogleTool>.self, from: data)
    {
        return decoded
    }
    return []
}

func setGoogleTools(value: Set<GoogleTool>) {
    if let data = try? JSONEncoder().encode(value) {
        UserDefaults.standard.set(data, forKey: "GoogleTools")
    }
}

