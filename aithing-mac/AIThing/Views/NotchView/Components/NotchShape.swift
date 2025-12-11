//
//  NotchShape.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 10/31/25.
//

import SwiftUI

struct NotchShape: Shape {
    let width: CGFloat
    let height: CGFloat
    let cornerRadiusLeft: CGFloat
    let cornerRadiusRight: CGFloat
    let circularNotch: Bool

    func path(in rect: CGRect) -> Path {
        let notchW = min(width, rect.width)
        let notchH = min(height, rect.height)

        let x = rect.midX - notchW / 2
        let y = rect.minY
        let notch = CGRect(x: x, y: y, width: notchW, height: notchH)

        let cornerRadiusLeft = cornerRadiusLeft
        let cornerRadiusRight = cornerRadiusRight

        let tl = CGPoint(x: notch.minX, y: notch.minY)
        let tr = CGPoint(x: notch.maxX, y: notch.minY)
        let br = CGPoint(x: notch.maxX, y: notch.maxY)
        let bl = CGPoint(x: notch.minX, y: notch.maxY)

        var p = Path()

        if circularNotch {
            p.move(to: CGPoint(x: tr.x, y: tr.y + cornerRadiusLeft + cornerRadiusRight))
            p.addQuadCurve(
                to: CGPoint(x: tr.x - cornerRadiusLeft, y: tr.y + cornerRadiusRight),
                control: CGPoint(x: tr.x, y: tr.y + cornerRadiusRight)
            )
        } else {
            p.move(to: CGPoint(x: tr.x, y: tr.y))
            p.addQuadCurve(
                to: CGPoint(x: tr.x - cornerRadiusRight, y: tr.y + cornerRadiusRight),
                control: CGPoint(x: tr.x, y: tr.y + cornerRadiusRight)
            )
        }

        p.addLine(to: CGPoint(x: tl.x + cornerRadiusLeft, y: tl.y + cornerRadiusRight))
        p.addQuadCurve(
            to: CGPoint(x: tl.x, y: tl.y + cornerRadiusRight + cornerRadiusLeft),
            control: CGPoint(x: tl.x, y: tl.y + cornerRadiusRight)
        )

        p.addLine(to: CGPoint(x: bl.x, y: bl.y - cornerRadiusRight - cornerRadiusLeft))
        p.addQuadCurve(
            to: CGPoint(x: bl.x + cornerRadiusLeft, y: bl.y - cornerRadiusRight),
            control: CGPoint(x: bl.x, y: bl.y - cornerRadiusRight)
        )

        if circularNotch {
            p.addLine(to: CGPoint(x: br.x - cornerRadiusLeft, y: br.y - cornerRadiusRight))
            p.addQuadCurve(
                to: CGPoint(x: br.x, y: br.y - cornerRadiusLeft - cornerRadiusRight),
                control: CGPoint(x: br.x, y: br.y - cornerRadiusRight)
            )
            p.addLine(to: CGPoint(x: tr.x, y: tr.y + cornerRadiusLeft + cornerRadiusLeft))
        } else {
            p.addLine(to: CGPoint(x: br.x - cornerRadiusRight, y: br.y - cornerRadiusRight))
            p.addQuadCurve(
                to: CGPoint(x: br.x, y: br.y),
                control: CGPoint(x: br.x, y: br.y - cornerRadiusRight)
            )
            p.addLine(to: CGPoint(x: tr.x, y: tr.y))
        }

        p.closeSubpath()

        return p
    }
}

