//
//  AutomationModels.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 11/10/25.
//

import Foundation

struct Automation: Codable, Identifiable {
    let id: String
    var title: String
    var instructions: String
    var executeTime: Date
    var recurrence: Recurrence
    var enabled: Bool

    struct Recurrence: Codable {
        var minutes: Int
        var hours: Int
        var days: Int

        var isOneOff: Bool {
            minutes == 0 && hours == 0 && days == 0
        }

        var timeInterval: TimeInterval? {
            guard !isOneOff else { return nil }
            return TimeInterval(minutes * 60 + hours * 3600 + days * 86400)
        }
    }
}

// MARK: - Automation Configuration

/// Configuration for creating or updating an automation.
struct AutomationConfig {
    /// Unique identifier for the automation
    let id: String
    
    /// Display title for the automation
    let title: String
    
    /// Instructions/prompt to execute when triggered
    let instructions: String
    
    /// Date/time when the automation should first execute
    let executeTime: Date
    
    /// Recurrence schedule for the automation
    let recurrence: Automation.Recurrence
    
    /// Whether the automation is enabled
    let enabled: Bool
}

