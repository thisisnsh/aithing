//
//  AppDelegate.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import AppKit
import ApplicationServices
import Cocoa
import FirebaseAuth
import FirebaseCore
import HotKey
import Logging
import OAuthSwift
import SelectedTextKit
import ServiceManagement
import SwiftUI
import os

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var floatingWindow: NonActivatingPanel!
    var floatingActionWindow: NonActivatingPanel!

    var hotKey: HotKey?

    let width: CGFloat = 1500
    let height: CGFloat = 96

    static var allowQuit = false

    let screenshotManager = ScreenshotManager()
    var selectionResetRequired = false

    private let textManager = SelectedTextManager.shared
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var selectedText: String = ""
    private var pollingTimer: DispatchSourceTimer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)  // background-style app

        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = .info
            return handler
        }

        FirebaseApp.configure()

        setupWindow()
        setupHotKey()
        startSelectionPoll()

        try? SMAppService.mainApp.register()

    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { OAuthSwift.handle(url: url) }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return AppDelegate.allowQuit ? .terminateNow : .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        pollingTimer?.cancel()
        pollingTimer = nil
    }

    func setupWindow() {
        let contentView = ContentView(
            onClose: { self.toggleWindow() },
            updatePanelSizeFromDefault: { extraHeight in
                self.updatePanelSizeFromDefault(extraHeight: extraHeight)
            },
            updatePanelSizeFromCurrent: { extraHeight in
                return self.updatePanelSizeFromCurrent(extraHeight: extraHeight)
            },
            getExtraSize: { return self.getExtraPanelSizeFromDefault() },
            setPanelVisibility: { return self.setPanelVisibility() },
            setPanelPassthrough: { self.setPanelPassthrough($0) }
        )
        .environmentObject(screenshotManager)

        let hostingView = NSHostingView(rootView: contentView)

        floatingWindow = NonActivatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height)
        )
        floatingWindow.contentView = hostingView
        floatingWindow.alphaValue = 1
        floatingWindow.center()
        floatingWindow.orderFrontRegardless()  // no app activation

        setPanelVisibility()
    }

    func setupHotKey() {
        hotKey = HotKey(key: .space, modifiers: [.control])
        hotKey?.keyDownHandler = { [weak self] in
            self?.toggleWindow()
        }
    }

    func toggleWindow() {
        self.screenshotManager.cancelScreenshot()

        if floatingWindow.isVisible {
            let origin = floatingWindow.frame.origin
            UserDefaults.standard.set(origin.x, forKey: "FloatingPanelOriginX")
            UserDefaults.standard.set(origin.y, forKey: "FloatingPanelOriginY")

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                floatingWindow.animator().alphaValue = 0
            } completionHandler: {
                self.floatingWindow.orderOut(nil)
            }
        } else {
            if let x = UserDefaults.standard.value(forKey: "FloatingPanelOriginX") as? CGFloat,
                let y = UserDefaults.standard.value(forKey: "FloatingPanelOriginY") as? CGFloat
            {
                floatingWindow.setFrameOrigin(NSPoint(x: x, y: y))
            } else {
                floatingWindow.center()
            }
            floatingWindow.alphaValue = 0
            floatingWindow.makeKeyAndOrderFront(nil)

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                floatingWindow.animator().alphaValue = 1
            }

            AnalyticsManager.shared.appOpen()
        }
    }
}

/// Floating Action Window
extension AppDelegate {

    private func setupActionWindow() {
        if floatingActionWindow != nil {
            return
        }
        if selectionResetRequired {
            return
        }

        let size = NSSize(width: 24 + 32 + 8 + 200 + 8 + 18 + 24, height: 48)
        let contentView = MiniTabView(
            onClick: { return self.selectedText },
            onClose: { self.closeActiveWindow() },
            onSetting: {},
            setPanelPassthrough: { self.setPanelPassthrough($0) }
        )
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(origin: .zero, size: size)

        let panel = NonActivatingPanel(contentRect: NSRect(origin: .zero, size: size))
        panel.contentView = hostingView
        panel.isReleasedWhenClosed = false

        let cursor = NSEvent.mouseLocation
        let origin = NSPoint(
            x: cursor.x - size.width / 2,
            y: cursor.y - size.height / 2
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: false)

        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)

        floatingActionWindow = panel
        setPanelVisibility()
    }

    private func closeActiveWindow() {
        selectionResetRequired = true
        floatingActionWindow.close()
        floatingActionWindow = nil
    }

    private func startSelectionPoll() {
        pollingTimer?.cancel()

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: 1.0)
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
                    selectedText = sanitizedText
                    await MainActor.run {
                        setupActionWindow()
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
                    selectedText = sanitizedText
                    await MainActor.run {
                        setupActionWindow()
                    }
                    return
                }
            }
        } catch {}

        selectedText = ""
        selectionResetRequired = false
    }
}

/// Size Functinos
extension AppDelegate {

    private func updatePanelSizeFromDefault(extraHeight: CGFloat) {
        let targetSize = NSSize(width: width, height: height + extraHeight)

        var frame = floatingWindow.frame
        frame.origin.y += (frame.size.height - targetSize.height)  // keep top aligned
        frame.size = targetSize

        floatingWindow.setFrame(frame, display: true, animate: false)
    }

    private func updatePanelSizeFromCurrent(extraHeight: CGFloat) {
        // Updates the floating window size by adding extra height while keeping the top edge aligned
        var frame = floatingWindow.frame
        let targetSize = NSSize(width: frame.width, height: frame.height + extraHeight)

        frame.origin.y += (frame.size.height - targetSize.height)  // keep top aligned
        frame.size = targetSize

        if frame.origin.y > 0 {
            floatingWindow.setFrame(frame, display: true, animate: false)
        }
    }

    /// Returns the extra panel height by calculating the difference between the floating window's current height and the base height
    private func getExtraPanelSizeFromDefault() -> CGFloat {
        let frame = floatingWindow.frame
        return frame.size.height - height
    }

    /// Sets the panel visibility in screenshots based on user preferences
    /// Uses readOnly sharing type to show the panel, or none to hide it from screenshots
    private func setPanelVisibility() {
        if let floatingWindow = floatingWindow {
            floatingWindow.sharingType = getPreferencesShowInScreenshot() ? .readOnly : .none
        }
        if let floatingActionWindow = floatingActionWindow {
            floatingActionWindow.sharingType = getPreferencesShowInScreenshot() ? .readOnly : .none
        }
    }

    private func setPanelPassthrough(_ enabled: Bool) {
        // true  -> panel ignores events (clicks pass through)
        // false -> panel receives events (interactive)
        if let floatingWindow = floatingWindow {
            floatingWindow.ignoresMouseEvents = enabled
        }
        if let floatingActionWindow = floatingActionWindow {
            floatingActionWindow.ignoresMouseEvents = enabled
        }
    }

}
