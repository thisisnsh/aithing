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
    private var floatingWindow: NonActivatingPanel!
    private var floatingActionWindow: NonActivatingPanel!

    private var escMonitor: Any?
    private var globalMouseMonitor: Any?
    private var hotKey: HotKey?

    private let width: CGFloat = 1500
    private let height: CGFloat = 1000

    private let miniWidth: CGFloat = 16
    private let miniHeight: CGFloat = 16
    private let miniWidthExpanded: CGFloat = 320
    private let miniHeightExpanded: CGFloat = 320
    private let miniHeightInput: CGFloat = 48

    static var allowQuit = false

    private let screenshotManager = ScreenshotManager()

    private var selectionResetRequired = false
    private let textManager = SelectedTextManager.shared
    private var selectedText: String = ""
    private var pollingTimer: DispatchSourceTimer?
    private var mouseLocation = NSEvent.mouseLocation

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
        // startSelectionPoll()
        // startGlobalInput()

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
        stopGlobalInput()
    }

    func setupWindow() {
        let contentView = ContentView(
            onClose: { self.toggleWindow() },
            resetSize: {
                let targetSize = NSSize(width: self.width, height: self.height)
                var frame = self.floatingWindow.frame
                frame.size = targetSize
                self.floatingWindow.setFrame(frame, display: true, animate: false)
            },
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

        let size = NSSize(width: miniWidth, height: miniHeight)
        let contentView = MiniTabView(
            onClick: {
                return self.selectedText
            },
            onClose: { self.closeActiveWindow() },
            onSetting: {},
            expandSize: { response in
                let targetSize = NSSize(
                    width: self.miniWidthExpanded,
                    height: response ? self.miniHeightExpanded : self.miniHeightInput
                )
                var frame = self.floatingActionWindow.frame
                frame.origin.y += (frame.size.height - self.miniWidthExpanded)
                frame.size = targetSize
                self.floatingActionWindow.setFrame(frame, display: true, animate: false)
            },
            setPanelPassthrough: { self.setPanelPassthrough($0) }
        )

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(origin: .zero, size: size)

        let panel = NonActivatingPanel(contentRect: NSRect(origin: .zero, size: size))
        panel.contentView = hostingView
        panel.isReleasedWhenClosed = false

        // Location of first click
        let cursor = mouseLocation
        let origin = NSPoint(
            x: cursor.x - size.width / 2 - 48,
            y: cursor.y - size.height / 2
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
        panel.orderFrontRegardless()

        floatingActionWindow = panel
        floatingActionWindow.backgroundColor = .red
        setPanelVisibility()
    }

    private func updateFloatingActiveWindowSizeFromCurrent(width: CGFloat, height: CGFloat) {
        guard let floatingActionWindow = floatingActionWindow else { return }
        // Updates the floating window size by adding extra height while keeping the top edge aligned
        var frame = floatingActionWindow.frame
        let targetSize = NSSize(width: frame.width + width, height: frame.height + height)

        frame.origin.y += (frame.size.height - targetSize.height)  // keep top aligned
        frame.size = targetSize

        if frame.origin.y > 0 {
            floatingActionWindow.setFrame(frame, display: true, animate: false)
        }
    }

    private func closeActiveWindow() {
        selectionResetRequired = true
        if let panel = floatingActionWindow {
            panel.close()
            floatingActionWindow = nil
        }
    }

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

/// Functions for Global Events
extension AppDelegate {
    private func requestAXIfNeeded() {
        let options =
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func startGlobalInput() {
        stopGlobalInput()  // idempotent
        requestAXIfNeeded()

        escMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {  // 53 = Escape
                self?.closeActiveWindow()
            }
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) {
            [weak self] _ in
            self?.saveMouseCoordinates()
        }
    }

    private func stopGlobalInput() {
        if let monitor = globalMouseMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = escMonitor { NSEvent.removeMonitor(monitor) }
        globalMouseMonitor = nil
        escMonitor = nil
    }

    private func saveMouseCoordinates() {
        mouseLocation = NSEvent.mouseLocation
    }
}
