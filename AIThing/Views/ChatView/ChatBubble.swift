//
//  ChatBubble.swift
//  AIThing
//
//  Chat bubble component for displaying messages.
//

import AppKit
import SwiftUI

struct ChatBubble: View, Equatable {
    // MARK: - Constants
    let item: ChatItem

    // MARK: - Equatable
    static func == (lhs: ChatBubble, rhs: ChatBubble) -> Bool {
        lhs.item == rhs.item
    }

    // MARK: - Body
    var body: some View {
        HStack {
            if item.role == .assistant { Spacer().frame(width: 0) }
            if item.role == .usage { Spacer().frame(width: 0) }

            switch item.payload {
            case .file(let name, _, let content):
                FileBubble(file: name, content: content)
                    .frame(maxWidth: 800, alignment: item.role == .file ? .trailing : .leading)
            case .text(let text):
                if item.role != .usage {
                    TextBubble(text: text, isUser: item.role == .user)
                        .frame(maxWidth: 800, alignment: item.role == .user ? .trailing : .leading)
                }
            case .image(let image):
                ImageBubble(image: image, isUser: item.role == .user)
                    .frame(maxWidth: 300, alignment: item.role == .user ? .trailing : .leading)
            case .toolUse(let name):
                ExtraBubble(text: "Called tool: \(name)")
                    .frame(maxWidth: 800, alignment: .leading)
            }

            if item.role == .file { Spacer().frame(width: 0) }
            if item.role == .user { Spacer().frame(width: 0) }
        }
        .frame(maxWidth: .infinity, alignment: item.role == .user ? .trailing : .leading)
    }
}

