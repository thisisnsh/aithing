//
//  ToastView.swift
//  AIThing
//
//  Toast notification view component.
//

import SwiftUI

extension NotchView {
    func Toast() -> some View {
        Group {
            if #available(macOS 26.0, *) {
                Text(toastText)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.yellow.opacity(0.5), lineWidth: 1)
                    }
            } else {
                Text(toastText)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.yellow.opacity(0.5), lineWidth: 1)
                    }
            }
        }
    }
}

