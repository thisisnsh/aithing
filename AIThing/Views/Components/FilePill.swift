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
    let onDelete: (Int) -> Void

    @State private var onHover = false

    var body: some View {
        HStack {
            Text(name)
                .lineLimit(1)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.black)
                .frame(maxWidth: 100)

            Button {
                onDelete(index)
            } label: {
                Image(systemName: onHover ? "xmark.circle.fill" : "xmark.circle")
                    .resizable()
                    .frame(width: 12, height: 12)
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
            .onHover { onHover = $0 }
        }
        .padding(4)
        .padding(.horizontal, 4)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
