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
    case chatIsShownSidebarIsCollapsed = 3
    case chatIsShownSidebarIsExpanded = 4
    case chatIsExpanded = 5
}

final class NotchVM: ObservableObject {
    @Published var refresh = false
    @Published var minimize = false
    @Published var open = false
    @Published var toggle = false
    @Published var selectedText = ""
    func refreshDimensions() { refresh.toggle() }
    func minimizeDimensions() { minimize.toggle() }
    func openDimensions() { open.toggle() }
    func toggleDimensions() { toggle.toggle() }
    func updateSelectedText(text: String) { selectedText = text }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    private var floatingWindow: NonActivatingPanel!

    static var allowQuit = false
    static var selectedText = ""

    private var screen = NSScreen.main

    private var originalWidth: CGFloat = 560
    private var originalHeight: CGFloat = 600
    private var width: CGFloat = 560
    private var height: CGFloat = 600

    private var previousTopY: CGFloat = 0
    private var lastWindowSize: WindowSize = .notchIsCollapsed

    private var upHotKey: HotKey?
    private var downHotKey: HotKey?
    private var spaceHotKey: HotKey?

    private var selectionResetRequired = false
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

        FirebaseApp.configure()

        startSelectionPoll()
        setupGlobalHotKeys()
        setupNotchWindow()

        // Launch app on login
        try? SMAppService.mainApp.register()
    }

    @objc private func handleScreenChange() {
        _ = updateWindowSize(windowSize: lastWindowSize, resetY: true)
        vm.refreshDimensions()
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
        upHotKey = HotKey(key: .upArrow, modifiers: [.control, .option])
        downHotKey = HotKey(key: .downArrow, modifiers: [.control, .option])
        spaceHotKey = HotKey(key: .space, modifiers: [.control, .option])

        upHotKey?.keyDownHandler = {
            self.modifyWindowTopOffset(offset: 16, windowSize: self.lastWindowSize)
        }
        downHotKey?.keyDownHandler = {
            self.modifyWindowTopOffset(offset: -16, windowSize: self.lastWindowSize)
        }
        spaceHotKey?.keyDownHandler = { self.vm.toggleDimensions() }
    }

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
            vm: vm,
            updateWindowSize: {
                return self.updateWindowSize(windowSize: $0)
            },
            modifyWindowBaseSize: {
                return self.modifyWindowBaseSize(size: $0, windowSize: $1)
            },
            modifyWindowOriginalSize: { self.modifyWindowOriginalSize() },
            modifyWindowTopOffset: { self.modifyWindowTopOffset(offset: $0, windowSize: $1) }

        )
        floatingWindow.contentView = FirstMouseHostingView(rootView: notchView)
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

    private func modifyWindowTopOffset(offset: CGFloat, windowSize: WindowSize) {
        if windowSize == .chatIsExpanded {
            return
        }
        _ = updateWindowSize(windowSize: windowSize, offsetTopY: offset)
    }

    private func getWindowSize(windowSize: WindowSize) -> (CGFloat, CGFloat) {
        switch windowSize {
        case .notchIsCollapsed:
            return (60, 100)
        case .sidebarIsCollapsed:
            return (60, 160)
        case .sidebarIsExpanded:
            return (200, 600)
        case .chatIsShownSidebarIsCollapsed:
            return (width, height)
        case .chatIsShownSidebarIsExpanded:
            return (width + 200, height)
        case .chatIsExpanded:
            if let screen = screen {
                return (
                    min(screen.visibleFrame.maxX * 0.5, 1000),
                    min(screen.visibleFrame.maxY * 0.8, 1000)
                )
            }
            return (860, 600)
        }
    }

    private func updateWindowSize(
        windowSize: WindowSize,
        offsetTopY: CGFloat = 0,
        resetY: Bool = false
    ) -> (
        CGFloat,
        CGFloat
    ) {
        // Calculate new position to keep top-right corner fixed
        guard let screen = screen(for: floatingWindow) ?? currentAppScreen() else {
            return getWindowSize(windowSize: windowSize)
        }
        self.screen = screen

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

        lastWindowSize = windowSize

        return (windowWidth, windowHeight)
    }

    /// Screen that the given window is currently showing on.
    /// Prefers NSWindow.screen; falls back to largest-intersection if nil.
    private func screen(for window: NSWindow) -> NSScreen? {
        if let s = window.screen { return s }  // where AppKit says the window is
        // Fallback: pick the screen with the largest overlap with the window frame
        let f = window.frame
        return NSScreen.screens
            .map {
                ($0, f.intersection($0.visibleFrame).width * f.intersection($0.visibleFrame).height)
            }
            .max(by: { $0.1 < $1.1 })?.0
    }

    private func currentAppScreen() -> NSScreen? {
        if let w = NSApp.keyWindow ?? NSApp.mainWindow
            ?? NSApp.windows.first(where: { $0.isVisible })
        {
            return screen(for: w)
        }
        return nil
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
    private func startSelectionPoll() {
        pollingTimer?.cancel()

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: 0.5)
        timer.setEventHandler {
            if !AXIsProcessTrusted() {
                let opts: NSDictionary = [
                    kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true
                ]
                _ = AXIsProcessTrustedWithOptions(opts)
                return
            }
            Task {
                await self.setupSelection()
            }
        }
        pollingTimer = timer
        timer.resume()
    }

    private func setupSelection() async {
        do {
            // Try AXUI method first
            if let text = try await textManager.getSelectedTextByAX() {
                let sanitizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !sanitizedText.isEmpty {
                    DispatchQueue.main.async {
                        self.vm.updateSelectedText(text: sanitizedText)
                    }
                    return
                }
            }
        } catch {}

        do {
            // If AXUI fails or returns empty text, try menu action copy
            if let menuCopyText = try await textManager.getSelectedTextByMenuAction() {
                let sanitizedText = menuCopyText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !sanitizedText.isEmpty {
                    DispatchQueue.main.async {
                        self.vm.updateSelectedText(text: sanitizedText)
                    }
                    return
                }
            }
        } catch {}

        selectedText = ""
        selectionResetRequired = false
    }
}

final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var acceptsFirstResponder: Bool { true }
}
