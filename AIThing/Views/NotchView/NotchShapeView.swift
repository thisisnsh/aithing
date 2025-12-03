//
//  NotchShapeView.swift
//  AIThing
//
//  Helper view for the notch shape with glass effect.
//

import SwiftUI

extension NotchView {
    func NotchShapeExt() -> some View {
        Group {
            if #available(macOS 26.0, *) {
                NotchShape(
                    width: width,
                    height: height,
                    cornerRadiusLeft: showChatWindow ? cornerRadiusLeft : 16,
                    cornerRadiusRight: 16,
                    circularNotch: circularNotch
                )
                .stroke(Color.gray.opacity(0.5), lineWidth: circularNotch ? 0 : 1)
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(showChatWindow ? 0.3 : 1.0),
                            Color.black.opacity(1.0),
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(
                        NotchShape(
                            width: width,
                            height: height,
                            cornerRadiusLeft: showChatWindow ? cornerRadiusLeft : 16,
                            cornerRadiusRight: 16,
                            circularNotch: circularNotch
                        )
                    )
                )
                .glassEffect(
                    .regular.tint(.black),
                    in: NotchShape(
                        width: width,
                        height: height,
                        cornerRadiusLeft: showChatWindow ? cornerRadiusLeft : 16,
                        cornerRadiusRight: 16,
                        circularNotch: circularNotch
                    )
                )
            } else {
                NotchShape(
                    width: width,
                    height: height,
                    cornerRadiusLeft: showChatWindow ? cornerRadiusLeft : 16,
                    cornerRadiusRight: 16,
                    circularNotch: circularNotch
                )
                .fill(.ultraThickMaterial)
                .shadow(color: .gray.opacity(0.5), radius: circularNotch ? 0 : 1)
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(showChatWindow ? 0.3 : 1.0),
                            Color.black.opacity(1.0),
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .blendMode(.overlay)
                    .clipShape(
                        NotchShape(
                            width: width,
                            height: height,
                            cornerRadiusLeft: showChatWindow ? cornerRadiusLeft : 16,
                            cornerRadiusRight: 16,
                            circularNotch: circularNotch
                        )
                    )
                )
            }
        }
    }
}

