//
//  SettingsManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/27/25.
//

import Foundation
import SwiftUI

// Define enum to hold different types of inputs
enum Entry: Codable, Identifiable, Equatable {
    case url(name: String, url: String)
    case urlWithToken(name: String, url: String, token: String)
    case command(name: String, command: String, arguments: [String])

    var id: UUID { UUID() }

    enum CodingKeys: String, CodingKey {
        case name, url, authorization_token, command, arguments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let name = try container.decode(String.self, forKey: .name)

        if let url = try? container.decode(String.self, forKey: .url) {
            if let token = try? container.decode(String.self, forKey: .authorization_token) {
                self = .urlWithToken(name: name, url: url, token: token)
            } else {
                self = .url(name: name, url: url)
            }
        } else if let command = try? container.decode(String.self, forKey: .command),
                  let arguments = try? container.decode([String].self, forKey: .arguments) {
            self = .command(name: name, command: command, arguments: arguments)
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unrecognized JSON structure"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .url(name, url):
            try container.encode(name, forKey: .name)
            try container.encode(url, forKey: .url)
        case let .urlWithToken(name, url, token):
            try container.encode(name, forKey: .name)
            try container.encode(url, forKey: .url)
            try container.encode(token, forKey: .authorization_token)
        case let .command(name, command, arguments):
            try container.encode(name, forKey: .name)
            try container.encode(command, forKey: .command)
            try container.encode(arguments, forKey: .arguments)
        }
    }

    var displayString: String {
        switch self {
        case let .url(name, url):
            return "name: \(name)\nurl: \(url)"
        case let .urlWithToken(name, url, token):
            return "name: \(name)\nurl: \(url)\ntoken: \(token)"
        case let .command(name, command, arguments):
            return "name: \(name)\ncommand: \(command)\nargs: \(arguments.joined(separator: " "))"
        }
    }
}

