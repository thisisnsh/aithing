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
    case notchIsCollapsed = 0
    case notchIsExpandedSidebarIsCollapsed = 1
    case notchIsExpanded = 2
    case chatIsShown = 3
    case chatIsExpanded = 4
}

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    private var floatingWindow: NonActivatingPanel!

    static var allowQuit = false
    private var screen = NSScreen.main

    private var originalWidth: CGFloat = 560
    private var originalHeight: CGFloat = 600
    private var width: CGFloat = 560
    private var height: CGFloat = 600

    private var previousTopY: CGFloat = 0

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
        guard let screen = screen else { return }
        let screenFrame = screen.visibleFrame

        // Create a borderless, floating window on the right side
        let (windowWidth, windowHeight) = getWindowSize(windowSize: .notchIsCollapsed)
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
            modifyWindowBaseSize: {
                return self.modifyWindowBaseSize(size: $0, windowSize: $1)
            },
            modifyWindowOriginalSize: { self.modifyWindowOriginalSize() }
        )
        floatingWindow.contentView = NSHostingView(rootView: notchView)
        floatingWindow.makeKeyAndOrderFront(nil)

        setPanelVisibility()
    }
}

extension AppDelegate {

    private func modifyWindowBaseSize(size: CGSize, windowSize: WindowSize) -> (CGFloat, CGFloat) {
        let newWidth = max(560, originalWidth + size.width)
        let newHeight = max(600, originalHeight + size.height)

        self.width = newWidth
        self.height = newHeight
        return updateWindowSize(windowSize: windowSize)
    }

    private func modifyWindowOriginalSize() {
        originalWidth = width
        originalHeight = height
    }

    private func getWindowSize(windowSize: WindowSize) -> (CGFloat, CGFloat) {
        switch windowSize {
        case .notchIsCollapsed:
            return (60, 100)
        case .notchIsExpandedSidebarIsCollapsed:
            return (60, 160)
        case .notchIsExpanded:
            return (200, 600)
        case .chatIsShown:
            return (width, height)
        case .chatIsExpanded:
            if let screen = screen {
                return (
                    min(screen.visibleFrame.maxX / 2, 1000),
                    min(screen.visibleFrame.maxY * 0.8, 1000)
                )
            }
            return (860, 600)
        }
    }

    private func updateWindowSize(windowSize: WindowSize) -> (CGFloat, CGFloat) {
        let (windowWidth, windowHeight) = getWindowSize(windowSize: windowSize)

        // Calculate new position to keep top-right corner fixed
        if let screen = screen {
            let screenFrame = screen.visibleFrame
            let xPosition = screenFrame.maxX - windowWidth

            // Calculate Y position to keep top-right corner fixed
            // When expanding, we need to move the origin down
            let currentTopY = floatingWindow.frame.origin.y + floatingWindow.frame.height
            var newY = currentTopY - windowHeight

            if windowSize == .chatIsExpanded {
                previousTopY = currentTopY
                newY = screenFrame.midY - (windowHeight / 2)
            } else if previousTopY != 0 {
                newY = previousTopY - windowHeight
                previousTopY = 0
            }

            floatingWindow.setFrame(
                NSRect(x: xPosition, y: newY, width: windowWidth, height: windowHeight),
                display: false,
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
