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
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let notchW = min(width, rect.width)
        let notchH = min(height, rect.height)

        let x = rect.midX - notchW / 2
        let y = rect.minY
        let notch = CGRect(x: x, y: y, width: notchW, height: notchH)

        let r = cornerRadius

        let tl = CGPoint(x: notch.minX, y: notch.minY)
        let tr = CGPoint(x: notch.maxX, y: notch.minY)
        let br = CGPoint(x: notch.maxX, y: notch.maxY)
        let bl = CGPoint(x: notch.minX, y: notch.maxY)

        var p = Path()

        //        p.move(to: CGPoint(x: tl.x, y: tl.y))
        //        p.addQuadCurve(
        //            to: CGPoint(x: tl.x + r, y: tl.y + r),
        //            control: CGPoint(x: tl.x + r, y: tl.y)
        //        )
        //
        //        p.addLine(to: CGPoint(x: bl.x + r, y: bl.y - r))
        //        p.addQuadCurve(
        //            to: CGPoint(x: bl.x + 2 * r, y: bl.y),
        //            control: CGPoint(x: bl.x + r, y: bl.y)
        //        )
        //
        //        p.addLine(to: CGPoint(x: br.x - 2 * r, y: br.y))
        //        p.addQuadCurve(
        //            to: CGPoint(x: br.x - r, y: br.y - r),
        //            control: CGPoint(x: br.x - r, y: br.y)
        //        )
        //
        //        p.addLine(to: CGPoint(x: tr.x - r, y: tr.y + r))
        //        p.addQuadCurve(
        //            to: CGPoint(x: tr.x, y: tr.y),
        //            control: CGPoint(x: tr.x - r, y: tr.y)
        //        )
        //
        //        p.addLine(to: CGPoint(x: tl.x, y: tl.y))
        //        p.closeSubpath()

        p.move(to: CGPoint(x: tr.x, y: tr.y))
        p.addQuadCurve(
            to: CGPoint(x: tr.x - r, y: tr.y + r),
            control: CGPoint(x: tr.x, y: tr.y + r)
        )

        p.addLine(to: CGPoint(x: tl.x + r, y: tl.y + r))
        p.addQuadCurve(
            to: CGPoint(x: tl.x, y: tl.y + r + r),
            control: CGPoint(x: tl.x, y: tl.y + r)
        )

        p.addLine(to: CGPoint(x: bl.x, y: bl.y - r - r))
        p.addQuadCurve(
            to: CGPoint(x: bl.x + r, y: bl.y - r),
            control: CGPoint(x: bl.x, y: bl.y - r)
        )

        p.addLine(to: CGPoint(x: br.x - r, y: br.y - r))
        p.addQuadCurve(
            to: CGPoint(x: br.x, y: br.y),
            control: CGPoint(x: br.x, y: br.y - r)
        )

        p.addLine(to: CGPoint(x: tr.x, y: tr.y))
        p.closeSubpath()

        return p
    }
}
