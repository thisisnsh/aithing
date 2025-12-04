//
//  OpenAIProvider.swift
//  AIThing
//
//  OpenAI Chat Completions API provider implementation.
//

import Foundation

/// Provider implementation for OpenAI's Chat Completions API.
final class OpenAIProvider: AIProviderProtocol {
    
    // MARK: - Properties
    
    let provider: AIProvider = .openai
    
    private let apiURL = "https://api.openai.com/v1/chat/completions"
    
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
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [
            "model": model,
            "stream": true,
            "max_tokens": maxTokens,
            "temperature": 0.7,
            "messages": convertMessagesWithSystem(messages, systemMessages: systemMessages)
        ]
        
        let convertedTools = convertTools(tools)
        if !convertedTools.isEmpty {
            body["tools"] = convertedTools
        }
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }
    
    // MARK: - Stream Parsing
    
    func parseStreamLine(_ line: String) -> StreamEvent? {
        guard line.starts(with: "data: ") else { return nil }
        
        let jsonString = line.replacingOccurrences(of: "data: ", with: "")
        
        // Check for stream end
        if jsonString.trimmingCharacters(in: .whitespaces) == "[DONE]" {
            return .done(stopReason: .endTurn)
        }
        
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        
        // Check for error
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return .error(message)
        }
        
        // Parse choices
        guard let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first
        else { return nil }
        
        // Check finish reason
        if let finishReason = firstChoice["finish_reason"] as? String {
            switch finishReason {
            case "stop":
                return .done(stopReason: .endTurn)
            case "length":
                return .done(stopReason: .maxTokens)
            case "tool_calls":
                return .done(stopReason: .toolUse)
            default:
                return .done(stopReason: .unknown)
            }
        }
        
        // Parse delta
        guard let delta = firstChoice["delta"] as? [String: Any] else { return nil }
        
        // Check for text content
        if let content = delta["content"] as? String {
            return .text(content)
        }
        
        // Check for tool calls
        if let toolCalls = delta["tool_calls"] as? [[String: Any]],
           let toolCall = toolCalls.first {
            return parseToolCall(toolCall)
        }
        
        return nil
    }
    
    private func parseToolCall(_ toolCall: [String: Any]) -> StreamEvent? {
        // Tool call start (has id and function name)
        if let id = toolCall["id"] as? String,
           let function = toolCall["function"] as? [String: Any],
           let name = function["name"] as? String {
            return .toolUseStart(id: id, name: name)
        }
        
        // Tool call arguments delta
        if let function = toolCall["function"] as? [String: Any],
           let arguments = function["arguments"] as? String {
            return .toolInput(arguments)
        }
        
        return nil
    }
    
    // MARK: - Message Conversion
    
    func convertMessages(_ messages: [[String: Any]]) -> [[String: Any]] {
        messages.compactMap { message -> [String: Any]? in
            guard let role = message["role"] as? String else { return nil }
            
            // Skip special internal roles
            guard role == "user" || role == "assistant" || role == "tool" else { return nil }
            
            guard let content = message["content"] else { return nil }
            
            // Handle array content (convert to OpenAI format)
            if let contentArray = content as? [[String: Any]] {
                return convertContentArray(role: role, contentArray: contentArray)
            }
            
            // Handle string content
            if let contentString = content as? String {
                return ["role": role, "content": contentString]
            }
            
            return nil
        }
    }
    
    private func convertMessagesWithSystem(
        _ messages: [[String: Any]],
        systemMessages: [[String: Any]]
    ) -> [[String: Any]] {
        var result: [[String: Any]] = []
        
        // Add system message first
        let systemText = systemMessages.compactMap { msg -> String? in
            if let content = msg["text"] as? String {
                return content
            }
            return nil
        }.joined(separator: "\n\n")
        
        if !systemText.isEmpty {
            result.append(["role": "system", "content": systemText])
        }
        
        // Add converted messages
        result.append(contentsOf: convertMessages(messages))
        
        return result
    }
    
    private func convertContentArray(role: String, contentArray: [[String: Any]]) -> [String: Any]? {
        var parts: [Any] = []
        
        for item in contentArray {
            guard let type = item["type"] as? String else { continue }
            
            switch type {
            case "text":
                if let text = item["text"] as? String {
                    parts.append(["type": "text", "text": text])
                }
                
            case "image":
                if let source = item["source"] as? [String: Any],
                   let base64 = source["data"] as? String,
                   let mediaType = source["media_type"] as? String {
                    parts.append([
                        "type": "image_url",
                        "image_url": ["url": "data:\(mediaType);base64,\(base64)"]
                    ])
                }
                
            case "tool_use":
                // OpenAI handles tool use differently in assistant messages
                if let id = item["id"] as? String,
                   let name = item["name"] as? String,
                   let input = item["input"] {
                    let inputString: String
                    if let inputDict = input as? [String: Any],
                       let jsonData = try? JSONSerialization.data(withJSONObject: inputDict),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        inputString = jsonString
                    } else {
                        inputString = "{}"
                    }
                    return [
                        "role": "assistant",
                        "tool_calls": [[
                            "id": id,
                            "type": "function",
                            "function": ["name": name, "arguments": inputString]
                        ]]
                    ]
                }
                
            case "tool_result":
                if let toolUseId = item["tool_use_id"] as? String,
                   let resultContent = item["content"] {
                    let resultString: String
                    if let resultArray = resultContent as? [[String: Any]] {
                        let texts = resultArray.compactMap { $0["text"] as? String }
                        resultString = texts.joined(separator: "\n")
                    } else if let str = resultContent as? String {
                        resultString = str
                    } else {
                        resultString = ""
                    }
                    return [
                        "role": "tool",
                        "tool_call_id": toolUseId,
                        "content": resultString
                    ]
                }
                
            default:
                continue
            }
        }
        
        // If we have parts, return appropriate message
        if parts.count == 1, let first = parts.first as? [String: Any],
           let text = first["text"] as? String {
            return ["role": role, "content": text]
        } else if !parts.isEmpty {
            return ["role": role, "content": parts]
        }
        
        return nil
    }
    
    func convertTools(_ tools: [[String: Any]]) -> [[String: Any]] {
        tools.compactMap { tool -> [String: Any]? in
            guard let name = tool["name"] as? String,
                  let description = tool["description"] as? String
            else { return nil }
            
            var function: [String: Any] = [
                "name": name,
                "description": description
            ]
            
            if let inputSchema = tool["input_schema"] as? [String: Any] {
                function["parameters"] = inputSchema
            }
            
            return [
                "type": "function",
                "function": function
            ]
        }
    }
    
    // MARK: - Message Building
    
    func buildToolResultMessage(toolUseId: String, result: [[String: Any]]) -> [String: Any] {
        let resultText = result.compactMap { $0["text"] as? String }.joined(separator: "\n")
        return [
            "role": "tool",
            "tool_call_id": toolUseId,
            "content": resultText
        ]
    }
    
    func buildAssistantToolUseMessage(
        text: String?,
        toolUseId: String,
        toolName: String,
        toolInput: Any
    ) -> [String: Any] {
        var message: [String: Any] = ["role": "assistant"]
        
        if let text = text, !text.isEmpty {
            message["content"] = text
        }
        
        let inputString: String
        if let inputDict = toolInput as? [String: Any],
           let jsonData = try? JSONSerialization.data(withJSONObject: inputDict),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            inputString = jsonString
        } else if let str = toolInput as? String {
            inputString = str
        } else {
            inputString = "{}"
        }
        
        message["tool_calls"] = [[
            "id": toolUseId,
            "type": "function",
            "function": [
                "name": toolName,
                "arguments": inputString
            ]
        ]]
        
        return message
    }
    
    func buildAssistantTextMessage(text: String) -> [String: Any] {
        ["role": "assistant", "content": text]
    }
}

