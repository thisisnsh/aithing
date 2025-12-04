//
//  LogoShape.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/26/25.
//

import SwiftUI

struct LogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Scale factor for adapting the original 1024x1024 viewBox
        let scaleX = rect.width / 1024
        let scaleY = rect.height / 1024

        // Triangle Polygon: points="143 711 363.51 294.99 585 711 143 711"
        path.move(to: CGPoint(x: 143 * scaleX, y: 711 * scaleY))
        path.addLine(to: CGPoint(x: 363.51 * scaleX, y: 294.99 * scaleY))
        path.addLine(to: CGPoint(x: 585 * scaleX, y: 711 * scaleY))
        path.addLine(to: CGPoint(x: 143 * scaleX, y: 711 * scaleY))
        path.closeSubpath()

        // Rectangle at x=626 y=298 width=97 height=413
        path.addRect(
            CGRect(
                x: 626 * scaleX,
                y: 298 * scaleY,
                width: 97 * scaleX,
                height: 413 * scaleY
            )
        )

        // Small rectangle at x=785 y=298 width=97 height=97
        path.addRect(
            CGRect(
                x: 785 * scaleX,
                y: 298 * scaleY,
                width: 97 * scaleX,
                height: 97 * scaleY
            )
        )

        // Circle-like shape (path element)
        // SVG path: "M512.79,294.3c59.81-5,73.55,84.04,15.05,97.04-69.07,15.35-84.22-91.26-15.05-97.04Z"
        path.move(to: CGPoint(x: 512.79 * scaleX, y: 294.3 * scaleY))
        path.addCurve(
            to: CGPoint(x: (512.79 + 15.05) * scaleX, y: (294.3 + 97.04) * scaleY),
            control1: CGPoint(x: (512.79 + 59.81) * scaleX, y: (294.3 - 5) * scaleY),
            control2: CGPoint(x: (512.79 + 73.55) * scaleX, y: (294.3 + 84.04) * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 512.79 * scaleX, y: 294.3 * scaleY),
            control1: CGPoint(
                x: (512.79 + 15.05 - 69.07) * scaleX,
                y: (294.3 + 97.04 + 15.35) * scaleY
            ),
            control2: CGPoint(x: (512.79 - 84.22) * scaleX, y: (294.3 + 97.04 - 91.26) * scaleY)
        )
        path.closeSubpath()

        return path
    }
}

