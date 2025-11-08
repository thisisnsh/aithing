//
//  FilePill.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 11/1/25.
//

import SwiftUI

struct FilePill: View {
    let index: Int
    let name: String
    let image: NSImage?
    let big: Bool
    let onDelete: (Int) -> Void

    @State private var onHover = false

    var body: some View {
        GroupView()
            .background(.white)
            .cornerRadius(6)
            .onHover { onHover = $0 }
    }

    private func GroupView() -> some View {
        Group {
            if let image = image, big {
                VStack {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 48)
                        .cornerRadius(6)
                        .overlay {
                            if onHover {
                                DeleteButton()
                            }
                        }
                }
            } else {
                PillStack()
                    .padding(.horizontal, 4)
            }
        }
        .padding(4)

    }

    private func PillStack() -> some View {
        HStack {
            Text(name)
                .lineLimit(1)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.black)
                .frame(maxWidth: 100)

            DeleteButton()
        }
    }

    private func DeleteButton() -> some View {
        Button {
            onDelete(index)
        } label: {
            Image(systemName: onHover ? "xmark.circle.fill" : "xmark.circle")
                .resizable()
                .frame(width: 12, height: 12)
                .foregroundStyle(.black)
                .padding(2)
                .background(.white)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
