//
//  LocalStorage.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/9/25.
//
//  Centralized UserDefaults storage for app settings and data.
//

import Foundation

// MARK: - Storage Keys

/// Private enumeration of all UserDefaults keys used by the app.
private enum StorageKey {
    // Model & API
    static let modelName = "ModelName"
    static let outputToken = "OutputToken"
    static let apiKeys = "APIKeys"

    // Caching & Screenshots
    static let cacheMessages = "CacheMessages"
    static let useCapturedScreenshots = "UseCapturedScreenshots"
    static let preferencesShowInScreenshot = "PreferencesShowInScreenshot"
    static let preferencesOpenAtLogin = "PreferencesOpenAtLogin"

    // UI State
    static let selectedTab = "SelectedTab"

    // Agents & Queries
    static let agentEntries = "AgentEntries"
    static let savedQueries = "SavedQueries"

    // GitHub
    static let githubTools = "GithubTools"
    static let githubUser = "GithubUser"

    // Google
    static let googleTools = "GoogleTools"

    // MCP (Dynamic keys)
    static func mcpEnabled(clientName: String) -> String { "McpEnabled-\(clientName)" }
    static func mcpToken(clientName: String) -> String { "McpToken-\(clientName)" }
}

// MARK: - Model & API Settings

/// Gets the currently selected AI model identifier.
///
/// - Returns: The model name
func getModel() -> String? {
    UserDefaults.standard.string(forKey: StorageKey.modelName)
}

/// Sets the selected AI model identifier.
///
/// - Parameter value: The model name to store
func setModel(value: String) {
    UserDefaults.standard.set(value, forKey: StorageKey.modelName)
}

/// Gets the maximum output token count for model responses.
///
/// - Returns: The token limit, defaults to 1024 if not set or invalid
func getOutputToken() -> Int {
    let token = UserDefaults.standard.integer(forKey: StorageKey.outputToken)
    return token > 0 ? token : 1024
}

/// Sets the maximum output token count for model responses.
///
/// - Parameter value: The token limit to store
func setOutputToken(value: Int) {
    UserDefaults.standard.set(value, forKey: StorageKey.outputToken)
}

// MARK: - API Keys

/// Container for all provider API keys.
struct APIKeys: Codable, Equatable {
    var anthropic: String
    var openai: String
    var google: String

    init(anthropic: String = "", openai: String = "", google: String = "") {
        self.anthropic = anthropic
        self.openai = openai
        self.google = google
    }

    /// Gets the API key for a specific provider.
    func key(for provider: AIProvider) -> String {
        switch provider {
        case .anthropic: return anthropic
        case .openai: return openai
        case .google: return google
        }
    }

    /// Returns a new APIKeys with the key updated for the given provider.
    func with(key: String, for provider: AIProvider) -> APIKeys {
        var copy = self
        switch provider {
        case .anthropic: copy.anthropic = key
        case .openai: copy.openai = key
        case .google: copy.google = key
        }
        return copy
    }
}

/// Gets all stored API keys.
///
/// - Returns: The APIKeys object, with empty strings for unset keys
func getAPIKeys() -> APIKeys {
    guard let data = UserDefaults.standard.data(forKey: StorageKey.apiKeys),
        let decoded = try? JSONDecoder().decode(APIKeys.self, from: data)
    else { return APIKeys() }
    return decoded
}

/// Sets all API keys.
///
/// - Parameter value: The APIKeys object to store
func setAPIKeys(value: APIKeys) {
    if let data = try? JSONEncoder().encode(value) {
        UserDefaults.standard.set(data, forKey: StorageKey.apiKeys)
    }
}

/// Gets the API key for a specific provider.
///
/// - Parameter provider: The AI provider
/// - Returns: The API key if set and non-empty, nil otherwise
func getAPIKey(for provider: AIProvider) -> String? {
    let key = getAPIKeys().key(for: provider)
    return key.isEmpty ? nil : key
}

// MARK: - Caching & Screenshots

/// Gets whether message caching is enabled.
///
/// When enabled, adds cache control headers to API requests for better performance.
///
/// - Returns: `true` if caching is enabled
func getCacheMessages() -> Bool {
    UserDefaults.standard.bool(forKey: StorageKey.cacheMessages)
}

/// Sets whether message caching is enabled.
///
/// - Parameter value: Whether to enable caching
func setCacheMessages(value: Bool) {
    UserDefaults.standard.set(value, forKey: StorageKey.cacheMessages)
}

/// Gets whether captured screenshots should be used automatically.
///
/// When enabled, newly captured screenshots are automatically added to context.
///
/// - Returns: `true` if auto-capture is enabled
func getUseCapturedScreenshots() -> Bool {
    UserDefaults.standard.bool(forKey: StorageKey.useCapturedScreenshots)
}

/// Sets whether captured screenshots should be used automatically.
///
/// - Parameter value: Whether to enable auto-capture
func setUseCapturedScreenshots(value: Bool) {
    UserDefaults.standard.set(value, forKey: StorageKey.useCapturedScreenshots)
}

/// Gets whether the app panel should be visible in screenshots.
///
/// - Returns: `true` if panel should be visible in screenshots
func getPreferencesShowInScreenshot() -> Bool {
    UserDefaults.standard.bool(forKey: StorageKey.preferencesShowInScreenshot)
}

/// Sets whether the app panel should be visible in screenshots.
///
/// - Parameter value: Whether to show panel in screenshots
func setPreferencesShowInScreenshot(value: Bool) {
    UserDefaults.standard.set(value, forKey: StorageKey.preferencesShowInScreenshot)
}

/// Gets whether the app should open at login
///
/// - Returns: `true` if panel should open at login
func getPreferencesOpenAtLogin() -> Bool {
    UserDefaults.standard.bool(forKey: StorageKey.preferencesOpenAtLogin)
}

/// Sets whether the app should open at login
///
/// - Parameter value: Whether to open the app at login
func setPreferencesOpenAtLogin(value: Bool) {
    UserDefaults.standard.set(value, forKey: StorageKey.preferencesOpenAtLogin)
}

// MARK: - UI State

/// Gets the currently selected settings tab.
///
/// - Returns: The selected tab, defaults to `.account`
func getSelectedTab() -> SettingsTab {
    if let name = UserDefaults.standard.string(forKey: StorageKey.selectedTab) {
        return SettingsTab(rawValue: name) ?? .account
    }
    return .account
}

/// Sets the currently selected settings tab.
///
/// - Parameter value: The tab to select
func setSelectedTab(value: SettingsTab) {
    UserDefaults.standard.set(value.rawValue, forKey: StorageKey.selectedTab)
}

// MARK: - Agents & Saved Queries

/// Gets all configured agent entries.
///
/// - Returns: Array of agent entries, empty array if none stored
func getAgentEntries() -> [AgentEntry] {
    guard let data = UserDefaults.standard.data(forKey: StorageKey.agentEntries),
        let decoded = try? JSONDecoder().decode([AgentEntry].self, from: data)
    else { return [] }
    return decoded
}

/// Sets the configured agent entries.
///
/// - Parameter value: Array of agent entries to store
func setAgentEntries(value: [AgentEntry]) {
    if let data = try? JSONEncoder().encode(value) {
        UserDefaults.standard.set(data, forKey: StorageKey.agentEntries)
    }
}

/// Gets all saved query templates.
///
/// - Returns: Array of saved queries, empty array if none stored
func getSavedQueries() -> [SavedQuery] {
    guard let data = UserDefaults.standard.data(forKey: StorageKey.savedQueries),
        let decoded = try? JSONDecoder().decode([SavedQuery].self, from: data)
    else { return [] }
    return decoded
}

/// Sets the saved query templates.
///
/// - Parameter value: Array of saved queries to store
func setSavedQueries(value: [SavedQuery]) {
    if let data = try? JSONEncoder().encode(value) {
        UserDefaults.standard.set(data, forKey: StorageKey.savedQueries)
    }
}

// MARK: - GitHub Storage

/// Gets the enabled GitHub tools.
///
/// - Returns: Set of enabled GitHub tools, empty set if none stored
func getGithubTools() -> Set<GithubTool> {
    guard let data = UserDefaults.standard.data(forKey: StorageKey.githubTools),
        let decoded = try? JSONDecoder().decode(Set<GithubTool>.self, from: data)
    else { return [] }
    return decoded
}

/// Sets the enabled GitHub tools.
///
/// - Parameter value: Set of GitHub tools to enable
func setGithubTools(value: Set<GithubTool>) {
    if let data = try? JSONEncoder().encode(value) {
        UserDefaults.standard.set(data, forKey: StorageKey.githubTools)
    }
}

/// Gets the authenticated GitHub user.
///
/// - Returns: The GitHub user if authenticated, nil otherwise
func getGithubUser() -> GithubUser? {
    guard let data = UserDefaults.standard.data(forKey: StorageKey.githubUser),
        let decoded = try? JSONDecoder().decode(GithubUser.self, from: data)
    else { return nil }
    return decoded
}

/// Sets the authenticated GitHub user.
///
/// - Parameter value: The GitHub user to store, or nil to clear
func setGithubUser(value: GithubUser?) {
    if let data = try? JSONEncoder().encode(value) {
        UserDefaults.standard.set(data, forKey: StorageKey.githubUser)
    }
}

// MARK: - Google Storage

/// Gets the enabled Google tools.
///
/// - Returns: Set of enabled Google tools, empty set if none stored
func getGoogleTools() -> Set<GoogleTool> {
    guard let data = UserDefaults.standard.data(forKey: StorageKey.googleTools),
        let decoded = try? JSONDecoder().decode(Set<GoogleTool>.self, from: data)
    else { return [] }
    return decoded
}

/// Sets the enabled Google tools.
///
/// - Parameter value: Set of Google tools to enable
func setGoogleTools(value: Set<GoogleTool>) {
    if let data = try? JSONEncoder().encode(value) {
        UserDefaults.standard.set(data, forKey: StorageKey.googleTools)
    }
}

// MARK: - MCP Storage

/// Gets whether an MCP client is enabled.
///
/// - Parameter clientName: The client name to check
/// - Returns: `true` if the client is enabled, `false` if disabled or name is nil
func getMcpEnabled(clientName: String?) -> Bool {
    guard let clientName = clientName else { return false }
    return UserDefaults.standard.bool(forKey: StorageKey.mcpEnabled(clientName: clientName))
}

/// Sets whether an MCP client is enabled.
///
/// - Parameters:
///   - value: Whether to enable the client
///   - clientName: The client name to update
func setMcpEnabled(value: Bool, clientName: String?) {
    guard let clientName = clientName else { return }
    UserDefaults.standard.set(value, forKey: StorageKey.mcpEnabled(clientName: clientName))
}

/// Gets the authentication token for an MCP client.
///
/// - Parameter clientName: The client name to get token for
/// - Returns: The stored token if available, nil otherwise
func getMcpToken(clientName: String?) -> McpToken? {
    guard let clientName = clientName else { return nil }
    guard let data = UserDefaults.standard.data(forKey: StorageKey.mcpToken(clientName: clientName)),
        let decoded = try? JSONDecoder().decode(McpToken.self, from: data)
    else { return nil }
    return decoded
}

/// Sets the authentication token for an MCP client.
///
/// - Parameters:
///   - value: The token to store, or nil to clear
///   - clientName: The client name to update
func setMcpToken(value: McpToken?, clientName: String?) {
    guard let clientName = clientName else { return }
    if let data = try? JSONEncoder().encode(value) {
        UserDefaults.standard.set(data, forKey: StorageKey.mcpToken(clientName: clientName))
    }
}
