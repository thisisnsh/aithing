//
//  TypingManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/18/25.
//

import AppKit
import ApplicationServices
import Foundation

final class TypingManager {
    static let shared = TypingManager()
    private init() {}

    private let typingQueue = DispatchQueue(label: "TypingManager.TypingQueue")
    private var typingSession = 0  // allows canceling older runs if a new one starts

    func cancelTyping() {
        typingQueue.async(flags: .barrier) {
            self.typingSession += 1
        }
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

    func requestAXIfNeeded() {
        let options =
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func typeText(_ text: String) {
        typingSession += 1
        let session = typingSession

        // Split into lines
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

        var delay: TimeInterval = 0

        for (index, line) in lines.enumerated() {
            let chunk = String(line) + (index < lines.count - 1 ? "\n" : "")

            typingQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, self.typingSession == session else { return }
                self.postUnicode(chunk)
            }

            // fixed pause between lines (you can tweak)
            delay += 0.2
        }
    }

    /// Posts a single “typed” Unicode chunk via CGEvents.
    private func postUnicode(_ s: String) {
        guard let src = CGEventSource(stateID: .hidSystemState) else { return }
        let units = Array(s.utf16)

        units.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            let count = buf.count

            if let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true) {
                down.flags = []  // don’t inherit real modifiers
                down.keyboardSetUnicodeString(stringLength: count, unicodeString: base)
                down.post(tap: .cgAnnotatedSessionEventTap)
            }
            if let up = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false) {
                up.flags = []
                up.keyboardSetUnicodeString(stringLength: count, unicodeString: base)
                up.post(tap: .cgAnnotatedSessionEventTap)
            }
        }
    }

}
