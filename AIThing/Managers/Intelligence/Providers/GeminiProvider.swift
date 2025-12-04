//
//  GeminiProvider.swift
//  AIThing
//
//  Google Gemini API provider implementation.
//

import Foundation

/// Provider implementation for Google's Gemini API.
final class GeminiProvider: AIProviderProtocol {
    
    // MARK: - Properties
    
    let provider: AIProvider = .gemini
    
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    
    // MARK: - Request Building
    
    func buildRequest(
        apiKey: String,
        model: String,
        messages: [[String: Any]],
        tools: [[String: Any]],
        systemMessages: [[String: Any]],
        maxTokens: Int
    ) -> URLRequest? {
        let urlString = "\(baseURL)/\(model):streamGenerateContent?alt=sse&key=\(apiKey)"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "contents": convertMessages(messages),
            "generationConfig": [
                "maxOutputTokens": maxTokens,
                "temperature": 0.7
            ]
        ]
        
        // Add system instruction
        let systemText = systemMessages.compactMap { $0["text"] as? String }.joined(separator: "\n\n")
        if !systemText.isEmpty {
            body["systemInstruction"] = ["parts": [["text": systemText]]]
        }
        
        // Add tools
        let convertedTools = convertTools(tools)
        if !convertedTools.isEmpty {
            body["tools"] = [["functionDeclarations": convertedTools]]
        }
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }
    
    // MARK: - Stream Parsing
    
    func parseStreamLine(_ line: String) -> StreamEvent? {
        guard line.starts(with: "data: ") else { return nil }
        
        let jsonString = line.replacingOccurrences(of: "data: ", with: "")
        
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        
        // Check for error
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return .error(message)
        }
        
        // Parse candidates
        guard let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first
        else { return nil }
        
        // Check finish reason
        if let finishReason = firstCandidate["finishReason"] as? String {
            switch finishReason {
            case "STOP":
                return .done(stopReason: .endTurn)
            case "MAX_TOKENS":
                return .done(stopReason: .maxTokens)
            case "SAFETY", "RECITATION", "OTHER":
                return .done(stopReason: .unknown)
            default:
                break
            }
        }
        
        // Parse content
        guard let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]]
        else { return nil }
        
        for part in parts {
            // Text content
            if let text = part["text"] as? String {
                return .text(text)
            }
            
            // Function call
            if let functionCall = part["functionCall"] as? [String: Any],
               let name = functionCall["name"] as? String {
                let args = functionCall["args"] as? [String: Any] ?? [:]
                let argsString: String
                if let jsonData = try? JSONSerialization.data(withJSONObject: args),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    argsString = jsonString
                } else {
                    argsString = "{}"
                }
                // Gemini doesn't provide tool IDs, generate one
                let toolId = "call_\(UUID().uuidString.prefix(8))"
                return .toolUseStart(id: toolId, name: name)
            }
        }
        
        return nil
    }
    
    // MARK: - Message Conversion
    
    func convertMessages(_ messages: [[String: Any]]) -> [[String: Any]] {
        messages.compactMap { message -> [String: Any]? in
            guard let role = message["role"] as? String else { return nil }
            
            // Map roles to Gemini format
            let geminiRole: String
            switch role {
            case "user":
                geminiRole = "user"
            case "assistant":
                geminiRole = "model"
            default:
                return nil
            }
            
            guard let content = message["content"] else { return nil }
            
            // Handle array content
            if let contentArray = content as? [[String: Any]] {
                let parts = convertContentArrayToParts(contentArray)
                if !parts.isEmpty {
                    return ["role": geminiRole, "parts": parts]
                }
            }
            
            // Handle string content
            if let contentString = content as? String {
                return ["role": geminiRole, "parts": [["text": contentString]]]
            }
            
            return nil
        }
    }
    
    private func convertContentArrayToParts(_ contentArray: [[String: Any]]) -> [[String: Any]] {
        var parts: [[String: Any]] = []
        
        for item in contentArray {
            guard let type = item["type"] as? String else { continue }
            
            switch type {
            case "text":
                if let text = item["text"] as? String {
                    parts.append(["text": text])
                }
                
            case "image":
                if let source = item["source"] as? [String: Any],
                   let base64 = source["data"] as? String,
                   let mediaType = source["media_type"] as? String {
                    parts.append([
                        "inlineData": [
                            "mimeType": mediaType,
                            "data": base64
                        ]
                    ])
                }
                
            case "tool_use":
                if let name = item["name"] as? String,
                   let input = item["input"] as? [String: Any] {
                    parts.append([
                        "functionCall": [
                            "name": name,
                            "args": input
                        ]
                    ])
                }
                
            case "tool_result":
                if let resultContent = item["content"] as? [[String: Any]] {
                    let resultText = resultContent.compactMap { $0["text"] as? String }.joined(separator: "\n")
                    parts.append([
                        "functionResponse": [
                            "name": "tool",
                            "response": ["result": resultText]
                        ]
                    ])
                }
                
            default:
                continue
            }
        }
        
        return parts
    }
    
    func convertTools(_ tools: [[String: Any]]) -> [[String: Any]] {
        tools.compactMap { tool -> [String: Any]? in
            guard let name = tool["name"] as? String,
                  let description = tool["description"] as? String
            else { return nil }
            
            var functionDeclaration: [String: Any] = [
                "name": name,
                "description": description
            ]
            
            if let inputSchema = tool["input_schema"] as? [String: Any] {
                functionDeclaration["parameters"] = inputSchema
            }
            
            return functionDeclaration
        }
    }
    
    // MARK: - Message Building
    
    func buildToolResultMessage(toolUseId: String, result: [[String: Any]]) -> [String: Any] {
        let resultText = result.compactMap { $0["text"] as? String }.joined(separator: "\n")
        return [
            "role": "user",
            "parts": [[
                "functionResponse": [
                    "name": "tool",
                    "response": ["result": resultText]
                ]
            ]]
        ]
    }
    
    func buildAssistantToolUseMessage(
        text: String?,
        toolUseId: String,
        toolName: String,
        toolInput: Any
    ) -> [String: Any] {
        var parts: [[String: Any]] = []
        
        if let text = text, !text.isEmpty {
            parts.append(["text": text])
        }
        
        let args: [String: Any]
        if let inputDict = toolInput as? [String: Any] {
            args = inputDict
        } else if let inputString = toolInput as? String,
                  let data = inputString.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            args = parsed
        } else {
            args = [:]
        }
        
        parts.append([
            "functionCall": [
                "name": toolName,
                "args": args
            ]
        ])
        
        return ["role": "model", "parts": parts]
    }
    
    func buildAssistantTextMessage(text: String) -> [String: Any] {
        ["role": "model", "parts": [["text": text]]]
    }
}

