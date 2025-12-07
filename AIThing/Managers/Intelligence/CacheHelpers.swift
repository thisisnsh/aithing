//
//  CacheHelpers.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 12/5/25.
//

import Foundation
import MCP

// MARK: - Tool Name Resolution

/// Gets the client name that owns a specific tool.
///
/// Searches through all client tools to find which client provides the specified tool.
///
/// - Parameters:
///   - toolName: The name of the tool to find
///   - allClientTools: Dictionary mapping client names to their tool definitions
/// - Returns: The client name that owns the tool, or empty string if not found
func getClientName(toolName: String, allClientTools: [String: [Tool]]) -> String {
    for (clientName, tools) in allClientTools {
        for tool in tools {
            if tool.name == toolName {
                return clientName
            }
        }
    }
    return ""
}

// MARK: - Cache Block Handling

/// Adds cache control blocks to messages or tool definitions.
///
/// When caching is enabled, adds ephemeral cache control with 5-minute TTL
/// to the last item in the input array.
///
/// - Parameters:
///   - input: Array of message or tool dictionaries
///   - isMessage: If `true`, adds cache to the last content item within the last message;
///                if `false`, adds cache directly to the last item
/// - Returns: Updated array with cache control added (if caching is enabled)
func addCacheBlock(input: [[String: Any]], isMessage: Bool = false) -> [[String: Any]] {
    guard getCacheMessages() else {
        return input
    }

    if isMessage {
        return addCacheBlockToMessage(input: input)
    } else {
        return addCacheBlockToItem(input: input)
    }
}

// MARK: - UI Helpers

/// Returns the shimmer placeholder character for streaming output.
///
/// Used to indicate that the model is still generating content.
///
/// - Returns: The shimmer cursor character
func shimmerPlaceholder() -> String {
    "▌"  // or use "…" or a flashing cursor symbol
}

// MARK: - Data Redaction

/// Redacts base64 data keys from objects for logging.
///
/// Recursively traverses dictionaries and arrays, replacing any "data" key values
/// with "<base64>" placeholder to prevent logging large base64 strings.
///
/// - Parameter object: The object to redact (dictionary, array, or other)
/// - Returns: The object with data keys redacted
func redactDataKeys(in object: Any) -> Any {
    // If it's a dictionary
    if let dict = object as? [String: Any] {
        var newDict: [String: Any] = [:]
        for (key, value) in dict {
            if key.lowercased() == "data" {
                newDict[key] = "<base64>"
            } else {
                newDict[key] = redactDataKeys(in: value)
            }
        }
        return newDict
    }

    // If it's an array, process recursively
    if let array = object as? [Any] {
        return array.map { redactDataKeys(in: $0) }
    }

    // Otherwise return unchanged
    return object
}

// MARK: - Private Helpers

/// Adds cache control to the last content item within a message.
///
/// - Parameter input: Array of message dictionaries
/// - Returns: Updated array with cache control added to last message's content
private func addCacheBlockToMessage(input: [[String: Any]]) -> [[String: Any]] {
    var updated = input

    guard var last = input.last,
        var contentArray = last["content"] as? [[String: Any]],
        var lastContent = contentArray.last
    else {
        return input
    }

    lastContent["cache_control"] = [
        "type": "ephemeral",
        "ttl": "5m",
    ]
    contentArray[contentArray.count - 1] = lastContent
    last["content"] = contentArray
    updated[updated.count - 1] = last

    return updated
}

/// Adds cache control directly to the last item in an array.
///
/// - Parameter input: Array of tool/system message dictionaries
/// - Returns: Updated array with cache control added to last item
private func addCacheBlockToItem(input: [[String: Any]]) -> [[String: Any]] {
    var updated = input

    guard var last = input.last else {
        return input
    }

    last["cache_control"] = [
        "type": "ephemeral",
        "ttl": "5m",
    ]
    updated[updated.count - 1] = last

    return updated
}
