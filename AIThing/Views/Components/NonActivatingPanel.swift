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
        self.level = .floating
        self.hasShadow = false
        self.backgroundColor = .clear
        self.isOpaque = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.transient, .moveToActiveSpace, .ignoresCycle]
        self.isMovableByWindowBackground = true
    }
}
