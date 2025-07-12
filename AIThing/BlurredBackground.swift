//
//  BlurredBackground.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import AppKit
import SwiftUI

struct BlurredBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .withinWindow
        view.material = .underWindowBackground  // ✅ Modern material
        view.state = .active

        // Optional: Force dark appearance even in light mode
        view.appearance = NSAppearance(named: .vibrantDark)

        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        // No dynamic updates needed
    }
}
