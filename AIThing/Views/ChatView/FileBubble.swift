//
//  FileBubble.swift
//  AIThing
//
//  File bubble component for displaying file attachments.
//

import SwiftUI

struct FileBubble: View {
    let file: String
    let content: String

    @State private var showContent = false

    var body: some View {
        if showContent {
            MarkdownText(text: content)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .textSelection(.enabled)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
                .padding(.leading, 32)
        } else {
            HStack {
                Text("\(file)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .textSelection(.enabled)

                if !content.isEmpty {
                    Image(systemName: "chevron.down")
                        .frame(width: 10, height: 10)
                }
            }
            .padding(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
            )
            .padding(.leading, 32)
            .onTapGesture {
                if !content.isEmpty {
                    showContent = true
                }
            }
        }

    }
}

