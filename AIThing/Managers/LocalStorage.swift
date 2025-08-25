//
//  LocalStorage.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/9/25.
//

import Foundation

func getAnthropicAPIKey() -> String? {
    UserDefaults.standard.string(forKey: "AnthropicAPIKey")
}

func getAgentEntries() -> [AgentEntry] {
    if let data = UserDefaults.standard.data(forKey: "AgentEntries"),
        let decoded = try? JSONDecoder().decode([AgentEntry].self, from: data)
    {
        return decoded
    }
    return []
}

func getPreferencesShowInScreenshot() -> Bool {
    UserDefaults.standard.bool(forKey: "PreferencesShowInScreenshot")
}

func getPreferencesCaptureFullScreen() -> Bool {
    return false
    // Always capture selectively
    // UserDefaults.standard.bool(forKey: "PreferencesCaptureFullScreen")
}

func getModel() -> String {
    return UserDefaults.standard.string(forKey: "ModelName") ?? "claude-sonnet-4-20250514"
}

func getSelectedTab() -> SettingsTab {
    if let name = UserDefaults.standard.string(forKey: "SelectedTab") {
        return SettingsTab(rawValue: name) ?? .account
    }
    return .account
}

func getByokSelected() -> Bool {
    UserDefaults.standard.bool(forKey: "ByokSelected")
}

func getGoogleAgentEnabled() -> Bool {
    UserDefaults.standard.bool(forKey: "GoogleAgentEnabled")
}

func getGithubAgentEnabled() -> Bool {
    UserDefaults.standard.bool(forKey: "GithubAgentEnabled")
}

func setGithubAgentEnabled(value: Bool) {
    UserDefaults.standard.set(value, forKey: "GithubAgentEnabled")
}

func setGoogleAgentEnabled(value: Bool) {
    UserDefaults.standard.set(value, forKey: "GoogleAgentEnabled")
}

func setByokSelected(value: Bool) {
    UserDefaults.standard.set(
        value,
        forKey: "ByokSelected"
    )
}

func setSelectedTab(value: SettingsTab) {
    UserDefaults.standard.set(value.rawValue, forKey: "SelectedTab")
}

func setModel(value: String) {
    UserDefaults.standard.set(value, forKey: "ModelName")
}

func setAnthropicAPIKey(value: String) {
    UserDefaults.standard.set(value, forKey: "AnthropicAPIKey")
}

func setAgentEntries(value: [AgentEntry]) {
    if let data = try? JSONEncoder().encode(value) {
        UserDefaults.standard.set(data, forKey: "AgentEntries")
    }
}

func setPreferencesShowInScreenshot(value: Bool) {
    UserDefaults.standard.set(
        value,
        forKey: "PreferencesShowInScreenshot"
    )
}

func setPreferencesCaptureFullScreen(value: Bool) {
    // No-op
    // UserDefaults.standard.set(
    //    value,
    //    forKey: "PreferencesCaptureFullScreen"
    // )
}
