//
//  AnthropicProvider.swift
//  AIThing
//
//  Anthropic Claude API provider implementation.
//

import Foundation

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
        messages: [[String: Any]],
        tools: [[String: Any]],
        systemMessages: [[String: Any]],
        maxTokens: Int
    ) -> URLRequest? {
        guard let url = URL(string: apiURL) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("extended-cache-ttl-2025-04-11", forHTTPHeaderField: "anthropic-beta")
        
        let body: [String: Any] = [
            "model": model,
            "stream": true,
            "max_tokens": maxTokens,
            "temperature": 0.7,
            "messages": convertMessages(messages),
            "tools": convertTools(tools),
            "system": systemMessages
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
            return .contentBlockStop
            
        case "message_delta":
            return parseMessageDelta(json: json)
            
        case "error":
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
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
    
    func convertMessages(_ messages: [[String: Any]]) -> [[String: Any]] {
        // Anthropic uses the same format internally, just filter out special roles
        messages.filter { message in
            guard let role = message["role"] as? String else { return false }
            return role == "user" || role == "assistant"
        }
    }
    
    func convertTools(_ tools: [[String: Any]]) -> [[String: Any]] {
        // Anthropic tools format is already compatible
        tools
    }
    
    // MARK: - Message Building
    
    func buildToolResultMessage(toolUseId: String, result: [[String: Any]]) -> [String: Any] {
        [
            "role": "user",
            "content": [[
                "type": "tool_result",
                "tool_use_id": toolUseId,
                "content": result
            ]]
        ]
    }
    
    func buildAssistantToolUseMessage(
        text: String?,
        toolUseId: String,
        toolName: String,
        toolInput: Any
    ) -> [String: Any] {
        var content: [[String: Any]] = []
        
        if let text = text, !text.isEmpty {
            content.append(["type": "text", "text": text])
        }
        
        content.append([
            "type": "tool_use",
            "id": toolUseId,
            "name": toolName,
            "input": toolInput
        ])
        
        return ["role": "assistant", "content": content]
    }
    
    func buildAssistantTextMessage(text: String) -> [String: Any] {
        [
            "role": "assistant",
            "content": [["type": "text", "text": text]]
        ]
    }
}

