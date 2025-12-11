//
//  OpenAIProvider.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 12/5/25.
//

import Foundation
import MCP

/// Provider implementation for OpenAI's Chat Completions API.
final class OpenAIProvider: AIProviderProtocol {

    // MARK: - Properties

    let provider: AIProvider = .openai

    private let apiURL = "https://api.openai.com/v1/chat/completions"

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
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let processedMessages = addCacheBlock(input: convertMessagesWithSystem(messages, systemMessages: systemMessages), isMessage: true)
        let processedTools = addCacheBlock(input: convertTools(tools))
        
        let body: [String: Any] = [
            "model": model,
            "stream": stream,
            "max_completion_tokens": maxTokens,
            "temperature": 1,
            "messages": processedMessages,
            "tools": processedTools,
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: - Stream Parsing

    func parseStreamLine(_ line: String) -> StreamEvent? {
        guard line.starts(with: "data: ") else { return nil }

        let jsonString = line.replacingOccurrences(of: "data: ", with: "")        

        // end of stream
        if jsonString.trimmingCharacters(in: .whitespaces) == "[DONE]" {
            return nil  // .done(stopReason: .endTurn)
        }

        guard
            let data = jsonString.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let choice = choices.first
        else { return nil }

        // finish reason
        if let finish = choice["finish_reason"] as? String {
            return parseFinishReason(finish)
        }

        // delta payload
        guard let delta = choice["delta"] as? [String: Any] else { return nil }

        return parseDelta(delta)
    }

    private func parseDelta(_ delta: [String: Any]) -> StreamEvent? {
        if let value = delta["content"], !(value is NSNull) {
            return parseDeltaText(delta: delta)
        }

        if let value = delta["tool_calls"], !(value is NSNull) {
            return parseDeltaTool(delta: delta)
        }

        // ignore delta[role]
        // ignore empty delta
        return nil
    }

    private func parseDeltaText(delta: [String: Any]) -> StreamEvent? {
        guard let text = delta["content"] as? String else { return nil }
        return .text(text)
    }

    private func parseDeltaTool(delta: [String: Any]) -> StreamEvent? {
        guard
            let calls = delta["tool_calls"] as? [[String: Any]],
            let call = calls.first,
            let function = call["function"] as? [String: Any]
        else { return nil }

        // tool use start
        if let name = function["name"] as? String,
            let id = call["id"] as? String
        {
            return .toolUseStart(id: id, name: name)
        }

        // tool arguments
        if let args = function["arguments"] as? String {
            return .toolInput(args)
        }

        return nil
    }

    private func parseFinishReason(_ finish: String) -> StreamEvent {
        return .done(stopReason: StopReason(from: finish))
    }

    // MARK: - Message Conversion

    func convertMessages(_ messages: [ChatItem]) -> [[String: Any]] {
        messages.compactMap { message in
            var content: [[String: Any]] = []
            for payload in message.payloads {
                switch payload {
                case .text(let text):
                    content.append(["type": "text", "text": text])
                case .textWithName(_, let text):
                    content.append(["type": "text", "text": text])
                case .imageBase64(_, let media, let image):
                    content.append(["type": "image_url", "image_url": ["url": "data:\(media);base64,\(image)"]])
                case .toolUse(let id, let name, let input):
                    return [
                        "role": message.role.rawValue,
                        "tool_calls": [["id": id, "type": "function", "function": ["name": name, "arguments": dictObjectToJSONString(input)]]],
                    ]
                case .toolResult(let id, _, let result):
                    return ["role": "tool", "tool_call_id": id, "content": result]
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
        tools.compactMap { tool -> [String: Any]? in
            let name = tool.name
            let description = tool.description

            var function: [String: Any] = [
                "name": name,
                "description": description,
            ]

            if let inputSchema = tool.inputSchema,
                var params = inputSchema.stringified() as? [String: Any]
            {
                if params["type"] == nil { params["type"] = "object" }
                if params["properties"] == nil { params["properties"] = [:] }

                function["parameters"] = params
            } else {
                function["parameters"] = ["type": "object", "properties": [:]]
            }

            return [
                "type": "function",
                "function": function,
            ]
        }
    }

    func convertSystemMessages(_ messages: [ChatPayload]) -> [[String: Any]] {
        // Add system message first
        let systemText = messages.compactMap { msg -> String? in
            if case .text(let text) = msg { return text }
            if case .textWithName(_, let text) = msg { return text }
            return nil
        }.joined(separator: "\n\n")

        if !systemText.isEmpty {
            return [["role": "system", "content": systemText]]
        }

        return []
    }

    private func convertMessagesWithSystem(
        _ messages: [ChatItem],
        systemMessages: [ChatPayload]
    ) -> [[String: Any]] {
        var result = convertSystemMessages(systemMessages)
        result.append(contentsOf: convertMessages(messages))
        return result
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
