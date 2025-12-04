//
//  ExtraBubble.swift
//  AIThing
//
//  Extra bubble component for displaying tool calls and other messages.
//

import SwiftUI

struct ExtraBubble: View {
    // MARK: - Constants
    let text: String

    // MARK: - Body
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .textSelection(.enabled)
            .padding(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
            )
            .padding(.leading, 8)
    }
}

