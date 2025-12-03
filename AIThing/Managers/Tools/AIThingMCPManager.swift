//
//  AIThingMCPManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 11/22/25.
//

import Foundation
import MCP
import SwiftUI
import os

@MainActor
class AIThingMCPManager {
    let logger = Logger(subsystem: "com.thisisnsh.mac.AIThing", category: "AIThingMCPManager")

    func getTools() -> [[String: Any]] {
        var tools: [[String: Any]] = []
        tools.append(
            [
                "name": "aithing_create_automation",
                "description":
                    "Create recurring or one-off automations tasks inside AI Thing app. Use this tool only if execution time is provided.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "title": [
                            "type": "string",
                            "description":
                                "Title of the automation. This is only used to distinguish between multiple automations. If it is not provided by the user, suggest a value based on the instructions.",
                        ],
                        "instructions": [
                            "type": "string",
                            "description":
                                "Instructions of the automation. These are the prompts that the automation runs when the time comes. These prompts are the ones sent to LLM that then does the automations. Make sure the prompt is small & clear for the AI.",
                        ],
                        "executeTime": [
                            "type": "string",
                            "description":
                                "Date time to execute the automation in yyyy-MM-dd HH:mm format. If just time is provided use current date.",
                        ],
                        "recurrence": [
                            "type": "string",
                            "description":
                                "Recurrence schedule of the automation in dd-hh-mm format, where dd is the days, hh is the hours, and mm is the minutes. For one-off automations, keep this 00-00-00",
                        ],

                    ],
                    "required": ["title", "instructions", "executeTime", "recurrence"],
                ],
            ]
        )

        return tools
    }

    func callTools(name: String, input: String, automationManager: AutomationManager) -> [[String:
        Any]]
    {
        guard let value = try? parseJSONStringToValueObject(input) else { return [] }
        guard case .object(let dict) = value else { return [] }

        let text = processCreateAutomation(dict: dict, automationManager: automationManager)

        var response: [[String: Any]] = []
        response.append(["type": "text", "text": text])
        return response
    }

    private func processCreateAutomation(
        dict: [String: Value],
        automationManager: AutomationManager
    ) -> String {
        guard let title = dict["title"]?.stringValue else { return "Title not provided" }
        guard let instructions = dict["instructions"]?.stringValue else {
            return "Instructions not provided"
        }

        let (recurrence, errorA) = validateRecurrnece(dict["recurrence"]?.stringValue)
        if !errorA.isEmpty { return errorA }

        let (date, errorB) = validateDateTime(dict["executeTime"]?.stringValue)
        if !errorB.isEmpty { return errorB }

        automationManager.createAutomation(
            id: UUID().uuidString,
            title: title,
            instructions: instructions,
            executeTime: date!,
            recurrence: recurrence!,
            enabled: true
        )

        return
            "Task created successfully. Check the created task in the automations tab in settings."
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    private func validateDateTime(_ executeTimeString: String?) -> (Date?, String) {
        guard let executeTimeString = executeTimeString else {
            return (nil, "Execution time not provided")
        }
        if let validDate = dateFormatter.date(from: executeTimeString) {
            return (validDate, "")
        }
        return (nil, "Invalid date time format")
    }

    private func validateRecurrnece(_ executeRecurrence: String?) -> (
        Automation.Recurrence?, String
    ) {
        guard let executeRecurrence = executeRecurrence else {
            return (nil, "Recurrence not provided")
        }
        let components = executeRecurrence.split(separator: "-")

        // Expect exactly 3 components
        guard components.count == 3
        else {
            return (nil, "Invalid recurrence format")
        }

        guard let minutes = Int(components[2])
        else {
            return (nil, "Invalid minutes provided")
        }

        if minutes < 0 || minutes > 59 {
            return (nil, "Minutes should be contained between 0 and 59")
        }

        guard let hours = Int(components[1])
        else {
            return (nil, "Invalid hours provided")
        }
        if hours < 0 || hours > 23 {
            return (nil, "Hours should be contained between 0 and 23")
        }

        guard let days = Int(components[0])
        else {
            return (nil, "Invalid days provided")
        }
        if days < 0 || days > 30 {
            return (nil, "Days should be contained between 0 and 30")
        }

        let recurrence = Automation.Recurrence(minutes: minutes, hours: hours, days: days)
        return (recurrence, "")
    }
}
