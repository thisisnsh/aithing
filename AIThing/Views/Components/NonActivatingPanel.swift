//
//  NonActivatingPanel.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import AppKit

class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.level = .statusBar
        self.hasShadow = false
        self.backgroundColor = .clear
        self.isOpaque = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [
            .canJoinAllSpaces, .ignoresCycle, .fullScreenAuxiliary,
        ]
        self.isMovableByWindowBackground = false
        self.acceptsMouseMovedEvents = true
    }

    func gainFocus() {
        // Bring the app forward if it's not active
        NSApp.activate(ignoringOtherApps: true)
        // Bring this specific panel to the front and make it key
        self.makeKeyAndOrderFront(nil)
    }
}
