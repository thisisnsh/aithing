//
//  LocalStorage.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/9/25.
//

import Foundation

func getOutputToken() -> Int {
    let token = UserDefaults.standard.integer(forKey: "OutputToken")
    if token <= 0 {
        return 1024
    }
    return token
}

func setOutputToken(value: Int) {
    UserDefaults.standard.set(value, forKey: "OutputToken")
}

func getCacheMessages() -> Bool {
    UserDefaults.standard.bool(forKey: "CacheMessages")
}

func setCacheMessages(value: Bool) {
    UserDefaults.standard.set(value, forKey: "CacheMessages")
}

func getAnthropicAPIKey() -> String? {
    UserDefaults.standard.string(forKey: "AnthropicAPIKey")
}

func setAnthropicAPIKey(value: String) {
    UserDefaults.standard.set(value, forKey: "AnthropicAPIKey")
}

func getAgentEntries() -> [AgentEntry] {
    if let data = UserDefaults.standard.data(forKey: "AgentEntries"),
        let decoded = try? JSONDecoder().decode([AgentEntry].self, from: data)
    {
        return decoded
    }
    return []
}

func setAgentEntries(value: [AgentEntry]) {
    if let data = try? JSONEncoder().encode(value) {
        UserDefaults.standard.set(data, forKey: "AgentEntries")
    }
}

func getPreferencesShowInScreenshot() -> Bool {
    UserDefaults.standard.bool(forKey: "PreferencesShowInScreenshot")
}

func setPreferencesShowInScreenshot(value: Bool) {
    UserDefaults.standard.set(
        value,
        forKey: "PreferencesShowInScreenshot"
    )
}

func getPreferencesCaptureFullScreen() -> Bool {
    return false
}

func setPreferencesCaptureFullScreen(value: Bool) {
    // No-op
}

func getModel() -> String {
    return UserDefaults.standard.string(forKey: "ModelName") ?? "claude-sonnet-4-20250514"
}

func setModel(value: String) {
    UserDefaults.standard.set(value, forKey: "ModelName")
}

func getSelectedTab() -> SettingsTab {
    if let name = UserDefaults.standard.string(forKey: "SelectedTab") {
        return SettingsTab(rawValue: name) ?? .account
    }
    return .account
}

func setSelectedTab(value: SettingsTab) {
    UserDefaults.standard.set(value.rawValue, forKey: "SelectedTab")
}

func getByokSelected() -> Bool {
    return true
}

func setByokSelected(value: Bool) {
    // No-op
}

func getManagedAgents() -> [String] {
    if let data = UserDefaults.standard.string(forKey: "ManagedAgents") {
        return data.split(separator: " ").map(String.init)
    }
    return []
}

func setManagedAgents(value: [String]) {
    let agents = value.joined(separator: " ")
    UserDefaults.standard.set(agents, forKey: "ManagedAgents")
}
