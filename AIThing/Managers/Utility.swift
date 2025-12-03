//
//  Utility.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import AppKit
import Foundation
import MCP
import os

/// Global logger instance for the application.
let logger = Logger(subsystem: "com.thisisnsh.mac.AIThing", category: "Utility")

// MARK: - Tool Conversion

/// Converts MCP Tool objects to dictionary representations for JSON serialization.
///
/// - Parameter tools: Array of MCP Tool objects
/// - Returns: Array of dictionaries containing tool name, description, and input schema
func toolsToDictionaries(_ tools: [Tool]) -> [[String: Any]] {
    tools.map { tool in
        var dict: [String: Any] = [
            "name": tool.name,
            "description": tool.description,
        ]

        if let inputSchema = tool.inputSchema {
            dict["input_schema"] = inputSchema.stringified()
        }

        return dict
    }
}

// MARK: - JSON Parsing

/// Parses a JSON string into an MCP Value object.
///
/// Handles empty strings gracefully by returning an empty object.
///
/// - Parameter json: The JSON string to parse
/// - Returns: The parsed Value object
/// - Throws: Error if JSON parsing fails
func parseJSONStringToValueObject(_ json: String) throws -> Value {
    if json.isEmpty {
        return [:]
    }
    
    let data = Data(json.utf8)
    let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
    return Value(fromDecoded: jsonObject)
}

/// Parses a JSON string into a dictionary.
///
/// Handles empty strings and invalid JSON gracefully by returning an empty dictionary.
/// Logs errors for debugging purposes.
///
/// - Parameter json: The JSON string to parse
/// - Returns: Dictionary representation of the JSON, or empty dictionary on failure
func parseJSONStringToDictObject(_ json: String) -> [String: Any] {
    do {
        if json.isEmpty {
            return [:]
        }
        
        let data = Data(json.utf8)
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])

        let value = Value(fromDecoded: jsonObject)

        guard case let .object(dict) = value else {
            logger.error("JSON root is not an object.")
            return [:]
        }

        let jsonSafeDict = dict.mapValues { $0.toJSONSafeObject() }

        return jsonSafeDict.compactMapValues { $0 }  // removes nils safely
    } catch {
        logger.error("Failed to parse JSON: \(error)")
        return [:]
    }
}
