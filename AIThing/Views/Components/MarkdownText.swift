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
                .background(.gray.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .markdownMargin(top: 0, bottom: 16)
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
}
