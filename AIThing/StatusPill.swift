//
//  StatusPill.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import SwiftUI

struct StatusPill: View {
    let text: String
    let status: McpStatus?

    var body: some View {
        HStack(spacing: 4) {
            if let status {
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundColor(status == .available ? .green : .red)
            }

            Text(text)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(BlurredBackground())
        .clipShape(Capsule())
    }
}
