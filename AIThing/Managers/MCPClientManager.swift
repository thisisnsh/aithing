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

        clients["Global"] = Client(name: "AIThing for Global", version: "0.1.0")
        executableURL["Global"] = "/opt/homebrew/bin/bunx"
        arguments["Global"] = ["@dhravya/apple-mcp@latest"]
        serverInputPipe["Global"] = Pipe()
        serverOutputPipe["Global"] = Pipe()
        process["Global"] = Process()

        clients["Xcode"] = Client(name: "AIThing for Xcode", version: "0.1.0")
        executableURL["Xcode"] = "/usr/local/bin/xcode-npx-wrapper"
        arguments["Xcode"] = ["-y", "xcodebuildmcp@latest"]
        serverInputPipe["Xcode"] = Pipe()
        serverOutputPipe["Xcode"] = Pipe()
        process["Xcode"] = Process()

        logger = Logger(label: "com.thisisnsh.mac.AIThing")
    }

    func connect(appName: String) async {
        do {
            guard let client = clients[appName] else { return }
            guard let executableURL = executableURL[appName] else { return }
            guard let arguments = arguments[appName] else { return }
            guard let serverInputPipe = serverInputPipe[appName] else { return }
            guard let serverOutputPipe = serverOutputPipe[appName] else { return }
            guard let process = process[appName] else { return }

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
            print("Connected to MCP server for \(appName)")
        } catch {
            print("Error in connecting: \(error.localizedDescription)")
        }
    }

    func getTools(appName: String) async -> [[String: Any]] {
        do {
            guard let client = clients[appName] else {
                return []
            }

            let (tools, _) = try await client.listTools()
            return toolsToDictionaries(tools)
        } catch {
            print("Error in getting tools: \(error.localizedDescription)")
            return []
        }
    }

    func callTools(appName: String, name: String, input: String) async -> [[String: Any]] {
        do {
            guard let client = clients[appName] else {
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
