//
//  ToolBubble.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/15/25.
//

import SwiftUI

struct ToolBubble: View {
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

