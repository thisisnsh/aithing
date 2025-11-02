//
//  AnimatedGradientBorder.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import SwiftUI

struct AnimatedGradientBorder: View {
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    var color: Color = .white

    @State private var animate = false

    var body: some View {
        GeometryReader { geometry in
            let _ = geometry.size

            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            color,
                            color.opacity(0.4),
                            color.opacity(0.05),
                            color.opacity(0.4),
                            color,
                        ]),
                        center: .center,
                        angle: .degrees(animate ? 360 : 0)
                    ),
                    lineWidth: lineWidth
                )
                .animation(
                    .linear(duration: 3).repeatForever(autoreverses: false),
                    value: animate
                )
                .onAppear {
                    animate = true
                }
        }
    }
}
