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

    let width: CGFloat = 1000
    let height: CGFloat = 96

    let mcp = MCPManager()

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
            onSizeChange: { extraHeight in
                self.resizePanel(extraHeight: extraHeight)
            },
            incrementSizePanel: { extraHeight in
                return self.incrementSizePanel(extraHeight: extraHeight)
            },
            getExtraSize: { return self.getExtraHeightPanel() }
        ).environmentObject(mcp)

        let hostingView = NSHostingView(rootView: contentView)

        floatingWindow = NonActivatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height)
        )
        floatingWindow.contentView = hostingView
        floatingWindow.alphaValue = 1
        floatingWindow.center()
        floatingWindow.orderFrontRegardless()  // no app activation
        floatingWindow.sharingType = .none

        Task {
            for client in mcp.clients.keys {
                await mcp.connect(clientName: client)
            }
        }
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

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                floatingWindow.animator().alphaValue = 1
            }
        }
    }

    func resizePanel(extraHeight: CGFloat) {
        let targetSize = NSSize(width: width, height: height + extraHeight)

        var frame = floatingWindow.frame
        frame.origin.y += (frame.size.height - targetSize.height)  // keep top aligned
        frame.size = targetSize

        floatingWindow.setFrame(frame, display: true, animate: false)
    }

    func incrementSizePanel(extraHeight: CGFloat) {
        var frame = floatingWindow.frame
        let targetSize = NSSize(width: frame.width, height: frame.height + extraHeight)

        frame.origin.y += (frame.size.height - targetSize.height)  // keep top aligned
        frame.size = targetSize

        floatingWindow.setFrame(frame, display: true, animate: false)
    }

    func getExtraHeightPanel() -> CGFloat {
        let frame = floatingWindow.frame
        return frame.size.height - height
    }
}
