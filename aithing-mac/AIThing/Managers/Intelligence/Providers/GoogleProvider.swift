//
//  GoogleProvider.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 12/5/25.
//

import Foundation
import MCP

/// Provider implementation for Google's Gemini API.
final class GoogleProvider: AIProviderProtocol {

    // MARK: - Properties

    let provider: AIProvider = .google  // Assuming .google exists in your AIProvider enum

    // MARK: - Request Building

    func buildRequest(
        apiKey: String,
        model: String,
        messages: [ChatItem],
        tools: [Tool],
        systemMessages: [ChatPayload],
        maxTokens: Int,
        stream: Bool
    ) -> URLRequest? {
        let type = stream ? "streamGenerateContent" : "generateContent"
        let baseUrl = "https://generativelanguage.googleapis.com/v1beta/models/\(model):\(type)"
        guard var components = URLComponents(string: baseUrl) else { return nil }

        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        if stream {
            components.queryItems?.append(URLQueryItem(name: "alt", value: "sse"))  // Server-Sent Events
        }

        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Gemini separates System Instructions from the main message history
        let systemInstruction = convertSystemMessages(systemMessages).first ?? [:]
        let contents = convertMessages(messages)
        let toolDeclarations = convertTools(tools)

        let body: [String: Any] = [
            "contents": contents,
            "generationConfig": [
                "maxOutputTokens": maxTokens,
                "temperature": 1,
            ],
            "systemInstruction": systemInstruction,
            "tools": [["function_declarations": toolDeclarations]],
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: - Stream Parsing

    func parseStreamLine(_ line: String) -> StreamEvent? {
        guard line.starts(with: "data: ") else { return nil }

        let jsonString = line.replacingOccurrences(of: "data: ", with: "")

        // Gemini streams often end simply, but we check for empty JSON or errors
        if jsonString.trimmingCharacters(in: .whitespaces).isEmpty {
            return nil
        }

        guard
            let data = jsonString.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let candidate = candidates.first
        else { return nil }

        // Check for finish reason first
        let hasFinish = candidate["finishReason"] != nil

        // Parse content parts
        if let content = candidate["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]]
        {

            // Iterate through parts (Gemini can send text and tool calls in one go, though rare in stream)
            for part in parts {
                if let text = part["text"] as? String {
                    if hasFinish {
                        return .endText(text)  // Final text
                    } else {
                        return .text(text)  // Partial text
                    }
                }

                if let functionCall = part["functionCall"] as? [String: Any] {
                    return parseFunctionCall(functionCall)
                }
            }
        }

        return nil
    }

    private func parseFunctionCall(_ call: [String: Any]) -> StreamEvent? {
        guard let name = call["name"] as? String else { return nil }

        // Gemini sends the full arguments object, not a stringified JSON Delta
        if let args = call["args"] as? [String: Any],
            let jsonData = try? JSONSerialization.data(withJSONObject: args),
            let jsonString = String(data: jsonData, encoding: .utf8)
        {
            let generatedId = UUID().uuidString
            return .toolUse(id: generatedId, name: name, input: jsonString)
        }

        return nil
    }

    private func parseFinishReason(_ finish: String) -> StreamEvent {
        return .done(stopReason: StopReason(from: finish))
    }

    // MARK: - Message Conversion

    func convertMessages(_ messages: [ChatItem]) -> [[String: Any]] {
        messages.compactMap { message in
            var parts: [[String: Any]] = []

            for payload in message.payloads {
                switch payload {
                case .text(let text):
                    parts.append(["text": text])

                case .textWithName(_, let text):
                    parts.append(["text": text])

                case .imageBase64(_, let media, let image):
                    parts.append([
                        "inline_data": [
                            "mime_type": media,
                            "data": image,
                        ]
                    ])

                case .toolUse(_, let name, let input):
                    parts.append([
                        "function_call": [
                            "name": name,
                            "args": input,
                        ]
                    ])

                case .toolResult(_, let name, let result):
                    parts.append([
                        "function_response": [
                            "name": name,
                            "response": ["result": result],
                        ]
                    ])
                }
            }

            // Map Roles: "assistant" -> "model", "user" -> "user"
            let role = (message.role == .assistant) ? "model" : "user"

            return [
                "role": role,
                "parts": parts,
            ]
        }
    }

    func convertTools(_ tools: [Tool]) -> [[String: Any]] {
        tools.compactMap { tool -> [String: Any]? in
            let name = tool.name
            let description = tool.description

            var parameters: [String: Any] = ["type": "object", "properties": [:]]

            if let inputSchema = tool.inputSchema,
                let schemaDict = inputSchema.stringified() as? [String: Any]
            {
                parameters = schemaDict
            }

            return [
                "name": name,
                "description": description,
                "parameters": parameters,
            ]
        }
    }

    func convertSystemMessages(_ messages: [ChatPayload]) -> [[String: Any]] {
        let systemText = messages.compactMap { msg -> String? in
            if case .text(let text) = msg { return text }
            if case .textWithName(_, let text) = msg { return text }
            return nil
        }.joined(separator: "\n\n")

        if !systemText.isEmpty {
            return [["parts": ["text": systemText]]]
        }
        return []
    }

    // MARK: - Message Building (Helpers)

    func buildToolResultMessage(toolUseId: String, toolName: String, result: String) -> [ChatItem] {
        return [ChatItem(role: .user, payload: .toolResult(id: toolUseId, name: toolName, result: result))]
    }

    func buildAssistantToolUseMessage(text: String?, toolUseId: String, toolName: String, toolInput: [String: Any]) -> [ChatItem] {
        var payloads: [ChatPayload] = []
        if let text = text, !text.isEmpty {
            payloads.append(.text(text: text))
        }
        payloads.append(.toolUse(id: toolUseId, name: toolName, input: toolInput))
        return [ChatItem(role: .assistant, payloads: payloads)]
    }

    func buildAssistantTextMessage(text: String) -> [ChatItem] {
        [ChatItem(role: .assistant, payload: .text(text: text))]
    }
}
