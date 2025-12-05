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
let logger = Logger(subsystem: "com.thisisnsh.mac.AIThing", category: "AIThing")

// MARK: - Image Parsing

func nsImageToBase64(_ image: NSImage) -> String? {
    guard let tiffData = image.tiffRepresentation,
        let bitmapImage = NSBitmapImageRep(data: tiffData),
        let pngData = bitmapImage.representation(using: .png, properties: [:])
    else {
        return nil
    }
    return pngData.base64EncodedString()
}

func base64ToNSImage(_ base64String: String) -> NSImage? {
    guard let data = Data(base64Encoded: base64String) else { return nil }
    return NSImage(data: data)
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

        guard case .object(let dict) = value else {
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

func dictObjectToJSONString(_ dict: [String: Any]) -> String {
    // Step 1: Convert dictionary into JSON-safe values
    let jsonSafe = dict.mapValues { Value(fromDecoded: $0).toJSONSafeObject() }

    // Step 2: Remove nils (because JSONSerialization cannot serialize nil)
    let cleaned = jsonSafe.compactMapValues { $0 }

    // Step 3: Validate before serialization
    guard JSONSerialization.isValidJSONObject(cleaned) else {
        logger.error("Invalid JSON object in dictObjectToJSONString.")
        return ""
    }

    do {
        let data = try JSONSerialization.data(
            withJSONObject: cleaned,
            options: [.prettyPrinted]
        )
        return String(data: data, encoding: .utf8) ?? ""
    } catch {
        logger.error("Failed to serialize JSON: \(error)")
        return ""
    }
}
