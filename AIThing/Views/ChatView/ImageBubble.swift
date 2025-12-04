//
//  ImageBubble.swift
//  AIThing
//
//  Image bubble component for displaying image messages.
//

import AppKit
import SwiftUI

struct ImageBubble: View {
    // MARK: - Constants
    let image: [NSImage]
    let isUser: Bool

    // MARK: - State
    @State private var index = 0

    // MARK: - Body
    var body: some View {
        ZStack {
            if image.count > 2 {
                ImageView(image: image[(index + 2) % image.count])
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .scaleEffect(0.6, anchor: .trailing)
                    .offset(x: -160)

            }

            if image.count > 1 {
                ImageView(image: image[(index + 1) % image.count])
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .scaleEffect(0.8, anchor: .trailing)
                    .offset(x: -80)
            }

            ImageView(image: image[index % image.count])
                .frame(maxWidth: .infinity, alignment: .trailing)
                .scaleEffect(1, anchor: .trailing)
                .onTapGesture {
                    index = (index + 1) % image.count
                }
        }
    }

    private func ImageView(image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isUser
                            ? Color.gray.opacity(0.1) : Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.gray.opacity(0.5), lineWidth: isUser ? 0 : 1)
            )
    }
}

