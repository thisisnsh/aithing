//
//  Extensions.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import AppKit
import Foundation
import MCP

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
            return ""
        case .bool(let b):
            return String(b)
        case .int(let i):
            return String(i)
        case .double(let d):
            return String(d)
        case .string(let s):
            return s
        case .data(let mimeType, _):
            return "data:\(mimeType ?? "application/octet-stream")"
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
