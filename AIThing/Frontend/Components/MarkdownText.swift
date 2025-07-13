//
//  MarkdownText.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/13/25.
//

import SwiftUI
import MarkdownUI

struct MarkdownText: View {
    var body: some View {
        Markdown(aiResponseError.isEmpty ? aiResponse : aiResponseError)
            .markdownTextStyle(\.blockquote) {
                FontFamilyVariant(.monospaced)
                ForegroundColor(.yellow)
                BackgroundColor(.gray.opacity(0.25))
            }
            .markdownTextStyle(\.codeBlock) {
                FontFamilyVariant(.monospaced)
                ForegroundColor(.red)
                BackgroundColor(.gray.opacity(0.25))
            }
            .markdownTextStyle(\.code) {
                FontFamilyVariant(.monospaced)
                ForegroundColor(.white)
                BackgroundColor(.gray.opacity(0.25))
            }
    }
}

#Preview {
    MarkdownText()
}
