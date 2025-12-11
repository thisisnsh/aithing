//
//  ToastView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 10/31/25.
//

import SwiftUI

extension NotchView {
    func Toast() -> some View {
        Text(toastText)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassBackground(cornerRadius: 8, style: .regular)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.yellow.opacity(0.5), lineWidth: 1)
            }
    }
}

