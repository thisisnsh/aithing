//
//  AgentModels.swift
//  AIThing
//
//  Created by Nishant Singh Hada.
//

import Foundation

// MARK: - Connection Errors

/// Errors that can occur during MCP connection operations
enum ConnectionError: LocalizedError {
    case invalidURL
    case clientNotFound
    case transportCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .clientNotFound:
            return "Client not found"
        case .transportCreationFailed:
            return "Failed to create transport"
        }
    }
}

// MARK: - Agent Entry

struct AgentEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var entry: Entry
    var isEnabled: Bool
}

enum McpEntry {
    case url
    case urlWithToken
    case command
}

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
            let arguments = try? container.decode([String].self, forKey: .arguments)
        {
            self = .command(name: name, command: command, arguments: arguments)
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Unrecognized JSON structure")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .url(let name, let url):
            try container.encode(name, forKey: .name)
            try container.encode(url, forKey: .url)
        case .urlWithToken(let name, let url, let token):
            try container.encode(name, forKey: .name)
            try container.encode(url, forKey: .url)
            try container.encode(token, forKey: .authorization_token)
        case .command(let name, let command, let arguments):
            try container.encode(name, forKey: .name)
            try container.encode(command, forKey: .command)
            try container.encode(arguments, forKey: .arguments)
        }
    }
}

