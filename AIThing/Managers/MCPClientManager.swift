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
    var client: Client?
    var logger: Logger?

    let serverInputPipe = Pipe()
    let serverOutputPipe = Pipe()
    let process = Process()

    init() {
        print("[MCPClientManager init]")
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = .info
            return handler
        }

        client = Client(name: "AIThing", version: "0.1.0")
        logger = Logger(label: "com.thisisnsh.mac.AIThing")
    }

    func connect() async {
        do {
            guard let client = client else { return }
            guard let logger = logger else { return }

            let serverInput: FileDescriptor = FileDescriptor(
                rawValue: serverInputPipe.fileHandleForWriting.fileDescriptor
            )
            let serverOutput: FileDescriptor = FileDescriptor(
                rawValue: serverOutputPipe.fileHandleForReading.fileDescriptor
            )

            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/bunx")
            process.arguments = ["@dhravya/apple-mcp@latest"]
            process.standardInput = serverInputPipe
            process.standardOutput = serverOutputPipe

            let transport = StdioTransport(
                input: serverOutput,
                output: serverInput,
                logger: logger
            )

            try process.run()
            logger.debug("Process launched")

            try await client.connect(transport: transport)
            logger.debug("Connected to MCP server")
        } catch {
            print("Error in connecting: \(error.localizedDescription)")
        }
    }

    func getTools() async -> [[String: Any]] {
        do {
            guard let logger = logger else {
                print("Logger is nil")
                return []
            }
            guard let client = client else {
                logger.error("Client is nil")
                return []
            }

            let (tools, _) = try await client.listTools()
            return toolsToDictionaries(tools)
        } catch {
            print("Error in getting tools: \(error.localizedDescription)")
            return []
        }
    }

    func callTools(name: String, input: String) async -> [[String: Any]] {
        do {
            guard let logger = logger else {
                print("Logger is nil")
                return []
            }
            guard let client = client else {
                logger.error("Client is nil")
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
