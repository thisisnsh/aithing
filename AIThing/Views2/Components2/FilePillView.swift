//
//  FilePillView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 11/1/25.
//

import SwiftUI

struct FilePillView: View {
    let index: Int
    let name: String
    let onDelete: (Int) -> Void

    var body: some View {
        HStack {
            Text(name)
                .lineLimit(1)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.black)

            Button {
                onDelete(index)
            } label: {
                Image(systemName: "xmark.circle")
                    .resizable()
                    .frame(width: 12, height: 12)
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
        }
        .padding(4)
        .padding(.horizontal, 4)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
