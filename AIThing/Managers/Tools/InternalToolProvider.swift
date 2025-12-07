//
//  InternalToolProvider.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 12/6/25.
//

import Foundation
import MCP
import SwiftUI
import os

// MARK: - Internal Tool Provider

/// Provides built-in tools for AIThing functionality.
/// Currently supports automation creation and management.
/// Note: This class is NOT @MainActor as it performs no UI updates.
/// Tool execution is done asynchronously and results are returned to callers.
final class InternalToolProvider: Sendable {

    // MARK: - Properties

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    // MARK: - Tool Discovery

    /// Returns all available internal tools as dictionary definitions
    func getTools() -> [Tool] {
        [createAutomationToolDefinition()]
    }

    // MARK: - Tool Execution

    /// Executes an internal tool by name
    /// - Parameters:
    ///   - name: Tool name to execute
    ///   - input: JSON string containing tool arguments
    ///   - automationManager: Manager for creating automations
    /// - Returns: Array of response content blocks
    func callTools(
        name: String,
        input: String,
        automationManager: AutomationManager
    ) async -> String {
        guard let value = try? parseJSONStringToValueObject(input),
            case .object(let dict) = value
        else {
            return "Error parsing input JSON"
        }

        let text = await executeCreateAutomation(dict: dict, automationManager: automationManager)
        return text
    }
}

// MARK: - Tool Definitions

extension InternalToolProvider {

    fileprivate func createAutomationToolDefinition() -> Tool {
        Tool(
            name: "aithing_create_automation",
            description: """
                Create recurring or one-off automations tasks inside AI Thing app. \
                Use this tool only if execution time is provided.
                """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "title": .object([
                        "type": .string("string"),
                        "description": .string(
                            """
                            Title of the automation. This is only used to distinguish between \
                            multiple automations. If it is not provided by the user, suggest a \
                            value based on the instructions.
                            """
                        ),
                    ]),
                    "instructions": .object([
                        "type": .string("string"),
                        "description": .string(
                            """
                            Instructions of the automation. These are the prompts that the \
                            automation runs when the time comes. These prompts are the ones \
                            sent to LLM that then does the automations. Make sure the prompt \
                            is small & clear for the AI.
                            """
                        ),
                    ]),
                    "executeTime": .object([
                        "type": .string("string"),
                        "description": .string(
                            """
                            Date time to execute the automation in yyyy-MM-dd HH:mm format. \
                            If just time is provided use current date.
                            """
                        ),
                    ]),
                    "recurrence": .object([
                        "type": .string("string"),
                        "description": .string(
                            """
                            Recurrence schedule of the automation in dd-hh-mm format, where \
                            dd is the days, hh is the hours, and mm is the minutes. For \
                            one-off automations, keep this 00-00-00
                            """
                        ),
                    ]),
                ]),
                "required": .array([.string("title"), .string("instructions"), .string("executeTime"), .string("recurrence")]),
            ])
        )
    }
}

// MARK: - Tool Execution

extension InternalToolProvider {

    /// Executes automation creation with validation.
    /// Validation is performed off the main thread, only the actual creation
    /// is dispatched to MainActor.
    fileprivate func executeCreateAutomation(
        dict: [String: Value],
        automationManager: AutomationManager
    ) async -> String {
        // Validate required fields (done off main thread)
        guard let title = dict["title"]?.stringValue else {
            return "Title not provided"
        }

        guard let instructions = dict["instructions"]?.stringValue else {
            return "Instructions not provided"
        }

        // Validate recurrence (done off main thread)
        let recurrenceResult = validateRecurrence(dict["recurrence"]?.stringValue)
        if !recurrenceResult.error.isEmpty {
            return recurrenceResult.error
        }

        // Validate execution time (done off main thread)
        let dateResult = validateDateTime(dict["executeTime"]?.stringValue)
        if !dateResult.error.isEmpty {
            return dateResult.error
        }

        guard let recurrence = recurrenceResult.value,
            let executeTime = dateResult.value
        else {
            return "Validation failed"
        }

        // Create the automation on the main thread (AutomationManager is @MainActor)
        await automationManager.createAutomation(
            id: UUID().uuidString,
            title: title,
            instructions: instructions,
            executeTime: executeTime,
            recurrence: recurrence,
            enabled: true
        )

        return "Task created successfully. Check the created task in the automations tab in settings."
    }
}

// MARK: - Validation

extension InternalToolProvider {

    fileprivate struct ValidationResult<T> {
        let value: T?
        let error: String

        static func success(_ value: T) -> ValidationResult {
            ValidationResult(value: value, error: "")
        }

        static func failure(_ error: String) -> ValidationResult {
            ValidationResult(value: nil, error: error)
        }
    }

    fileprivate func validateDateTime(_ executeTimeString: String?) -> ValidationResult<Date> {
        guard let executeTimeString = executeTimeString else {
            return .failure("Execution time not provided")
        }

        guard let validDate = dateFormatter.date(from: executeTimeString) else {
            return .failure("Invalid date time format")
        }

        return .success(validDate)
    }

    fileprivate func validateRecurrence(_ recurrenceString: String?) -> ValidationResult<Automation.Recurrence> {
        guard let recurrenceString = recurrenceString else {
            return .failure("Recurrence not provided")
        }

        let components = recurrenceString.split(separator: "-")

        guard components.count == 3 else {
            return .failure("Invalid recurrence format")
        }

        guard let minutes = Int(components[2]),
            (0...59).contains(minutes)
        else {
            return .failure("Minutes should be between 0 and 59")
        }

        guard let hours = Int(components[1]),
            (0...23).contains(hours)
        else {
            return .failure("Hours should be between 0 and 23")
        }

        guard let days = Int(components[0]),
            (0...30).contains(days)
        else {
            return .failure("Days should be between 0 and 30")
        }

        let recurrence = Automation.Recurrence(minutes: minutes, hours: hours, days: days)
        return .success(recurrence)
    }
}
