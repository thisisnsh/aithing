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
    guard let value = try? parseJSONStringToValueObject(json) else { return [:] }
    guard case let .object(dict) = value else { return [:] }
    return dict
}
