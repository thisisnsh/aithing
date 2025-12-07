//
//  AppDelegate.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import AppKit
import Cocoa
import FirebaseAuth
import FirebaseCore
import HotKey
import Logging
import OAuthSwift
import SelectedTextKit
import ServiceManagement
import Sparkle
import SwiftUI

// MARK: - App Delegate

/// Main application delegate managing the window, hotkeys, and global state.
///
/// Responsibilities:
/// - Creates and manages the floating notch window
/// - Registers global keyboard shortcuts
/// - Handles selected text monitoring
/// - Initializes Firebase and other services
/// - Manages window positioning and sizing
class AppDelegate: NSObject, NSApplicationDelegate {
    private var floatingWindow: NonActivatingPanel!

    private var width: CGFloat = 660
    private var height: CGFloat = 600
    private var shadowBuffer: CGFloat = 32

    private var previousTopY: CGFloat = 0
    private var lastWindowSize: WindowSize = .collapsed

    private var upHotKey: HotKey?
    private var downHotKey: HotKey?
    private var spaceHotKey: HotKey?
    private var spaceHotKeyAnother: HotKey?

    private let textManager = SelectedTextManager.shared
    private var selectedText: String = ""
    private var pollingTimer: DispatchSourceTimer?
    private var mouseLocation = NSEvent.mouseLocation

    let viewModel = NotchViewModel()
    let appContext = AppContext()
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    /// Called when the application finishes launching.
    ///
    /// Sets up:
    /// - Logging system
    /// - Firebase configuration (if available)
    /// - Global hotkeys for opening/closing the window
    /// - The floating notch window
    /// - Launch-at-login service
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)  // background-style app

        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = .info
            return handler
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NonActivatingPanelDidMove"),
            object: floatingWindow,
            queue: .main
        ) { notification in
            self.viewModel.triggerMove()
        }

        // Only configure Firebase if GoogleService-Info.plist has valid values
        if FirebaseConfiguration.shared.isConfigured {
            FirebaseApp.configure()
        }

        setupGlobalHotKeys()
        setupNotchWindow()

        // Launch app on login
        try? SMAppService.mainApp.register()
    }

    /// Handles screen configuration changes (resolution, arrangement, etc.).
    ///
    /// Resets the window position to ensure it remains visible.
    @objc private func handleScreenChange() {
        _ = updateWindowSize(windowSize: lastWindowSize, resetY: true)
    }

    /// Called when any application becomes active.
    ///
    /// Refreshes the app context to track the newly active application.
    @objc func appDidActivate(_ note: Notification) {
        DispatchQueue.main.async {
            self.appContext.refresh()
        }
    }

    /// Handles URL scheme callbacks for OAuth flows.
    ///
    /// - Parameters:
    ///   - application: The application instance
    ///   - urls: URLs to handle (OAuth callback URLs)
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { OAuthSwift.handle(url: url) }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return .terminateNow
    }
}

// MARK: - Setup

extension AppDelegate {
    /// Registers global keyboard shortcuts for the application.
    ///
    /// Registers:
    /// - Ctrl+Option+Space: Toggle window open/close
    /// - Ctrl+Space: Toggle window open/close (alternative)
    private func setupGlobalHotKeys() {
        spaceHotKey = HotKey(key: .space, modifiers: [.control, .option])
        spaceHotKeyAnother = HotKey(key: .space, modifiers: [.control])
        spaceHotKey?.keyDownHandler = { self.viewModel.triggerOpenClose() }
        spaceHotKeyAnother?.keyDownHandler = { self.viewModel.triggerOpenClose() }
    }

    /// Creates and configures the main floating window.
    ///
    /// Initializes the window on the right side of the screen with
    /// the collapsed size, sets up the SwiftUI view hierarchy, and
    /// configures window visibility for screenshots.
    private func setupNotchWindow() {
        // Get screen dimensions
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        // Create a borderless, floating window on the right side
        let (windowWidth, windowHeight) = getWindowSize(windowSize: .collapsed)
        let xPosition = screenFrame.maxX - windowWidth
        let yPosition = screenFrame.midY - (windowHeight / 2)

        floatingWindow = NonActivatingPanel(
            contentRect: NSRect(
                x: xPosition + 2,
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
            viewModel: viewModel,
            updater: updaterController.updater,
            updateWindowSize: { return self.updateWindowSize(windowSize: $0) },
            modifyWindowSize: { return self.modifyWindowSize(size: $0, windowSize: $1) },
            ignoresMouseEvents: { self.ignoresMouseEvents($0) },
            gainFocus: { self.gainFocus() },
            isTouchingRightEdge: { return self.isTouchingRightEdge() },
            windowMoveable: { self.windowMoveable($0) },
            startSelectionPoll: { self.startSelectionPoll() },
            stopSelectionPoll: { self.stopSelectionPoll() },
            setPanelVisibility: { self.setPanelVisibility() }
        )
        .environmentObject(appContext)

        floatingWindow.contentView = FirstMouseHostingView(rootView: notchView)
        floatingWindow.makeKeyAndOrderFront(nil)

        setPanelVisibility()
    }
}

// MARK: - Window Management

extension AppDelegate {
    /// Sets whether the window can be moved by dragging its background.
    ///
    /// - Parameter value: Whether window should be moveable
    private func windowMoveable(_ value: Bool) {
        floatingWindow?.isMovableByWindowBackground = value
    }

    /// Sets whether the window ignores mouse events (click-through).
    ///
    /// - Parameter value: Whether to ignore mouse events
    private func ignoresMouseEvents(_ value: Bool) {
        floatingWindow?.ignoresMouseEvents = value
    }

    /// Brings the floating window to the front and makes it key.
    private func gainFocus() {
        floatingWindow?.gainFocus()
    }

    /// Modifies the window size during resizing.
    ///
    /// Updates the stored width and height based on the delta, enforcing minimum sizes.
    ///
    /// - Parameters:
    ///   - size: The size delta to apply
    ///   - windowSize: The target window size state
    /// - Returns: Tuple of (width, height) for the updated window
    private func modifyWindowSize(size: CGSize, windowSize: WindowSize) -> (CGFloat, CGFloat) {
        width = max(560, width + size.width)
        height = max(600, height + size.height)
        return updateWindowSize(windowSize: windowSize)
    }

    /// Gets the dimensions for the specified window size state.
    ///
    /// - Parameter windowSize: The window size state (collapsed or expanded)
    /// - Returns: Tuple of (width, height) including shadow buffer
    private func getWindowSize(windowSize: WindowSize) -> (CGFloat, CGFloat) {
        switch windowSize {
        case .collapsed:
            return (60 + shadowBuffer, 100 + shadowBuffer + shadowBuffer)
        case .expanded:
            return (width + shadowBuffer, height + shadowBuffer + shadowBuffer)
        }
    }

    /// Updates the window size and position while keeping the top-right corner fixed.
    ///
    /// - Parameters:
    ///   - windowSize: The target window size state
    ///   - offsetTopY: Optional Y offset to apply
    ///   - resetY: Whether to reset the Y position tracking
    /// - Returns: Tuple of (width, height) for the updated window
    private func updateWindowSize(windowSize: WindowSize, offsetTopY: CGFloat = 0, resetY: Bool = false) -> (CGFloat, CGFloat) {
        // Calculate new position to keep top-right corner fixed
        guard let screen = floatingWindow.screen ?? NSScreen.main else {
            return getWindowSize(windowSize: windowSize)
        }

        let (windowWidth, windowHeight) = getWindowSize(windowSize: windowSize)

        let screenFrame = screen.visibleFrame
        let xPosition = screenFrame.maxX - windowWidth

        // Calculate Y position to keep top-right corner fixed
        // When expanding, we need to move the origin down
        let currentTopY = floatingWindow.frame.origin.y + floatingWindow.frame.height
        var newX = xPosition + 2
        var newY = currentTopY - windowHeight + offsetTopY

        if previousTopY != 0 {
            newY = previousTopY - windowHeight + offsetTopY
            previousTopY = 0
        }

        floatingWindow.setFrame(
            NSRect(x: newX, y: newY, width: windowWidth, height: windowHeight),
            display: false,
            animate: false
        )

        let outOfBoundsEdges = outOfBoundsEdges()
        if !outOfBoundsEdges.isEmpty {

            if outOfBoundsEdges.contains(.top) {
                newY = screenFrame.maxY - windowHeight
            } else if outOfBoundsEdges.contains(.bottom) {
                newY = screenFrame.minY
            }

            if outOfBoundsEdges.contains(.left) {
                newX = screenFrame.minX
            } else if outOfBoundsEdges.contains(.right) {
                newX = xPosition + 2
            }

            floatingWindow.setFrame(
                NSRect(x: newX, y: newY, width: windowWidth, height: windowHeight),
                display: false,
                animate: false
            )
        }

        lastWindowSize = windowSize
        return (windowWidth, windowHeight)
    }

    /// Determines which edges of the window are outside the visible screen bounds.
    ///
    /// - Returns: Set of edges that are out of bounds
    private func outOfBoundsEdges() -> Set<OutOfBoundsEdge> {
        var edges = Set<OutOfBoundsEdge>()
        guard let screen = floatingWindow.screen ?? NSScreen.main else { return edges }

        let windowFrame = floatingWindow.frame
        let screenFrame = screen.visibleFrame

        // Compare window edges to screen bounds
        if windowFrame.minX < screenFrame.minX {
            edges.insert(.left)
        }
        if windowFrame.maxX > screenFrame.maxX {
            edges.insert(.right)
        }
        if windowFrame.minY < screenFrame.minY {
            edges.insert(.bottom)
        }
        if windowFrame.maxY > screenFrame.maxY {
            edges.insert(.top)
        }

        return edges
    }

    /// Checks if the window is touching or past the right edge of the screen.
    ///
    /// - Returns: `true` if the window's right edge is at or beyond the screen's right edge
    private func isTouchingRightEdge() -> Bool {
        guard let screen = floatingWindow.screen ?? NSScreen.main else { return false }
        let windowFrame = floatingWindow.frame
        let screenFrame = screen.visibleFrame

        // Check if the window's right edge is at or beyond the screen's right edge
        return windowFrame.maxX >= screenFrame.maxX
    }

    /// Sets the panel visibility in screenshots based on user preferences.
    ///
    /// Uses `.readOnly` sharing type to show the panel in screenshots,
    /// or `.none` to hide it from screenshots.
    private func setPanelVisibility() {
        if let floatingWindow = floatingWindow {
            floatingWindow.sharingType = getPreferencesShowInScreenshot() ? .readOnly : .none
        }
    }
}

// MARK: - Text Selection Monitoring

extension AppDelegate {
    /// Bundle IDs of apps to exclude from text selection monitoring.
    ///
    /// Add apps here that shouldn't trigger text selection detection.
    private var excludedBundleIDs: Set<String> {
        [
            "com.thisisnsh.mac.AIThing",
            "com.apple.finder",
            // add more...
        ]
    }

    /// Stops monitoring for text selection changes.
    private func stopSelectionPoll() {
        viewModel.updateSelectionPolling(value: false)
        pollingTimer?.cancel()
    }

    /// Starts monitoring for text selection changes every 500ms.
    ///
    /// Requests accessibility permissions if not already granted.
    /// Skips monitoring when the frontmost app is in the excluded list.
    private func startSelectionPoll() {
        viewModel.updateSelectionPolling(value: true)
        pollingTimer?.cancel()

        // Accessibility trust (prompt once as needed)
        if !AXIsProcessTrusted() {
            let opts: NSDictionary = [
                kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true
            ]
            _ = AXIsProcessTrustedWithOptions(opts)
            return
        }

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: 0.5)

        // Fixes: "Capture of 'self' with non-Sendable type 'AppDelegate' in a '@Sendable' closure"
        // by capturing self weakly.
        timer.setEventHandler { [weak self] in
            guard let self else { return }

            // Skip if the *frontmost* app is our own or excluded.
            if let frontmostID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
                if frontmostID == Bundle.main.bundleIdentifier { return }
                if self.excludedBundleIDs.contains(frontmostID) { return }
            }

            // Hop to the main actor and run the selection logic.
            // Using [weak self] again avoids capturing a non-Sendable strong reference
            // inside Task's @Sendable closure.
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.setupSelection()
            }
        }

        pollingTimer = timer
        timer.resume()
    }

    /// Attempts to retrieve currently selected text using multiple methods.
    ///
    /// Tries accessibility API first, then falls back to menu action copy.
    /// Updates the view model with any non-empty selection found.
    @MainActor
    private func setupSelection() async {
        do {
            // Try AXUI method first
            if let text = try await textManager.getSelectedTextByAX() {
                let sanitized = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !sanitized.isEmpty {
                    // We're on the main actor; no need to dispatch to main.
                    viewModel.updateSelectedText(text: sanitized)
                    return
                }
            }
        } catch {
            // You can log if useful
        }

        do {
            // Fallback: menu action copy
            if let menuCopyText = try await textManager.getSelectedTextByMenuAction() {
                let sanitized = menuCopyText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !sanitized.isEmpty {
                    viewModel.updateSelectedText(text: sanitized)
                    return
                }
            }
        } catch {
            // You can log if useful
        }

        selectedText = ""
    }
}

// MARK: - First Mouse Hosting View

/// Custom NSHostingView that accepts first mouse clicks.
///
/// Allows the window to respond to clicks even when it's not the active window,
/// without activating the app.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    /// Accepts the first mouse click even when the window is not active.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    
    /// Accepts first responder status for keyboard input.
    override var acceptsFirstResponder: Bool { true }
}
