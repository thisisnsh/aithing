//
//  PillView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import SwiftUI

struct PillView: View {
    var text: String
    var help: String

    var body: some View {
        if text.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 8) {
                MarkdownText(text: text)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(.white)
                    .help(help)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .overlay(
                Capsule().stroke(Color.white, lineWidth: 1.5)
            )
            .clipShape(Capsule())
        }
    }
}
