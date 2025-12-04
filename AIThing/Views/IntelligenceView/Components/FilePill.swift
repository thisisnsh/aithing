//
//  FilePill.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 11/1/25.
//

import SwiftUI

struct FilePill: View {
    // MARK: - Constants & Closures
    let index: Int
    let name: String
    let image: NSImage?
    let systemName: String
    let big: Bool
    let onDelete: (Int) -> Void
    let cornerRadius: CGFloat

    // MARK: - State
    @State var onHover = false

    // MARK: - Body
    var body: some View {
        HStack(alignment: .bottom) {
            Image(systemName: systemName)
                .resizable()
                .frame(width: 12, height: 12)
                .foregroundStyle(.black)
                .padding(.leading, 4)
                .padding(.top, -2)

            Text(name)
                .lineLimit(1)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.black)
                .frame(maxWidth: 164)

            DeleteButton()
        }
        .padding(.trailing, 4)
        .padding(8)
        .background(.white)
        .cornerRadius(cornerRadius)
        .onHover { onHover = $0 }
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

