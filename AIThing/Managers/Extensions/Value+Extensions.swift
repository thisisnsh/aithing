//
//  Value+Extensions.swift
//  AIThing
//
//  Created by Nishant Singh Hada.
//

import Foundation
import MCP

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

