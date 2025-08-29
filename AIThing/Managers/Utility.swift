//
//  Environment.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import AppKit
import Foundation
import MCP
import os

let logger = Logger(subsystem: "com.thisisnsh.mac.AIThing", category: "Utility")

struct Env {
    static func get(_ key: String) -> String? {
        guard let url = Bundle.main.url(forResource: ".env", withExtension: nil),
            let data = try? String(contentsOf: url, encoding: .utf8)
        else {
            return nil
        }

        for line in data.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let k = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let v = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                if k == key { return v }
            }
        }
        return nil
    }
}

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

func parseJSONStringToValueObject(_ json: String) throws -> Value {
    if json.isEmpty {
        return [:]
    }
    
    let data = Data(json.utf8)
    let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
    return Value(fromDecoded: jsonObject)
}

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

extension NSPasteboard {
    private static var lastKnownChangeCount: Int = 0
    private static var lastChangeTime: Date?

    func changeCountTimestamp() -> Date? {
        if changeCount != Self.lastKnownChangeCount {
            Self.lastKnownChangeCount = changeCount
            Self.lastChangeTime = Date()
        }
        return Self.lastChangeTime
    }
}

extension Value {
    func stringified() -> Any {
        switch self {
        case .null:
            return NSNull()
        case .bool(let b):
            return b
        case .int(let i):
            return i
        case .double(let d):
            return d
        case .string(let s):
            return s
        case .data(let mimeType, let data):
            let base64 = data.base64EncodedString()
            let mime = mimeType ?? "application/octet-stream"
            return "data:\(mime);base64,\(base64)"
        case .array(let arr):
            return arr.map { $0.stringified() }
        case .object(let dict):
            return dict.mapValues { $0.stringified() }
        }
    }

    init(fromDecoded any: Any) {
        switch any {
        case let b as Bool:
            self = .bool(b)
        case let i as Int:
            self = .int(i)
        case let d as Double:
            self = .double(d)
        case let s as String:
            self = .string(s)
        case let arr as [Any]:
            self = .array(arr.map { Value(fromDecoded: $0) })
        case let dict as [String: Any]:
            self = .object(dict.mapValues { Value(fromDecoded: $0) })
        default:
            self = .null  // fallback
        }
    }

    func toJSONSafeObject() -> Any {
        self.stringified()
    }
}
