//
//  AppContext.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import AppKit
import ApplicationServices
import Foundation

enum McpStatus {
    case available
    case unavailable
}

class AppContext: ObservableObject {
    @Published var appName: String = ""
    @Published var visibleText: String = ""
    @Published var clipboardText: String = ""
    @Published var mcpStatus: McpStatus = .available
    @Published var mcpClientManager: MCPClientManager?

    private var lastVisibleTime: Date?

    func markAppVisible() {
        lastVisibleTime = Date()
    }

    func updateClipboardIfRecent() {
        guard let lastVisibleTime else { return }

        let pasteboard = NSPasteboard.general
        guard let copied = pasteboard.string(forType: .string),
            let changeTime = pasteboard.changeCountTimestamp(),
            changeTime > lastVisibleTime
        else {
            return
        }

        DispatchQueue.main.async {
            self.clipboardText = copied
        }
    }

    func clearClipboardText() {
        clipboardText = ""
    }

    func getSelectedText() -> String? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let pid = frontApp.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)

        var focusedElement: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
           let element = focusedElement {
            
            var selectedTextValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedTextValue) == .success,
               let selectedText = selectedTextValue as? String {
                return selectedText
            }
        }

        return nil
    }

}
