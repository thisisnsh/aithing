//
//  AppDelegate.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import AppKit
import FirebaseAuth
import FirebaseCore
import Logging
import OAuthSwift
import ServiceManagement
import SwiftUI

enum WindowSize: Int {
    // notch is collapsed
    case alpha = 0
    // notch is expanded
    case beta = 1
    // chat window is shown
    case gamma = 2
    // chat window is expanded
    case delta = 3
}

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    private var floatingWindow: NonActivatingPanel!

    static var allowQuit = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)  // background-style app

        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = .info
            return handler
        }

        FirebaseApp.configure()

        setupNotchWindow()

        // Launch app on login
        try? SMAppService.mainApp.register()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { OAuthSwift.handle(url: url) }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return AppDelegate.allowQuit ? .terminateNow : .terminateCancel
    }
}

extension AppDelegate {

    private func setupNotchWindow() {
        // Get screen dimensions
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        // Create a borderless, floating window on the right side
        let (windowWidth, windowHeight) = getWindowSize(windowSize: .alpha)
        let xPosition = screenFrame.maxX - windowWidth
        let yPosition = screenFrame.midY - (windowHeight / 2)

        floatingWindow = NonActivatingPanel(
            contentRect: NSRect(
                x: xPosition,
                y: yPosition,
                width: windowWidth,
                height: windowHeight
            )
        )
        floatingWindow.alphaValue = 1
        floatingWindow.center()
        floatingWindow.orderFrontRegardless()  // no app activation

        // Create the SwiftUI view
        let notchView = NotchView(
            updateWindowSize: {
                return self.updateWindowSize(windowSize: $0)
            },
        )
        floatingWindow.contentView = NSHostingView(rootView: notchView)
        floatingWindow.makeKeyAndOrderFront(nil)

        setPanelVisibility()
    }
}

extension AppDelegate {

    private func getWindowSize(windowSize: WindowSize) -> (CGFloat, CGFloat) {
        switch windowSize {
        case .alpha:  // collapsed notch
            return (60, 100)
        case .beta:  // expanded notch
            return (200, 600)
        case .gamma:  // chat window shown (use expanded for now)
            return (560, 600)
        case .delta:  // chat window expanded (use expanded for now)
            return (860, 600)
        }
    }

    private func updateWindowSize(windowSize: WindowSize) -> (CGFloat, CGFloat) {
        let (windowWidth, windowHeight) = getWindowSize(windowSize: windowSize)

        // Calculate new position to keep top-right corner fixed
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let xPosition = screenFrame.maxX - windowWidth

            // Calculate Y position to keep top-right corner fixed
            // When expanding, we need to move the origin down
            let currentTopY = floatingWindow.frame.origin.y + floatingWindow.frame.height
            let newY = currentTopY - windowHeight

            floatingWindow.setFrame(
                NSRect(x: xPosition, y: newY, width: windowWidth, height: windowHeight),
                display: true,
                animate: false
            )
        }

        return (windowWidth, windowHeight)
    }

    /// Sets the panel visibility in screenshots based on user preferences
    /// Uses readOnly sharing type to show the panel, or none to hide it from screenshots
    private func setPanelVisibility() {
        if let floatingWindow = floatingWindow {
            floatingWindow.sharingType = getPreferencesShowInScreenshot() ? .readOnly : .none
        }
    }

}
