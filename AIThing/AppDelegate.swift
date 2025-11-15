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
import SwiftUI

enum WindowSize: Int {
    case notchIsCollapsed = 0
    case sidebarIsCollapsed = 1
    case sidebarIsExpanded = 2
    case chatIsShown = 3
    case chatIsExpanded = 4
}

final class NotchVM: ObservableObject {
    @Published var refresh = false
    @Published var minimize = false
    @Published var open = false
    @Published var toggle = false
    @Published var selectedText = ""
    @Published var move = false

    func refreshDimensions() { refresh.toggle() }
    func minimizeDimensions() { minimize.toggle() }
    func openDimensions() { open.toggle() }
    func toggleDimensions() { toggle.toggle() }
    func updateSelectedText(text: String) { selectedText = text }
    func toggleMove() { move.toggle() }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    private var floatingWindow: NonActivatingPanel!

    static var allowQuit = false
    static var selectedText = ""

    private var originalWidth: CGFloat = 660
    private var originalHeight: CGFloat = 600
    private var width: CGFloat = 660
    private var height: CGFloat = 600
    private var shadowBuffer: CGFloat = 32

    private var previousTopY: CGFloat = 0
    private var lastWindowSize: WindowSize = .notchIsCollapsed

    private var upHotKey: HotKey?
    private var downHotKey: HotKey?
    private var spaceHotKey: HotKey?
    private var spaceHotKeyAnother: HotKey?

    private let textManager = SelectedTextManager.shared
    private var selectedText: String = ""
    private var pollingTimer: DispatchSourceTimer?
    private var mouseLocation = NSEvent.mouseLocation

    let vm = NotchVM()

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

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NonActivatingPanelDidMove"),
            object: floatingWindow,
            queue: .main
        ) { notification in
            self.vm.toggleMove()
        }

        FirebaseApp.configure()

        setupGlobalHotKeys()
        setupNotchWindow()

        // Launch app on login
        try? SMAppService.mainApp.register()
    }

    @objc private func handleScreenChange() {
        _ = updateWindowSize(windowSize: lastWindowSize, resetY: true)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { OAuthSwift.handle(url: url) }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return AppDelegate.allowQuit ? .terminateNow : .terminateCancel
    }
}

extension AppDelegate {
    private func setupGlobalHotKeys() {
        spaceHotKey = HotKey(key: .space, modifiers: [.control, .option])
        spaceHotKeyAnother = HotKey(key: .space, modifiers: [.control])
        spaceHotKey?.keyDownHandler = { self.vm.toggleDimensions() }
        spaceHotKeyAnother?.keyDownHandler = { self.vm.toggleDimensions() }
    }

    private func setupNotchWindow() {
        // Get screen dimensions
        guard let screen = NSScreen.main else { return }
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
            vm: vm,
            updateWindowSize: {
                return self.updateWindowSize(windowSize: $0)
            },
            modifyWindowBaseSize: {
                return self.modifyWindowBaseSize(size: $0, windowSize: $1)
            },
            modifyWindowOriginalSize: { self.modifyWindowOriginalSize() },
            modifyWindowTopOffset: { self.modifyWindowTopOffset(offset: $0, windowSize: $1) },
            gainFocus: { self.gainFocus() },
            isTouchingRightEdge: { return self.isTouchingRightEdge() },
            windowMoveable: { self.windowMoveable($0) },
            startSelectionPoll: { self.startSelectionPoll() },
            stopSelectionPoll: { self.stopSelectionPoll() },
            setPanelVisibility: { self.setPanelVisibility() }
        )
        floatingWindow.contentView = FirstMouseHostingView(rootView: notchView)
        floatingWindow.makeKeyAndOrderFront(nil)

        setPanelVisibility()
    }
}

extension AppDelegate {
    private func windowMoveable(_ value: Bool) {
        floatingWindow?.isMovableByWindowBackground = value
    }

    private func gainFocus() {
        floatingWindow?.gainFocus()
    }

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

    private func modifyWindowTopOffset(offset: CGFloat, windowSize: WindowSize) {
        if windowSize == .chatIsExpanded {
            return
        }
        _ = updateWindowSize(windowSize: windowSize, offsetTopY: offset)
    }

    private func getWindowSize(windowSize: WindowSize) -> (CGFloat, CGFloat) {
        switch windowSize {
        case .notchIsCollapsed:
            return (60 + shadowBuffer, 100)
        case .sidebarIsCollapsed:
            return (60 + shadowBuffer, 160)
        case .sidebarIsExpanded:
            return (200 + shadowBuffer, 600)
        case .chatIsShown:
            return (width + shadowBuffer, height)
        case .chatIsExpanded:
            if let screen = NSScreen.main {
                return (
                    min(screen.visibleFrame.maxX * 0.5, 1000) + shadowBuffer,
                    min(screen.visibleFrame.maxY * 0.8, 1000)
                )
            }
            return (860 + shadowBuffer, 600)
        }
    }

    private func updateWindowSize(
        windowSize: WindowSize,
        offsetTopY: CGFloat = 0,
        resetY: Bool = false,
    ) -> (
        CGFloat,
        CGFloat
    ) {
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
        var newY = currentTopY - windowHeight + offsetTopY

        if windowSize == .chatIsExpanded {
            previousTopY = currentTopY
            newY = screenFrame.midY - (windowHeight / 2)
        } else if previousTopY != 0 {
            newY = previousTopY - windowHeight + offsetTopY
            previousTopY = 0
        }

        floatingWindow.setFrame(
            NSRect(x: xPosition, y: newY, width: windowWidth, height: windowHeight),
            display: false,
            animate: false
        )

        let outOfBoundsEdges = outOfBoundsEdges()
        if !outOfBoundsEdges.isEmpty {
            if outOfBoundsEdges.contains(.top) {
                floatingWindow.setFrame(
                    NSRect(
                        x: xPosition,
                        y: screenFrame.maxY - windowHeight,
                        width: windowWidth,
                        height: windowHeight
                    ),
                    display: false,
                    animate: false
                )
            } else if outOfBoundsEdges.contains(.bottom) {
                floatingWindow.setFrame(
                    NSRect(
                        x: xPosition,
                        y: screenFrame.minY,
                        width: windowWidth,
                        height: windowHeight
                    ),
                    display: false,
                    animate: false
                )
            }
        }

        lastWindowSize = windowSize
        return (windowWidth, windowHeight)
    }

    enum OutOfBoundsEdge: String {
        case left
        case right
        case top
        case bottom
    }

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

    private func isTouchingRightEdge() -> Bool {
        guard let screen = floatingWindow.screen ?? NSScreen.main else { return false }
        let windowFrame = floatingWindow.frame
        let screenFrame = screen.visibleFrame

        // Check if the window's right edge is at or beyond the screen's right edge
        return windowFrame.maxX >= screenFrame.maxX
    }

    /// Sets the panel visibility in screenshots based on user preferences
    /// Uses readOnly sharing type to show the panel, or none to hide it from screenshots
    private func setPanelVisibility() {
        if let floatingWindow = floatingWindow {
            floatingWindow.sharingType = getPreferencesShowInScreenshot() ? .readOnly : .none
        }
    }
}

extension AppDelegate {
    /// Put any bundle IDs you want to ignore here.
    /// Example values shown; change/remove as needed.
    private var excludedBundleIDs: Set<String> {
        [
            "com.thisisnsh.mac.AIThing",
            "com.apple.finder",
            // add more...
        ]
    }

    private func stopSelectionPoll() {
        pollingTimer?.cancel()
    }

    private func startSelectionPoll() {
        pollingTimer?.cancel()

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: 0.5)

        // Fixes: "Capture of 'self' with non-Sendable type 'AppDelegate' in a '@Sendable' closure"
        // by capturing self weakly.
        timer.setEventHandler { [weak self] in
            guard let self else { return }

            // Accessibility trust (prompt once as needed)
            if !AXIsProcessTrusted() {
                let opts: NSDictionary = [
                    kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true
                ]
                _ = AXIsProcessTrustedWithOptions(opts)
                return
            }

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

    /// Main-actor isolate this since it touches UI state (e.g. view models).
    @MainActor
    private func setupSelection() async {
        do {
            // Try AXUI method first
            if let text = try await textManager.getSelectedTextByAX() {
                let sanitized = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !sanitized.isEmpty {
                    // We're on the main actor; no need to dispatch to main.
                    vm.updateSelectedText(text: sanitized)
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
                    vm.updateSelectedText(text: sanitized)
                    return
                }
            }
        } catch {
            // You can log if useful
        }

        selectedText = ""
    }
}

final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var acceptsFirstResponder: Bool { true }
}
