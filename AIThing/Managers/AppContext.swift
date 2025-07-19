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
    @Published var windowName: String = ""
    @Published var visibleText: String = ""
    @Published var clipboardText: String = ""

    @Published var mcpClientManager: MCPClientManager?

    private var lastVisibleTime: Date?

    func markAppVisible() {
        lastVisibleTime = Date()
    }

    func mcpStatus() -> McpStatus {
        switch self.appName.lowercased() {
        case "macos", "xcode":
            return .available
        default:
            return .unavailable
        }
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
        if AXUIElementCopyAttributeValue(
            axApp,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        ) == .success,
            let element = focusedElement
        {

            var selectedTextValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(
                element as! AXUIElement,
                kAXSelectedTextAttribute as CFString,
                &selectedTextValue
            ) == .success,
                let selectedText = selectedTextValue as? String
            {
                return selectedText
            }
        }

        return nil
    }

    func refresh() {
        let context = getAppContext()
        self.appName = context.appName
        self.visibleText = context.visibleText
        self.windowName = context.windowTitle
    }

    private func getAppContext() -> (appName: String, windowTitle: String, visibleText: String) {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return ("", "", "")
        }

        let appName = frontApp.localizedName ?? ""
        let pid = frontApp.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)

        var focusedWindow: AnyObject?
        let windowResult = AXUIElementCopyAttributeValue(
            axApp,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        guard windowResult == .success, let window = focusedWindow else {
            return (appName, "", "")
        }

        // Try to get the window title
        var titleValue: AnyObject?
        var windowTitle = ""
        if AXUIElementCopyAttributeValue(
            window as! AXUIElement,
            kAXTitleAttribute as CFString,
            &titleValue
        ) == .success,
            let title = titleValue as? String
        {
            windowTitle = title
        }

        // Recursively extract visible text from focused window
        let visibleText = extractText(from: window as! AXUIElement)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (appName, windowTitle, visibleText)
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
