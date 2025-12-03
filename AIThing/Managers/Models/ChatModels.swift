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
    case usage
    case file
}

enum ChatPayload: Equatable {
    case text(String)
    case image([NSImage])
    case toolUse(name: String)
    case file(text: String, skipNextMessages: Bool, content: String)

    static func == (lhs: ChatPayload, rhs: ChatPayload) -> Bool {
        switch (lhs, rhs) {
        case (.text(let a), .text(let b)): return a == b
        case (.toolUse(let a), .toolUse(let b)): return a == b
        case (.file(let a, _, _), .file(let b, _, _)): return a == b
        case (.image, .image): return false  // NSImage not Equatable; treat as unequal
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
    var payload: ChatPayload

    init(id: UUID = UUID(), role: ChatRole, payload: ChatPayload) {
        self.id = id
        self.role = role
        self.payload = payload
    }

    static func == (lhs: ChatItem, rhs: ChatItem) -> Bool {
        lhs.id == rhs.id && lhs.role == rhs.role && lhs.payload == rhs.payload
    }
}

