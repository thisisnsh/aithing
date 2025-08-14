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
    UserDefaults.standard.bool(forKey: "PreferencesCaptureFullScreen")
}

func getModel() -> ModelName {
    if let name = UserDefaults.standard.string(forKey: "ModelName") {
        return ModelName(rawValue: name) ?? .claude_sonnet_4
    }
    return .claude_sonnet_4
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

func setByokSelected(value: Bool) {
    UserDefaults.standard.set(
        value,
        forKey: "ByokSelected"
    )
}

func setSelectedTab(value: SettingsTab) {
    UserDefaults.standard.set(value.rawValue, forKey: "SelectedTab")
}

func setModel(value: ModelName) {
    UserDefaults.standard.set(value.rawValue, forKey: "ModelName")
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
    UserDefaults.standard.set(
        value,
        forKey: "PreferencesCaptureFullScreen"
    )
}
