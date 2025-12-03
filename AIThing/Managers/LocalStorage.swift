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

private enum StorageKey {
    // Model & API
    static let modelName = "ModelName"
    static let outputToken = "OutputToken"
    static let anthropicAPIKey = "AnthropicAPIKey"
    
    // Caching & Screenshots
    static let cacheMessages = "CacheMessages"
    static let useCapturedScreenshots = "UseCapturedScreenshots"
    static let preferencesShowInScreenshot = "PreferencesShowInScreenshot"
    static let preferencesCaptureFullScreen = "PreferencesCaptureFullScreen"
    
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

func getModel() -> String {
    UserDefaults.standard.string(forKey: StorageKey.modelName) ?? "claude-sonnet-4-5-20250929"
}

func setModel(value: String) {
    UserDefaults.standard.set(value, forKey: StorageKey.modelName)
}

func getOutputToken() -> Int {
    let token = UserDefaults.standard.integer(forKey: StorageKey.outputToken)
    return token > 0 ? token : 1024
}

func setOutputToken(value: Int) {
    UserDefaults.standard.set(value, forKey: StorageKey.outputToken)
}

func getAnthropicAPIKey() -> String? {
    UserDefaults.standard.string(forKey: StorageKey.anthropicAPIKey)
}

func setAnthropicAPIKey(value: String) {
    UserDefaults.standard.set(value, forKey: StorageKey.anthropicAPIKey)
}

// MARK: - Caching & Screenshots

func getCacheMessages() -> Bool {
    UserDefaults.standard.bool(forKey: StorageKey.cacheMessages)
}

func setCacheMessages(value: Bool) {
    UserDefaults.standard.set(value, forKey: StorageKey.cacheMessages)
}

func getUseCapturedScreenshots() -> Bool {
    UserDefaults.standard.bool(forKey: StorageKey.useCapturedScreenshots)
}

func setUseCapturedScreenshots(value: Bool) {
    UserDefaults.standard.set(value, forKey: StorageKey.useCapturedScreenshots)
}

func getPreferencesShowInScreenshot() -> Bool {
    UserDefaults.standard.bool(forKey: StorageKey.preferencesShowInScreenshot)
}

func setPreferencesShowInScreenshot(value: Bool) {
    UserDefaults.standard.set(value, forKey: StorageKey.preferencesShowInScreenshot)
}

func getPreferencesCaptureFullScreen() -> Bool {
    // Currently disabled
    return false
}

func setPreferencesCaptureFullScreen(value: Bool) {
    UserDefaults.standard.set(value, forKey: StorageKey.preferencesCaptureFullScreen)
}

// MARK: - UI State

func getSelectedTab() -> SettingsTab {
    if let name = UserDefaults.standard.string(forKey: StorageKey.selectedTab) {
        return SettingsTab(rawValue: name) ?? .account
    }
    return .account
}

func setSelectedTab(value: SettingsTab) {
    UserDefaults.standard.set(value.rawValue, forKey: StorageKey.selectedTab)
}

func getByokSelected() -> Bool {
    return true
}

func setByokSelected(value: Bool) {
    // No-op (always BYOK)
}

// MARK: - Agents & Saved Queries

func getAgentEntries() -> [AgentEntry] {
    guard let data = UserDefaults.standard.data(forKey: StorageKey.agentEntries),
          let decoded = try? JSONDecoder().decode([AgentEntry].self, from: data)
    else { return [] }
    return decoded
}

func setAgentEntries(value: [AgentEntry]) {
    if let data = try? JSONEncoder().encode(value) {
        UserDefaults.standard.set(data, forKey: StorageKey.agentEntries)
    }
}

func getSavedQueries() -> [SavedQuery] {
    guard let data = UserDefaults.standard.data(forKey: StorageKey.savedQueries),
          let decoded = try? JSONDecoder().decode([SavedQuery].self, from: data)
    else { return [] }
    return decoded
}

func setSavedQueries(value: [SavedQuery]) {
    if let data = try? JSONEncoder().encode(value) {
        UserDefaults.standard.set(data, forKey: StorageKey.savedQueries)
    }
}

// MARK: - GitHub Storage

func getGithubTools() -> Set<GithubTool> {
    guard let data = UserDefaults.standard.data(forKey: StorageKey.githubTools),
          let decoded = try? JSONDecoder().decode(Set<GithubTool>.self, from: data)
    else { return [] }
    return decoded
}

func setGithubTools(value: Set<GithubTool>) {
    if let data = try? JSONEncoder().encode(value) {
        UserDefaults.standard.set(data, forKey: StorageKey.githubTools)
    }
}

func getGithubUser() -> GithubUser? {
    guard let data = UserDefaults.standard.data(forKey: StorageKey.githubUser),
          let decoded = try? JSONDecoder().decode(GithubUser.self, from: data)
    else { return nil }
    return decoded
}

func setGithubUser(value: GithubUser?) {
    if let data = try? JSONEncoder().encode(value) {
        UserDefaults.standard.set(data, forKey: StorageKey.githubUser)
    }
}

// MARK: - Google Storage

func getGoogleTools() -> Set<GoogleTool> {
    guard let data = UserDefaults.standard.data(forKey: StorageKey.googleTools),
          let decoded = try? JSONDecoder().decode(Set<GoogleTool>.self, from: data)
    else { return [] }
    return decoded
}

func setGoogleTools(value: Set<GoogleTool>) {
    if let data = try? JSONEncoder().encode(value) {
        UserDefaults.standard.set(data, forKey: StorageKey.googleTools)
    }
}

// MARK: - MCP Storage

func getMcpEnabled(clientName: String?) -> Bool {
    guard let clientName = clientName else { return false }
    return UserDefaults.standard.bool(forKey: StorageKey.mcpEnabled(clientName: clientName))
}

func setMcpEnabled(value: Bool, clientName: String?) {
    guard let clientName = clientName else { return }
    UserDefaults.standard.set(value, forKey: StorageKey.mcpEnabled(clientName: clientName))
}

func getMcpToken(clientName: String?) -> McpToken? {
    guard let clientName = clientName else { return nil }
    guard let data = UserDefaults.standard.data(forKey: StorageKey.mcpToken(clientName: clientName)),
          let decoded = try? JSONDecoder().decode(McpToken.self, from: data)
    else { return nil }
    return decoded
}

func setMcpToken(value: McpToken?, clientName: String?) {
    guard let clientName = clientName else { return }
    if let data = try? JSONEncoder().encode(value) {
        UserDefaults.standard.set(data, forKey: StorageKey.mcpToken(clientName: clientName))
    }
}
