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

    func getSelectedText() -> String? {
        requestAXIfNeeded()

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

    private var typingText: String = ""
    func typeText(_ text: String) {
        typingText += text
        if !typingText.contains("\n") { return }

        // Split into lines
        let lines = stripCodeBlock(from: typingText).split(
            separator: "\n",
            omittingEmptySubsequences: false
        )

        for (index, line) in lines.enumerated() {
            let chunk = String(line) + (index < lines.count - 1 ? "\n" : "")

            typingQueue.sync { [weak self] in
                guard let self = self else { return }
                self.postUnicode(chunk)
            }

        }

        typingText = ""
    }

    func endTypeText() {
        self.postEnter()
        typingText = ""
    }

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

    private func postEnter() {
        guard let src = CGEventSource(stateID: .hidSystemState) else { return }
        if let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 36, keyDown: true) {
            keyDown.flags = []
            keyDown.post(tap: .cgAnnotatedSessionEventTap)
        }
        if let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 36, keyDown: false) {
            keyUp.flags = []
            keyUp.post(tap: .cgAnnotatedSessionEventTap)
        }
    }

    func stripCodeBlock(from text: String) -> String {
        // Regex matches:
        // - opening ``` + optional word + newline
        // - closing ```
        let pattern = #"^```[\w]*\n|\n```$"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }

}
