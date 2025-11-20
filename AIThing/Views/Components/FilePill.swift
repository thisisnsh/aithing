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
        Group {
            if let image = image, big {
                ZStack {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 64)
                        .cornerRadius(cornerRadius - 8)

                    DeleteButton(width: 24)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius - 8, style: .continuous)
                        .stroke(Color.white, lineWidth: 2)
                }
            } else {
                HStack {
                    Image(systemName: systemName)
                        .resizable()
                        .frame(width: 10, height: 10)
                        .foregroundStyle(.black)
                        .padding(.leading, 4)

                    Text(name)
                        .lineLimit(1)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.black)
                        .frame(maxWidth: 100)

                    DeleteButton()
                }
                .padding(4)
                .padding(8)
                .background(.white)
                .cornerRadius(cornerRadius)
            }
        }
        .onHover { onHover = $0 }
    }

    private func DeleteButton(width: CGFloat = 12) -> some View {
        Button {
            onDelete(index)
        } label: {
            Image(systemName: onHover ? "xmark.circle.fill" : "xmark.circle")
                .resizable()
                .frame(width: width, height: width)
                .foregroundStyle(.black)
                .padding(.horizontal, 2)
                .background(.white)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
