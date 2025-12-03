//
//  TextBubble.swift
//  AIThing
//
//  Text bubble component for displaying text messages.
//

import SwiftUI

struct TextBubble: View {
    let text: String
    let isUser: Bool

    var body: some View {
        MarkdownText(text: text)
            .font(.system(size: 12, weight: .medium))
            .textSelection(.enabled)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isUser ? Color.gray.opacity(0.1) : Color.clear)
            )
            .padding(.leading, isUser ? 32 : 0)
            .padding(.trailing, isUser ? 0 : 32)
    }
}

