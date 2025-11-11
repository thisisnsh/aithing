//
//  NonActivatingPanel.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import AppKit

protocol NonActivatingPanelDelegate: AnyObject {
    func panelDidMove(_ panel: NonActivatingPanel)
}

class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    weak var panelDelegate: NonActivatingPanelDelegate?
    private var frameObserver: NSKeyValueObservation?

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

        // Observe frame changes
        frameObserver = self.observe(\.frame, options: [.new]) { [weak self] panel, _ in
            guard let self = self else { return }
            self.panelDelegate?.panelDidMove(self)
            NotificationCenter.default.post(
                name: NSNotification.Name("NonActivatingPanelDidMove"),
                object: self
            )
        }
    }

    func gainFocus() {
        // Bring the app forward if it's not active
        NSApp.activate(ignoringOtherApps: true)
        // Bring this specific panel to the front and make it key
        self.makeKeyAndOrderFront(nil)
    }
}
