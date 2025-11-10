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
    return false  //UserDefaults.standard.bool(forKey: "PreferencesCaptureFullScreen")
}

func setPreferencesCaptureFullScreen(value: Bool) {
    UserDefaults.standard.set(
        value,
        forKey: "PreferencesCaptureFullScreen"
    )
}

func getModel() -> String {
    return UserDefaults.standard.string(forKey: "ModelName") ?? "claude-sonnet-4-5-20250929"
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

func getSavedQueries() -> [SavedQuery] {
    if let data = UserDefaults.standard.data(forKey: "SavedQueries"),
        let decoded = try? JSONDecoder().decode([SavedQuery].self, from: data)
    {
        return decoded
    }
    return []
}

func setSavedQueries(value: [SavedQuery]) {
    if let data = try? JSONEncoder().encode(value) {
        UserDefaults.standard.set(data, forKey: "SavedQueries")
    }
}
