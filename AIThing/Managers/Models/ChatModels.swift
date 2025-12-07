//
//  ChatModels.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 12/5/25.
//

import AppKit
import Foundation

// MARK: - Chat Role

/// The role of a participant in a chat conversation.
enum ChatRole: String {
    /// The user's messages
    case user = "user"
    
    /// The AI assistant's messages
    case assistant = "assistant"
}

// MARK: - Chat Payload

/// The different types of content that can be included in a chat message.
enum ChatPayload: Equatable {
    /// Plain text content
    case text(text: String)
    
    /// Text content with an associated name
    case textWithName(name: String, text: String)
    
    /// Base64-encoded image with metadata
    case imageBase64(name: String, media: String, image: String)
    
    /// Tool invocation with parameters
    case toolUse(id: String, name: String, input: [String: Any])
    
    /// Result returned from a tool execution
    case toolResult(id: String, name: String, result: String)

    static func == (lhs: ChatPayload, rhs: ChatPayload) -> Bool {
        switch (lhs, rhs) {
        case (.text(let a), .text(let b)): return a == b
        case (.textWithName(_, let a), .textWithName(_, let b)): return a == b
        case (.imageBase64(_, _, let a), .imageBase64(_, _, let b)): return a == b
        case (.toolUse(let a, _, _), .toolUse(let b, _, _)): return a == b
        case (.toolResult(_, _, _), .toolResult(_, _, _)): return false
        default: return false
        }
    }

    /// Whether this payload represents text content.
    var isText: Bool {
        if case .text = self { return true }
        if case .textWithName = self { return true }
        return false
    }

    /// Whether this payload represents an image.
    var isImage: Bool {
        if case .imageBase64 = self { return true }
        return false
    }
}

// MARK: - Chat Item

/// Represents a single message in a chat conversation.
///
/// A chat item has a role (user or assistant) and one or more payloads
/// containing the actual content (text, images, tool calls, etc.).
struct ChatItem: Identifiable, Equatable {
    let id: UUID
    let role: ChatRole
    var payloads: [ChatPayload]

    /// Creates a chat item with multiple payloads.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if not provided)
    ///   - role: The message sender's role
    ///   - payloads: Array of content payloads
    init(id: UUID = UUID(), role: ChatRole, payloads: [ChatPayload]) {
        self.id = id
        self.role = role
        self.payloads = payloads
    }

    /// Creates a chat item with a single payload.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if not provided)
    ///   - role: The message sender's role
    ///   - payload: Single content payload
    init(id: UUID = UUID(), role: ChatRole, payload: ChatPayload) {
        self.id = id
        self.role = role
        self.payloads = [payload]
    }

    static func == (lhs: ChatItem, rhs: ChatItem) -> Bool {
        lhs.id == rhs.id && lhs.role == rhs.role && lhs.payloads == rhs.payloads
    }
}

extension ChatItem {
    // MARK: - Serialization

    /// Converts an array of ChatItems to an array of dictionaries for persistence.
    ///
    /// - Parameter items: The chat items to serialize
    /// - Returns: Array of dictionaries representing the chat items
    static func toDictionaries(_ items: [ChatItem]) -> [[String: Any]] {
        return items.map { item in
            let dict: [String: Any] = [
                "id": item.id.uuidString,
                "role": item.role == .user ? "user" : "assistant",
                "payloads": item.payloads.map { payload in
                    payloadToDictionary(payload)
                },
            ]
            return dict
        }
    }

    /// Converts an array of dictionaries back to ChatItems from persistence.
    ///
    /// - Parameter dicts: The dictionaries to deserialize
    /// - Returns: Array of reconstructed chat items
    static func fromDictionaries(_ dicts: [[String: Any]]) -> [ChatItem] {
        var items: [ChatItem] = []

        for dict in dicts {
            let idString = dict["id"] as? String ?? ""  // Backward compatibility
            let id = UUID(uuidString: idString) ?? UUID()

            let roleString = dict["role"] as? String
            if roleString != "user" && roleString != "assistant" { continue }
            let role: ChatRole = roleString == "user" ? .user : .assistant

            var payloads: [ChatPayload] = []

            if let payloadDicts = dict["payloads"] as? [[String: Any]] {
                for payloadDict in payloadDicts {
                    guard let payload = dictionaryToPayload(payloadDict) else {
                        continue
                    }
                    payloads.append(payload)
                }
            }

            // Backward Compatibility: History stored before ChatItem was used in History
            if let contentDicts = dict["content"] as? [[String: Any]] {
                for payloadDict in contentDicts {
                    guard let payload = backwardDictionaryToPayload(payloadDict) else {
                        continue
                    }
                    payloads.append(payload)
                }
            }

            items.append(ChatItem(id: id, role: role, payloads: payloads))
        }

        return items
    }

    // MARK: - Private Helpers

    private static func payloadToDictionary(_ payload: ChatPayload) -> [String: Any] {
        switch payload {
        case .text(let text):
            return [
                "type": "text",
                "text": text,
            ]

        case .textWithName(let name, let text):
            return [
                "type": "textWithName",
                "name": name,
                "text": text,
            ]

        case .imageBase64(let name, let media, let image):
            return [
                "type": "imageBase64",
                "name": name,
                "media": media,
                "image": image,
            ]

        case .toolUse(let id, let name, let input):
            return [
                "type": "toolUse",
                "id": id,
                "name": name,
                "input": input,
            ]

        case .toolResult(let id, let name, let result):
            return [
                "type": "toolResult",
                "id": id,
                "name": name, 
                "result": result,
            ]
        }
    }

    private static func dictionaryToPayload(_ dict: [String: Any]) -> ChatPayload? {
        guard let type = dict["type"] as? String else { return nil }

        switch type {
        case "text":
            guard let text = dict["text"] as? String else { return nil }
            return .text(text: text)

        case "textWithName":
            guard let name = dict["name"] as? String,
                let text = dict["text"] as? String
            else { return nil }
            return .textWithName(name: name, text: text)

        case "imageBase64":
            guard let name = dict["name"] as? String,
                let media = dict["media"] as? String,
                let image = dict["image"] as? String
            else { return nil }
            return .imageBase64(name: name, media: media, image: image)

        case "toolUse":
            guard let id = dict["id"] as? String,
                let name = dict["name"] as? String,
                let input = dict["input"] as? [String: Any]
            else { return nil }
            return .toolUse(id: id, name: name, input: input)

        case "toolResult":
            guard let id = dict["id"] as? String,
                let name = dict["name"] as? String,
                let result = dict["result"] as? String
            else { return nil }
            return .toolResult(id: id, name: name, result: result)

        default:
            return nil
        }
    }

    private static func backwardDictionaryToPayload(_ dict: [String: Any]) -> ChatPayload? {
        guard let type = dict["type"] as? String else { return nil }

        switch type {
        case "text":
            guard let text = dict["text"] as? String else { return nil }
            return .text(text: text)

        case "image":
            guard let source = dict["source"] as? [String: Any] else { return nil }
            guard let media = source["media_type"] as? String,
                let image = source["data"] as? String
            else { return nil }
            return .imageBase64(name: "", media: media, image: image)

        case "tool_use":
            guard let id = dict["id"] as? String,
                let name = dict["name"] as? String,
                let input = dict["input"] as? [String: Any]
            else { return nil }
            return .toolUse(id: id, name: name, input: input)

        case "tool_result":
            guard let id = dict["tool_use_id"] as? String,
                let content = dict["content"] as? [String: Any]
            else { return nil }
            guard let result = content["text"] as? String else { return nil }
            return .toolResult(id: id, name: "", result: result)

        default:
            return nil
        }
    }
}
