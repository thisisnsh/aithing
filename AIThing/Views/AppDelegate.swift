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
import ServiceManagement
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var floatingWindow: NonActivatingPanel!
    var hotKey: HotKey?

    let width: CGFloat = 1400
    let height: CGFloat = 96

    static var allowQuit = false

    let mcp = MCPManager()
    let screenshotManager = ScreenshotManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)  // background-style app

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        FirebaseApp.configure()

        setupWindow()
        setupHotKey()

        try? SMAppService.mainApp.register()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return AppDelegate.allowQuit ? .terminateNow : .terminateCancel
    }

    @objc func appDidActivate(_ note: Notification) {}

    func setupWindow() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

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
        .environmentObject(mcp)
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

    func updatePanelSizeFromDefault(extraHeight: CGFloat) {
        let targetSize = NSSize(width: width, height: height + extraHeight)

        var frame = floatingWindow.frame
        frame.origin.y += (frame.size.height - targetSize.height)  // keep top aligned
        frame.size = targetSize

        floatingWindow.setFrame(frame, display: true, animate: false)
    }

    func updatePanelSizeFromCurrent(extraHeight: CGFloat) {
        // Updates the floating window size by adding extra height while keeping the top edge aligned
        var frame = floatingWindow.frame
        let targetSize = NSSize(width: frame.width, height: frame.height + extraHeight)
        
        frame.origin.y += (frame.size.height - targetSize.height)  // keep top aligned
        frame.size = targetSize
        
        floatingWindow.setFrame(frame, display: true, animate: false)
    }

    /// Returns the extra panel height by calculating the difference between the floating window's current height and the base height
    func getExtraPanelSizeFromDefault() -> CGFloat {
        let frame = floatingWindow.frame
        return frame.size.height - height
    }

    /// Sets the panel visibility in screenshots based on user preferences
    /// Uses readOnly sharing type to show the panel, or none to hide it from screenshots
    func setPanelVisibility() {
        floatingWindow.sharingType = getPreferencesShowInScreenshot() ? .readOnly : .none
    }

    func setPanelPassthrough(_ enabled: Bool) {
        // true  -> panel ignores events (clicks pass through)
        // false -> panel receives events (interactive)
        floatingWindow.ignoresMouseEvents = enabled
    }
}


