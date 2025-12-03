//
//  CacheHelpers.swift
//  AIThing
//
//  Helper functions for cache block handling and utility.
//

import Foundation

func getClientName(toolName: String, allClientTools: [String: [[String: Any]]]) -> String {
    for (clientName, tools) in allClientTools {
        for tool in tools {
            if let name = tool["name"] as? String, name == toolName {
                return clientName
            }
        }
    }
    return ""
}

func addCacheBlock(input: [[String: Any]], isMessage: Bool = false) -> [[String: Any]] {
    if !getCacheMessages() {
        return input
    }

    var updated = input

    if isMessage {
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
    } else {

        guard var last = input.last else {
            return input
        }

        last["cache_control"] = [
            "type": "ephemeral",
            "ttl": "5m",
        ]

        updated[updated.count - 1] = last
    }
    return updated
}

func shimmerPlaceholder() -> String {
    return "▌"  // or use "…" or a flashing cursor symbol
}

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

