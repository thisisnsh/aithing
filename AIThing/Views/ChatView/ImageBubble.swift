//
//  ImageBubble.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/15/25.
//

import AppKit
import SwiftUI

struct ImageBubble: View {
    // MARK: - Constants
    let payloads: [ChatPayload]
    let isUser: Bool

    // MARK: - State
    @State var index = 0
    @State var images: [NSImage] = []

    // MARK: - Body
    var body: some View {
        ZStack {
            if images.count > 2 {
                ImageView(image: images[(index + 2) % images.count])
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .scaleEffect(0.6, anchor: .trailing)
                    .offset(x: -160)

            }

            if images.count > 1 {
                ImageView(image: images[(index + 1) % images.count])
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .scaleEffect(0.8, anchor: .trailing)
                    .offset(x: -80)
            }

            if images.count > 0 {
                ImageView(image: images[index % images.count])
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .scaleEffect(1, anchor: .trailing)
                    .onTapGesture {
                        index = (index + 1) % images.count
                    }
            }
        }
        .onAppear {
            for payload in payloads {
                if case .imageBase64(_, _, let image) = payload {
                    if let nsImage = base64ToNSImage(image) {
                        images.append(nsImage)
                    }
                }
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
