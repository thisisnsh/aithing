//
//  NotchShapeView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 10/31/25.
//

import SwiftUI

extension NotchView {
    /// Creates the current notch shape with the appropriate corner radii
    private var currentNotchShape: NotchShape {
        NotchShape(
            width: width,
            height: height,
            cornerRadiusLeft: isExpanded ? cornerRadiusLeft : 16,
            cornerRadiusRight: 16,
            circularNotch: circularNotch
        )
    }

    /// Creates the gradient overlay for the notch
    private var notchGradientOverlay: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.black.opacity(isExpanded ? 0.3 : 1.0),
                Color.black.opacity(1.0),
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .clipShape(currentNotchShape)
    }

    func NotchShapeExt() -> some View {
        Group {
            if #available(macOS 26.0, *) {
                currentNotchShape
                    .stroke(Color.gray.opacity(0.5), lineWidth: circularNotch ? 0 : 1)
                    .overlay(notchGradientOverlay)
                    .glassEffect(.regular.tint(.black), in: currentNotchShape)
            } else {
                currentNotchShape
                    .fill(.ultraThickMaterial)
                    .shadow(color: .gray.opacity(0.5), radius: circularNotch ? 0 : 1)
                    .overlay(notchGradientOverlay.blendMode(.overlay))
            }
        }
    }
}
