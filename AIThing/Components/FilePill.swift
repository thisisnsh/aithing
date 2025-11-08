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
    let systemName: String
    let big: Bool
    let onDelete: (Int) -> Void
    let cornerRadius: CGFloat

    @State private var onHover = false

    var body: some View {
        GroupView()
            .background(.white)
            .cornerRadius(image != nil && big ? cornerRadius - 8 : cornerRadius)
            .onHover { onHover = $0 }
    }

    private func GroupView() -> some View {
        Group {
            if let image = image, big {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 64)
                    .cornerRadius(cornerRadius - 8)
                    .overlay {
                        if onHover {
                            DeleteButton()
                        }
                    }
            } else {
                PillStack()
                    .padding(.horizontal, 4)
                    .padding(8)
            }
        }

    }

    private func PillStack() -> some View {
        HStack {
            Image(systemName: systemName)
                .resizable()
                .frame(width: 10, height: 10)
                .foregroundStyle(.black)

            Text(name)
                .lineLimit(1)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.black)
                .frame(maxWidth: 100)

            if onHover {
                DeleteButton()
            }
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
                .padding(.horizontal, 2)
                .background(.white)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
