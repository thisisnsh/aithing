//
//  MCPClientManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/13/25.
//

import Foundation
import Logging
import MCP
import System

class MCPClientManager: ObservableObject {
    var clients: [String: Client] = [:]
    var executableURL: [String: String] = [:]
    var arguments: [String: [String]] = [:]

    var logger: Logger?

    var serverInputPipe: [String: Pipe] = [:]
    var serverOutputPipe: [String: Pipe] = [:]
    var process: [String: Process] = [:]

    init() {
        print("[MCPClientManager init]")
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = .info
            return handler
        }

        clients["macos"] = Client(name: "AIThing for MacOS", version: "0.1.0")
        executableURL["macos"] = "/opt/homebrew/bin/bunx"
        arguments["macos"] = ["@dhravya/apple-mcp@latest"]
        serverInputPipe["macos"] = Pipe()
        serverOutputPipe["macos"] = Pipe()
        process["macos"] = Process()

        clients["xcode"] = Client(name: "AIThing for Xcode", version: "0.1.0")
        executableURL["xcode"] = "/usr/local/bin/xcode-npx-wrapper"
        arguments["xcode"] = ["-y", "xcodebuildmcp@latest"]
        serverInputPipe["xcode"] = Pipe()
        serverOutputPipe["xcode"] = Pipe()
        process["xcode"] = Process()

        logger = Logger(label: "com.thisisnsh.mac.AIThing")
    }

    func connect(clientName: String) async {
        do {
            let clientName = clientName.lowercased()
            guard let client = clients[clientName] else { return }
            guard let executableURL = executableURL[clientName] else { return }
            guard let arguments = arguments[clientName] else { return }
            guard let serverInputPipe = serverInputPipe[clientName] else { return }
            guard let serverOutputPipe = serverOutputPipe[clientName] else { return }
            guard let process = process[clientName] else { return }

            guard let logger = logger else { return }

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
                logger: logger
            )

            try process.run()
            print("Process launched")

            try await client.connect(transport: transport)
            print("Connected to MCP server for \(clientName)")
        } catch {
            print("Error in connecting: \(error.localizedDescription)")
        }
    }

    func getTools(clientName: String) async -> [[String: Any]] {
        let clientName = clientName.lowercased()
        do {
            guard let client = clients[clientName] else {
                return []
            }

            let (tools, _) = try await client.listTools()
            return toolsToDictionaries(tools)
        } catch {
            print("Error in getting tools: \(error.localizedDescription)")
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
                print("Error in getting tools")
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

            return response
        } catch {
            print("Error in getting tools: \(error.localizedDescription)")
            return []
        }
    }
}
