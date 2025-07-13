//
//  StatusPill.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import SwiftUI

struct StatusPill: View {
    var text: String
    var help: String
    var status: McpStatus?
    var showAnimation: Bool = false

    @State private var showWhiteBackground = true

    var body: some View {
        HStack(spacing: 4) {
            if let status {
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundColor(status == .available ? .green : .red)
            }

            Text(text)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(showWhiteBackground ? .black : .white)
                .help(help)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Group {
                if showWhiteBackground {
                    BlurredBackground(isDark: false)
                } else {
                    BlurredBackground()
                }
            }
        )
        .clipShape(Capsule())
        .onAppear {
            if showAnimation {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showWhiteBackground = false
                    }
                }
            } else {
                showWhiteBackground = false
            }
        }
    }
}
