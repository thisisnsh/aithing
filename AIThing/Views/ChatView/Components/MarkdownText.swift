//
//  MarkdownText.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/13/25.
//

import AppKit
import MarkdownUI
import SwiftUI

struct MarkdownText: View {
    var text: String
    var noBackground = false

    @State var copiedBlock: String? = nil
    @State var codeHover = false

    var body: some View {
        Markdown(text)
            .textSelection(.enabled)
            .markdownBlockStyle(\.blockquote) { configuration in
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 8)
                        .background(.gray.opacity(0.25))
                        .relativeFrame(width: .em(0.2))
                    configuration.label
                        .markdownTextStyle {
                            FontFamilyVariant(.monospaced)
                            FontSize(.em(1))
                        }
                        .relativePadding(.horizontal, length: .em(1))
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .markdownBlockStyle(\.codeBlock) { configuration in
                ZStack(alignment: .topTrailing) {
                    ScrollView(.horizontal) {
                        configuration.label
                            .fixedSize(horizontal: false, vertical: true)
                            .relativeLineSpacing(.em(0.225))
                            .markdownTextStyle {
                                FontFamilyVariant(.monospaced)
                                FontSize(.em(1))
                            }
                            .padding(16)
                    }
                    .background(noBackground ? .clear : .gray.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .markdownMargin(top: 0, bottom: 16)

                    if codeHover {
                        Button(action: {
                            copyToClipboard(configuration.content)
                            copiedBlock = configuration.content
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                copiedBlock = nil
                            }
                        }) {
                            Label(
                                copiedBlock == configuration.content ? "Copied!" : "Copy",
                                systemImage: "doc.on.doc"
                            )
                            .labelStyle(.titleAndIcon)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                    }
                }
                .onHover { hover in
                    codeHover = hover
                }
            }
            .markdownTextStyle(\.code) {
                FontFamilyVariant(.monospaced)
                FontSize(.em(1))
                BackgroundColor(.gray.opacity(0.25))
            }
            .markdownTextStyle(\.text) {
                FontSize(.em(1))
            }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

