//
//  AppDelegate.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import AppKit
import ApplicationServices
import Cocoa
import HotKey
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var floatingWindow: NonActivatingPanel!
    var hotKey: HotKey?

    let width = 640
    let height = 100

    let appContext = AppContext()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)  // background-style app

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        setupWindow()
        setupHotKey()
    }

    @objc func appDidActivate(_ note: Notification) {
        let context = getAppContext()
        DispatchQueue.main.async {
            self.appContext.appName = context.appName
            self.appContext.visibleText = context.visibleText
            self.appContext.clearClipboardText()  // ⬅️ clear clipboard context
        }
    }

    func setupWindow() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        let contentView = ContentView(
            onClose: { self.toggleWindow() },
            onSizeChange: { expanded in
                self.resizePanel(expanded: expanded)
            }
        ).environmentObject(appContext)

        let hostingView = NSHostingView(rootView: contentView)

        floatingWindow = NonActivatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height)
        )
        floatingWindow.contentView = hostingView
        floatingWindow.alphaValue = 1
        floatingWindow.center()
        floatingWindow.orderFrontRegardless()  // no app activation
    }

    func setupHotKey() {
        hotKey = HotKey(key: .space, modifiers: [.control])
        hotKey?.keyDownHandler = { [weak self] in
            self?.toggleWindow()
        }
    }

    func toggleWindow() {
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

            appContext.markAppVisible()
            appContext.updateClipboardIfRecent()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                floatingWindow.animator().alphaValue = 1
            }
        }
    }

    func resizePanel(expanded: Bool) {
        let targetSize = NSSize(width: width, height: expanded ? height + 200 : height)

        var frame = floatingWindow.frame
        frame.origin.y += frame.size.height - targetSize.height  // keep top aligned
        frame.size = targetSize

        floatingWindow.setFrame(frame, display: true, animate: false)
    }

    func getAppContext() -> (appName: String, visibleText: String) {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return ("Unknown App", "")
        }

        let appName = frontApp.localizedName ?? "Unknown App"
        let pid = frontApp.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)

        var focusedWindow: AnyObject?
        let windowResult = AXUIElementCopyAttributeValue(
            axApp,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        guard windowResult == .success, let window = focusedWindow else {
            return (appName, "")
        }

        // Recursively extract visible text from focused window
        let visibleText = extractText(from: window as! AXUIElement)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (appName, visibleText)
    }

    private func extractText(from element: AXUIElement) -> [String] {
        var result: [String] = []

        var children: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
            == .success,
            let childArray = children as? [AXUIElement]
        {
            for child in childArray {
                var value: AnyObject?

                // Try reading the value directly (AXValue)
                if AXUIElementCopyAttributeValue(child, kAXValueAttribute as CFString, &value)
                    == .success,
                    let string = value as? String
                {
                    result.append(string)
                }

                // Also try the title if present
                if AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &value)
                    == .success,
                    let string = value as? String
                {
                    result.append(string)
                }

                // Recurse
                result.append(contentsOf: extractText(from: child))
            }
        }

        return result
    }
}
