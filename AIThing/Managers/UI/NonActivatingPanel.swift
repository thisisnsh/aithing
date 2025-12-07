//
//  NonActivatingPanel.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import AppKit

// MARK: - Non-Activating Panel Delegate

/// Delegate protocol for receiving notifications about panel movements.
protocol NonActivatingPanelDelegate: AnyObject {
    /// Called when the panel's frame changes.
    ///
    /// - Parameter panel: The panel that moved
    func panelDidMove(_ panel: NonActivatingPanel)
}

// MARK: - Non-Activating Panel

/// A floating panel that can become key but doesn't activate the app.
///
/// This panel type is used for the main UI window. It:
/// - Floats above other windows at status bar level
/// - Can become key to receive keyboard input
/// - Doesn't activate the app when clicked
/// - Appears on all spaces
/// - Doesn't participate in window cycling
class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    weak var panelDelegate: NonActivatingPanelDelegate?
    private var frameObserver: NSKeyValueObservation?

    /// Creates a new non-activating panel with the specified content rect.
    ///
    /// - Parameter contentRect: The initial frame for the panel
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

    /// Activates the app and brings this panel to the front.
    ///
    /// Makes the panel key and orders it front, activating the app
    /// and ignoring other apps in the process.
    func gainFocus() {
        // Bring the app forward if it's not active
        NSApp.activate(ignoringOtherApps: true)
        // Bring this specific panel to the front and make it key
        self.makeKeyAndOrderFront(nil)
    }
}

