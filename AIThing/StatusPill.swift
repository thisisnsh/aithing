//
//  StatusPill.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import SwiftUI

struct StatusPill: View {
    let status: McpStatus

    var isAvailable: Bool {
        status == .available
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundColor(isAvailable ? .green : .red)

            Text("MCP Server")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(BlurredBackground())
        .clipShape(Capsule())
    }
}
