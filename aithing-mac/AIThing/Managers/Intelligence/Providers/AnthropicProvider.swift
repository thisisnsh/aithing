//
//  AnthropicProvider.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 12/5/25.
//

import Foundation
import MCP

/// Provider implementation for Anthropic's Claude API.
final class AnthropicProvider: AIProviderProtocol {

    // MARK: - Properties

    let provider: AIProvider = .anthropic

    private let apiURL = "https://api.anthropic.com/v1/messages"
    private let apiVersion = "2023-06-01"

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
        guard let url = URL(string: apiURL) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("extended-cache-ttl-2025-04-11", forHTTPHeaderField: "anthropic-beta")

        let systemMessages = addCacheBlock(input: convertSystemMessages(systemMessages))
        let processedMessages = addCacheBlock(input: convertMessages(messages), isMessage: true)
        let processedTools = addCacheBlock(input: convertTools(tools))

        let body: [String: Any] = [
            "model": model,
            "stream": stream,
            "max_tokens": maxTokens,
            "temperature": 1,
            "messages": processedMessages,
            "tools": processedTools,
            "system": systemMessages,
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: - Stream Parsing

    func parseStreamLine(_ line: String) -> StreamEvent? {
        guard line.starts(with: "data: ") else { return nil }

        let jsonString = line.replacingOccurrences(of: "data: ", with: "")

        guard let data = jsonString.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let dataType = json["type"] as? String
        else { return nil }

        switch dataType {
        case "content_block_start":
            return parseContentBlockStart(json: json)

        case "content_block_delta":
            return parseContentBlockDelta(json: json)

        case "content_block_stop":
            return nil  // .contentBlockStop

        case "message_delta":
            return parseMessageDelta(json: json)

        case "error":
            if let error = json["error"] as? [String: Any],
                let message = error["message"] as? String
            {
                return .error(message)
            }
            return .error("Unknown error")

        default:
            return nil
        }
    }

    private func parseContentBlockStart(json: [String: Any]) -> StreamEvent? {
        guard let contentBlock = json["content_block"] as? [String: Any],
            let contentBlockType = contentBlock["type"] as? String,
            contentBlockType == "tool_use",
            let id = contentBlock["id"] as? String,
            let name = contentBlock["name"] as? String
        else { return nil }

        return .toolUseStart(id: id, name: name)
    }

    private func parseContentBlockDelta(json: [String: Any]) -> StreamEvent? {
        guard let delta = json["delta"] as? [String: Any],
            let deltaType = delta["type"] as? String
        else { return nil }

        switch deltaType {
        case "text_delta":
            guard let text = delta["text"] as? String else { return nil }
            return .text(text)

        case "input_json_delta":
            guard let partialJson = delta["partial_json"] as? String else { return nil }
            return .toolInput(partialJson)

        default:
            return nil
        }
    }

    private func parseMessageDelta(json: [String: Any]) -> StreamEvent? {
        guard let delta = json["delta"] as? [String: Any],
            let stopReason = delta["stop_reason"] as? String
        else { return nil }

        return .done(stopReason: StopReason(from: stopReason))
    }

    // MARK: - Message Conversion

    func convertMessages(_ messages: [ChatItem]) -> [[String: Any]] {
        messages.map { message in
            var content: [[String: Any]] = []
            for payload in message.payloads {
                switch payload {
                case .text(let text):
                    content.append(["type": "text", "text": text])
                case .textWithName(_, let text):
                    content.append(["type": "text", "text": text])
                case .imageBase64(_, let media, let image):
                    content.append(["type": "image", "source": ["type": "base64", "media_type": media, "data": image]])
                case .toolUse(let id, let name, let input):
                    content.append(["type": "tool_use", "id": id, "name": name, "input": input])
                case .toolResult(let id, _, let result):
                    content.append(["type": "tool_result", "tool_use_id": id, "content": result])
                }
            }

            let dict: [String: Any] = [
                "role": message.role.rawValue,
                "content": content,
            ]

            return dict
        }
    }

    func convertTools(_ tools: [Tool]) -> [[String: Any]] {
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

    func convertSystemMessages(_ messages: [ChatPayload]) -> [[String: Any]] {
        messages.map { payload in
            switch payload {
            case .text(let text):
                return ["type": "text", "text": text]
            default:
                return [:]
            }
        }
    }

    // MARK: - Message Building

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
