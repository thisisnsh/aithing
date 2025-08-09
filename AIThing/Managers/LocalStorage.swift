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
