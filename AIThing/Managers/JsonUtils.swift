//
//  JsonUtils.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/13/25.
//

import Foundation
import MCP

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
    let data = Data(json.utf8)
    let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
    return Value(fromDecoded: jsonObject)
}

func parseJSONStringToDictObject(_ json: String) -> [String: Any] {
    do {
        let data = Data(json.utf8)
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])

        let value = Value(fromDecoded: jsonObject)

        guard case let .object(dict) = value else {
            print("JSON root is not an object.")
            return [:]
        }

        let jsonSafeDict = dict.mapValues { $0.toJSONSafeObject() }

        return jsonSafeDict.compactMapValues { $0 }  // removes nils safely
    } catch {
        print("Failed to parse JSON: \(error)")
        return [:]
    }
}
