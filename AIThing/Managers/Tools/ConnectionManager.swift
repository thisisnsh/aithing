//
//  ConnectionManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 9/13/25.
//

import Foundation
import Logging
import MCP
import SwiftUI
import System
import os

// MARK: - Connection Manager

/// Manages connections to MCP servers via stdio and HTTP transports.
/// Handles client lifecycle, tool discovery, and tool execution.
class ConnectionManager: ObservableObject {

    // MARK: - Properties

    /// Active MCP clients keyed by client name
    var clients: [String: Client] = [:]

    /// Tool filters per client
    var filters: [String: [String]] = [:]

    /// Reconnection state tracking
    var reconnecting: [String: Bool] = [:]

    // MARK: - Stdio Connection Properties

    var executableURL: [String: String] = [:]
    var arguments: [String: [String]] = [:]
    var serverInputPipe: [String: Pipe] = [:]
    var serverOutputPipe: [String: Pipe] = [:]
    var process: [String: Process] = [:]

    // MARK: - HTTP Connection Properties

    var httpURL: [String: String] = [:]
    var headers: [String: [String: String]] = [:]

    // MARK: - Logging

    private let loggingLogger = Logging.Logger(label: "com.thisisnsh.mac.AIThing")

    // MARK: - Initialization

    init() {}

    // MARK: - Client Status

    /// Checks if a client with the given name exists
    func clientExists(clientName: String) -> Bool {
        clients.keys.contains(clientName.lowercased())
    }

    // MARK: - Stdio Connection

    /// Connects to an MCP server via stdio transport
    /// - Parameters:
    ///   - clientName: Unique identifier for the client
    ///   - command: Path to the executable
    ///   - args: Command line arguments
    /// - Returns: Empty string on success, error message on failure
    func connect(clientName: String, command: String, args: [String]) async -> String {
        let normalizedName = clientName.lowercased()

        do {
            let client = createClient(name: normalizedName)
            let (inputPipe, outputPipe, proc) = createStdioComponents(
                command: command,
                args: args
            )

            storeStdioConnection(
                clientName: normalizedName,
                client: client,
                command: command,
                args: args,
                inputPipe: inputPipe,
                outputPipe: outputPipe,
                process: proc
            )

            let transport = createStdioTransport(inputPipe: inputPipe, outputPipe: outputPipe)

            try proc.run()
            try await client.connect(transport: transport)

            logger.info("Connected to MCP server via stdio: \(normalizedName)")
            return ""
        } catch {
            logger.error("Stdio connection error: \(error.localizedDescription)")
            cleanupStdioConnection(clientName: normalizedName)
            return error.localizedDescription
        }
    }

    // MARK: - HTTP Connection

    /// Connects to an MCP server via HTTP transport
    /// - Parameters:
    ///   - clientName: Unique identifier for the client
    ///   - url: Server URL
    ///   - authToken: Optional bearer token for authentication
    /// - Returns: Empty string on success, error message on failure
    func connect(clientName: String, url: String, authToken: String?) async -> String {
        let normalizedName = clientName.lowercased()

        do {
            let client = createClient(name: normalizedName)

            storeHTTPConnection(
                clientName: normalizedName,
                client: client,
                url: url,
                authToken: authToken
            )

            let transport = try createHTTPTransport(url: url, authToken: authToken)
            try await client.connect(transport: transport)

            logger.info("Connected to MCP server via HTTP: \(normalizedName)")
            return ""
        } catch {
            logger.error("HTTP connection error: \(error.localizedDescription)")
            cleanupHTTPConnection(clientName: normalizedName)
            return error.localizedDescription
        }
    }

    // MARK: - Reconnection

    /// Attempts to reconnect to an HTTP-based MCP server
    /// - Parameters:
    ///   - clientName: Client identifier to reconnect
    ///   - url: Server URL
    ///   - authToken: Bearer token for authentication
    /// - Returns: True if reconnection succeeded
    func reconnect(clientName: String, url: String, authToken: String) async -> Bool {
        let normalizedName = clientName.lowercased()

        // Wait if another reconnection is in progress
        if reconnecting[normalizedName] ?? false {
            while reconnecting[normalizedName] ?? false {
                logger.debug("Waiting for existing reconnection: \(normalizedName)")
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            return true
        }

        reconnecting[normalizedName] = true
        defer { reconnecting[normalizedName] = false }

        logger.debug("Reconnecting: \(normalizedName)")

        if let client = clients[normalizedName] {
            await client.disconnect()
        }

        let result = await connect(clientName: normalizedName, url: url, authToken: authToken)

        return result.isEmpty
    }

    // MARK: - Disconnection

    /// Disconnects all active clients and releases resources
    /// - Returns: Empty string on success, error message on failure
    func disconnect() async -> String {
        // Disconnect all clients
        for client in clients.values {
            await client.disconnect()
        }
        clients.removeAll()

        // Cleanup HTTP resources
        httpURL.removeAll()
        headers.removeAll()

        // Cleanup stdio resources
        terminateAllProcesses()
        closeAllPipes()

        return ""
    }

    // MARK: - Tool Operations

    /// Retrieves available tools from a connected client
    /// - Parameters:
    ///   - clientName: Client identifier
    ///   - filter: Optional list of tool names to include (empty = all)
    /// - Returns: Array of tool definitions as dictionaries
    func getTools(clientName: String, filter: [String]) async -> [Tool] {
        let normalizedName = clientName.lowercased()

        guard let client = clients[normalizedName] else {
            return []
        }

        do {
            filters[normalizedName] = filter
            let (tools, _) = try await client.listTools()
            let filteredTools = tools.filter { filter.isEmpty || filter.contains($0.name) }

            return filteredTools
        } catch {
            logger.error("Error getting tools: \(error.localizedDescription)")
            return []
        }
    }

    /// Executes a tool on a connected client
    /// - Parameters:
    ///   - clientName: Client identifier
    ///   - name: Tool name to execute
    ///   - input: JSON string containing tool arguments
    /// - Returns: Array of response content blocks
    func callTools(clientName: String, name: String, input: String) async -> String {
        let normalizedName = clientName.lowercased()

        guard let client = clients[normalizedName] else {
            return "Error: Client not connected"
        }

        guard let value = try? parseJSONStringToValueObject(input),
            case .object(let dict) = value
        else {
            return "Error parsing JSON input"
        }

        do {
            let (content, isError) = try await client.callTool(name: name, arguments: dict)

            if isError ?? false {
                logger.error("Tool call returned error")
                return "Tool call returned error"
            }

            let response = extractTextContent(from: content)
            return response
        } catch {
            logger.error("Error calling tool: \(error.localizedDescription)")
            return "Error calling tool"
        }
    }
}

// MARK: - Private Helpers

extension ConnectionManager {

    fileprivate func createClient(name: String) -> Client {
        Client(name: "AIThing for \(name)", version: "0.1.0")
    }

    fileprivate func createStdioComponents(command: String, args: [String]) -> (Pipe, Pipe, Process) {
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let proc = Process()

        proc.executableURL = URL(fileURLWithPath: command)
        proc.arguments = args
        proc.standardInput = inputPipe
        proc.standardOutput = outputPipe

        return (inputPipe, outputPipe, proc)
    }

    fileprivate func createStdioTransport(inputPipe: Pipe, outputPipe: Pipe) -> StdioTransport {
        let serverInput = FileDescriptor(rawValue: inputPipe.fileHandleForWriting.fileDescriptor)
        let serverOutput = FileDescriptor(rawValue: outputPipe.fileHandleForReading.fileDescriptor)

        return StdioTransport(
            input: serverOutput,
            output: serverInput,
            logger: loggingLogger
        )
    }

    fileprivate func createHTTPTransport(url: String, authToken: String?) throws -> any Transport {
        guard let endpoint = URL(string: url) else {
            throw ConnectionError.invalidURL
        }

        let configuration = URLSessionConfiguration.default
        if let token = authToken {
            configuration.httpAdditionalHeaders = ["Authorization": "Bearer \(token)"]
        }

        let isLegacySSE = url.hasSuffix("/sse/") || url.hasSuffix("/sse")

        if isLegacySSE {
            return SSEClientTransport(
                endpoint: endpoint,
                token: authToken,
                configuration: configuration,
                logger: loggingLogger
            )
        } else {
            return HTTPClientTransport(
                endpoint: endpoint,
                configuration: configuration,
                streaming: true,
                sseInitializationTimeout: 60,
                logger: loggingLogger
            )
        }
    }

    fileprivate func storeStdioConnection(
        clientName: String,
        client: Client,
        command: String,
        args: [String],
        inputPipe: Pipe,
        outputPipe: Pipe,
        process: Process
    ) {
        clients[clientName] = client
        executableURL[clientName] = command
        arguments[clientName] = args
        serverInputPipe[clientName] = inputPipe
        serverOutputPipe[clientName] = outputPipe
        self.process[clientName] = process
    }

    fileprivate func storeHTTPConnection(
        clientName: String,
        client: Client,
        url: String,
        authToken: String?
    ) {
        clients[clientName] = client
        httpURL[clientName] = url
        headers[clientName] = authToken.map { ["Authorization": "Bearer \($0)"] } ?? [:]
    }

    fileprivate func cleanupStdioConnection(clientName: String) {
        clients.removeValue(forKey: clientName)
        executableURL.removeValue(forKey: clientName)
        arguments.removeValue(forKey: clientName)

        closePipes(for: clientName)
        terminateProcess(for: clientName)
    }

    fileprivate func cleanupHTTPConnection(clientName: String) {
        clients.removeValue(forKey: clientName)
        httpURL.removeValue(forKey: clientName)
        headers.removeValue(forKey: clientName)
    }

    fileprivate func closePipes(for clientName: String) {
        do {
            try serverInputPipe[clientName]?.fileHandleForReading.close()
            try serverOutputPipe[clientName]?.fileHandleForReading.close()
        } catch {}

        serverInputPipe.removeValue(forKey: clientName)
        serverOutputPipe.removeValue(forKey: clientName)
    }

    fileprivate func closeAllPipes() {
        for pipe in serverInputPipe.values {
            try? pipe.fileHandleForReading.close()
            try? pipe.fileHandleForWriting.close()
        }
        for pipe in serverOutputPipe.values {
            try? pipe.fileHandleForReading.close()
            try? pipe.fileHandleForWriting.close()
        }
        serverInputPipe.removeAll()
        serverOutputPipe.removeAll()
    }

    fileprivate func terminateProcess(for clientName: String) {
        if let proc = process[clientName], proc.isRunning {
            proc.terminate()
        }
        process.removeValue(forKey: clientName)
    }

    fileprivate func terminateAllProcesses() {
        for proc in process.values where proc.isRunning {
            proc.terminate()
        }
        process.removeAll()
        executableURL.removeAll()
        arguments.removeAll()
    }

    fileprivate func extractTextContent(from content: [Tool.Content]) -> String {
        let strings = content.compactMap { item -> String? in
            if case .text(let text) = item {
                return text
            }
            return nil
        }
        var result = ""
        for string in strings {
            result += string + " "
        }
        return result
    }
}
