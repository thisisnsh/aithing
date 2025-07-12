//
//  AppDelegate.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import Cocoa
import HotKey
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var floatingWindow: NonActivatingPanel!
    var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)  // background-style app

        setupWindow()
        setupHotKey()
    }

    func setupWindow() {
        let contentView = FloatingTextBoxView {
            self.floatingWindow.orderOut(nil)
        }

        let hostingView = NSHostingView(rootView: contentView)

        floatingWindow = NonActivatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 64)
        )
        floatingWindow.contentView = hostingView
        floatingWindow.alphaValue = 0
        floatingWindow.center()
        floatingWindow.orderFrontRegardless()  // no app activation
    }

    func setupHotKey() {
        hotKey = HotKey(key: .space, modifiers: [.control])
        hotKey?.keyDownHandler = { [weak self] in
            self?.logFrontmostApp()  // ✅ Log before showing
            self?.toggleWindow()
            print("App is active? \(NSApp.isActive)")
        }
    }

    func toggleWindow() {
        if floatingWindow.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                floatingWindow.animator().alphaValue = 0
            } completionHandler: {
                self.floatingWindow.orderOut(nil)
            }
        } else {
            floatingWindow.alphaValue = 0
            floatingWindow.center()
            floatingWindow.makeKeyAndOrderFront(nil)

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                floatingWindow.animator().alphaValue = 1
            }
        }
    }

    func logFrontmostApp() {
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            print("✅ Frontmost App: \(frontApp.localizedName ?? "Unknown")")
        }
    }
}
