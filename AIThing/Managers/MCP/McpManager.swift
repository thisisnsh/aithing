//
//  MCPManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/13/25.
//

import Foundation
import Logging
import MCP
import SwiftUI
import System
import os

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
            AnalyticsManager.shared.customError(
                type: "unrecognized_json_structure",
                severity: "high",
                location: "settings_manager"
            )
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Unrecognized JSON structure")
            )
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
}

class MCPManager: ObservableObject {
    var reconnecting: [String: Bool] = [:]
    var clients: [String: Client] = [:]
    var filters: [String: [String]] = [:]

    var executableURL: [String: String] = [:]
    var arguments: [String: [String]] = [:]

    var httpURL: [String: String] = [:]
    var headers: [String: [String: String]] = [:]

    var serverInputPipe: [String: Pipe] = [:]
    var serverOutputPipe: [String: Pipe] = [:]
    var process: [String: Process] = [:]

    var logger = os.Logger(subsystem: "com.thisisnsh.mac.AIThing", category: "MCPManager")
    var loggingLogger = Logging.Logger(label: "com.thisisnsh.mac.AIThing")

    init() {}

    func clientExists(clientName: String) -> Bool {
        return clients.keys.contains(clientName)
    }

    func connect(clientName: String, command: String, args: [String]) async -> String {
        do {
            let clientName = clientName.lowercased()
            clients[clientName] = Client(name: "AIThing for \(clientName)", version: "0.1.0")
            executableURL[clientName] = command
            arguments[clientName] = args
            serverInputPipe[clientName] = Pipe()
            serverOutputPipe[clientName] = Pipe()
            process[clientName] = Process()

            guard let client = clients[clientName] else { return "Client not found" }
            guard let executableURL = executableURL[clientName] else {
                return "Executable not found"
            }
            guard let arguments = arguments[clientName] else { return "Argument not found" }
            guard let serverInputPipe = serverInputPipe[clientName] else {
                return "Input pipe not found"
            }
            guard let serverOutputPipe = serverOutputPipe[clientName] else {
                return "Output pipe not found"
            }
            guard let process = process[clientName] else { return "Process not found" }

            let serverInput: FileDescriptor = FileDescriptor(
                rawValue: serverInputPipe.fileHandleForWriting.fileDescriptor
            )
            let serverOutput: FileDescriptor = FileDescriptor(
                rawValue: serverOutputPipe.fileHandleForReading.fileDescriptor
            )

            process.executableURL = URL(fileURLWithPath: executableURL)
            process.arguments = arguments
            process.standardInput = serverInputPipe
            process.standardOutput = serverOutputPipe

            let transport = StdioTransport(
                input: serverOutput,
                output: serverInput,
                logger: loggingLogger
            )

            try process.run()

            try await client.connect(transport: transport)
            logger.info("Connected to MCP server for \(clientName)")
            AnalyticsManager.shared.selectItem(
                itemID: "mcp_connected_stdio",
                itemName: "mcp_connected_stdio"
            )
            return ""
        } catch {
            AnalyticsManager.shared.customError(
                type: "mcp_error_in_connecting_stdio",
                severity: "high",
                location: "mcp_manager"
            )
            logger.error("Error in connecting: \(error.localizedDescription)")
            clients.removeValue(forKey: clientName)
            executableURL.removeValue(forKey: clientName)
            arguments.removeValue(forKey: clientName)

            do {
                if serverInputPipe[clientName] != nil, serverOutputPipe[clientName] != nil {
                    try serverInputPipe[clientName]!.fileHandleForReading.close()
                    try serverOutputPipe[clientName]!.fileHandleForReading.close()
                }
                serverInputPipe.removeValue(forKey: clientName)
                serverOutputPipe.removeValue(forKey: clientName)
            } catch {}

            if process[clientName] != nil, process[clientName]!.isRunning {
                process[clientName]!.terminate()
            }
            process.removeValue(forKey: clientName)
            return error.localizedDescription
        }
    }

    func connect(clientName: String, url: String, authToken: String?) async -> String {
        do {
            let clientName = clientName.lowercased()
            clients[clientName] = Client(name: "AIThing for \(clientName)", version: "0.1.0")
            httpURL[clientName] = url
            if let authToken = authToken {
                headers[clientName] = ["Authorization": "Bearer \(authToken)"]
            } else {
                headers[clientName] = [:]
            }

            guard let client = clients[clientName] else { return "Client not found" }
            guard let httpURL = httpURL[clientName] else { return "URL not found" }
            guard let headers = headers[clientName] else { return "Header not found" }

            let configuration = URLSessionConfiguration.default
            configuration.httpAdditionalHeaders = headers

            let legacySse = httpURL.hasSuffix("/sse/") || httpURL.hasSuffix("/sse")
            if legacySse {
                let transport = SSEClientTransport(
                    endpoint: URL(string: httpURL)!,
                    token: authToken,
                    configuration: configuration,
                    logger: loggingLogger
                )
                try await client.connect(transport: transport)
            } else {
                let transport = HTTPClientTransport(
                    endpoint: URL(string: httpURL)!,
                    configuration: configuration,
                    streaming: true,
                    sseInitializationTimeout: 60,
                    logger: loggingLogger
                )
                try await client.connect(transport: transport)
            }

            logger.info("Connected to MCP server for \(clientName)")
            AnalyticsManager.shared.selectItem(
                itemID: "mcp_connected_http",
                itemName: "mcp_connected_http"
            )
            return ""
        } catch {
            AnalyticsManager.shared.customError(
                type: "mcp_error_in_connecting_http",
                severity: "high",
                location: "mcp_manager"
            )
            logger.error("Error in connecting: \(error.localizedDescription)")
            clients.removeValue(forKey: clientName)
            httpURL.removeValue(forKey: clientName)
            headers.removeValue(forKey: clientName)
            return error.localizedDescription
        }
    }

    func reconnect(clientName: String, url: String, authToken: String) async -> Bool {
        // If another tab is reconnecting let it do that
        if reconnecting[clientName] ?? false {
            while reconnecting[clientName] ?? false {
                logger.info("Let other tab reconnect: \(clientName)")
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            return true
        }

        reconnecting[clientName] = true
        logger.info("Reconnecting: \(clientName)")

        if let client = clients[clientName] {
            await client.disconnect()
        }
        let rc = await connect(clientName: clientName, url: url, authToken: authToken)
        AnalyticsManager.shared.selectItem(
            itemID: "mcp_reconnected",
            itemName: "mcp_reconnected"
        )

        reconnecting[clientName] = false
        return rc.isEmpty
    }

    func disconnect() async -> String {
        do {
            for client in clients.values {
                await client.disconnect()
            }
            clients.removeAll()
            httpURL.removeAll()
            headers.removeAll()

            for (_, process) in process {
                if process.isRunning {
                    process.terminate()
                }
            }
            process.removeAll()
            executableURL.removeAll()
            arguments.removeAll()

            for pipe in serverInputPipe.values {
                try pipe.fileHandleForReading.close()
                try pipe.fileHandleForWriting.close()
            }
            for pipe in serverOutputPipe.values {
                try pipe.fileHandleForReading.close()
                try pipe.fileHandleForWriting.close()
            }
            serverInputPipe.removeAll()
            serverOutputPipe.removeAll()

            AnalyticsManager.shared.selectItem(
                itemID: "mcp_disconnected",
                itemName: "mcp_disconnected"
            )
            return ""
        } catch {
            AnalyticsManager.shared.customError(
                type: "mcp_error_in_disconnecting",
                severity: "high",
                location: "mcp_manager"
            )
            logger.error("Error in disconnecting: \(error.localizedDescription)")
            return error.localizedDescription
        }
    }

    func getAllTools() async -> [String: [Tool]] {
        var tools: [String: [Tool]] = [:]
        do {
            for (clientName, client) in clients {
                let (t, _) = try await client.listTools()
                let filter = filters[clientName] ?? []
                let filteredTools = t.filter { filter.contains($0.name) || filter.isEmpty }
                if !filteredTools.isEmpty {
                    tools[formatManagedString(clientName)] = filteredTools
                }
            }
        } catch {}
        return tools
    }

    func getTools(clientName: String, filter: [String]) async -> [[String: Any]] {
        let clientName = clientName.lowercased()
        do {
            guard let client = clients[clientName] else {
                return []
            }
            filters[clientName] = filter
            let (tools, _) = try await client.listTools()
            let filteredTools = tools.filter { filter.contains($0.name) || filter.isEmpty }
            AnalyticsManager.shared.selectItem(itemID: "mcp_get_tools", itemName: "mcp_get_tools")
            return toolsToDictionaries(filteredTools)
        } catch {
            AnalyticsManager.shared.customError(
                type: "mcp_error_in_getting_tools",
                severity: "high",
                location: "mcp_manager"
            )
            logger.error("Error in getting tools: \(error.localizedDescription)")
            return []
        }
    }

    func callTools(clientName: String, name: String, input: String) async -> [[String: Any]] {
        let clientName = clientName.lowercased()
        do {
            guard let client = clients[clientName] else {
                return []
            }

            guard let value = try? parseJSONStringToValueObject(input) else { return [] }
            guard case let .object(dict) = value else { return [] }

            let (content, isError) = try await client.callTool(name: name, arguments: dict)
            if isError ?? false {
                AnalyticsManager.shared.customError(
                    type: "mcp_call_tools_error",
                    severity: "high",
                    location: "mcp_manager"
                )
                logger.error("Error in calling tools")
                return []
            }

            var response: [[String: Any]] = []

            for item in content {
                switch item {
                case .text(let text):
                    response.append(["type": "text", "text": text])
                default:
                    continue
                }
            }

            AnalyticsManager.shared.selectItem(itemID: "mcp_call_tools", itemName: "mcp_call_tools")
            return response
        } catch {
            AnalyticsManager.shared.customError(
                type: "mcp_error_in_calling_tools",
                severity: "high",
                location: "mcp_manager"
            )
            logger.error("Error in calling tools: \(error.localizedDescription)")
            return []
        }
    }

    func formatManagedString(_ input: String) -> String {
        var trimmed = input
        if !trimmed.hasPrefix("managed_") {
            return input
        }

        if trimmed == "managed_github_mcp" {
            trimmed = "managed_github"
        } else if trimmed == "managed_google_mcp" {
            trimmed = "managed_google"
        }

        // 1. Remove the "managed_" prefix if it exists
        trimmed.removeFirst("managed_".count)

        // 2. Split by underscore
        let parts = trimmed.split(separator: "_")

        // 3. Capitalize each word
        let capitalizedParts = parts.map { part in
            part.prefix(1).uppercased() + part.dropFirst()
        }

        // 4. Join with spaces
        return capitalizedParts.joined(separator: " ")
    }

}
