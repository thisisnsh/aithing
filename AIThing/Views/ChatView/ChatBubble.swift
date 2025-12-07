//
//  ChatBubble.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/15/25.
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

            // It is guaranteed that all payloads will have same type
            switch item.payloads.first! {
            case .text(let text):
                TextBubble(text: text, isUser: item.role == .user)
                    .frame(maxWidth: 800, alignment: item.role == .user ? .trailing : .leading)
            case .textWithName(let name, let text):
                FileBubble(file: name, content: text)
                    .frame(maxWidth: 800, alignment: item.role == .user ? .trailing : .leading)
            case .imageBase64(_, _, _):
                ImageBubble(payloads: item.payloads, isUser: item.role == .user)
                    .frame(maxWidth: 300, alignment: item.role == .user ? .trailing : .leading)
            case .toolUse(_, let name, let input):
                ToolBubble(text: "Called tool: \(name)\nInput: \(input)")
                    .frame(maxWidth: 800, alignment: .leading)
            case .toolResult(_, _, _):
                // Ignored. This will never be displayed
                Color.clear.frame(width: 0, height: 0)
            }

            if item.role == .user { Spacer().frame(width: 0) }
        }
        .frame(maxWidth: .infinity, alignment: item.role == .user ? .trailing : .leading)
    }
}
