//
//  ChatModels.swift
//  AIThing
//
//  Models for chat functionality.
//

import AppKit
import Foundation

enum ChatRole {
    case user
    case assistant
}

enum ChatPayload: Equatable {
    case text(content: String)
    case textWithName(name: String, content: String)
    case imageBase64(name: String, media: String, image: String)
    case imageNSImage(name: String, media: String, image: NSImage)
    case toolUse(id: String, name: String, input: Any)
    case toolResult(id: String, result: String)

    static func == (lhs: ChatPayload, rhs: ChatPayload) -> Bool {
        switch (lhs, rhs) {
        case (.text(let a), .text(let b)): return a == b
        case (.textWithName(_, let a), .textWithName(_, let b)): return a == b
        case (.toolUse(let a, _, _), .toolUse(let b, _, _)): return a == b
        case (.imageBase64(_, _, let a), .imageBase64(_, _, let b)): return a == b
        case (.imageNSImage(_, _, _), .imageBase64(_, _, _)): return false  // NSImage not Equatable; treat as unequal
        case (.toolResult(_, _), .toolResult(_, _)): return false
        default: return false
        }
    }

    var isText: Bool {
        if case .text = self { return true }
        return false
    }
}

struct ChatItem: Identifiable, Equatable {
    let id: UUID
    let role: ChatRole
    var payload: [ChatPayload]

    init(id: UUID = UUID(), role: ChatRole, payload: [ChatPayload]) {
        self.id = id
        self.role = role
        self.payload = payload
    }

    static func == (lhs: ChatItem, rhs: ChatItem) -> Bool {
        lhs.id == rhs.id && lhs.role == rhs.role && lhs.payload == rhs.payload
    }
}
