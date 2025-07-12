//
//  Environment.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import Foundation

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
