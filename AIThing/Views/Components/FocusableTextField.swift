//
//  FocusableTextField.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import AppKit
import SwiftUI

struct FocusableTextField: NSViewRepresentable {
    @Binding var text: String
    var onCommit: () -> Void
    var onCommandTyped: (String) -> Void = { _ in }
    var onCommandRemoved: (String) -> Void = { _ in }  // ← new

    class NonSelectingTextField: NSTextField {
        override func selectText(_ sender: Any?) {
            // Do nothing to prevent auto-selection
        }
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: FocusableTextField
        private var seenCommands = Set<String>()

        init(_ parent: FocusableTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue

            let pattern = #"\\([a-zA-Z]+)"#
            let regex = try? NSRegularExpression(pattern: pattern)
            let nsrange = NSRange(parent.text.startIndex..<parent.text.endIndex, in: parent.text)

            var currentCommands = Set<String>()

            regex?.matches(in: parent.text, options: [], range: nsrange).forEach { match in
                if let wordRange = Range(match.range(at: 1), in: parent.text) {
                    let command = String(parent.text[wordRange])
                    currentCommands.insert(command)

                    if !seenCommands.contains(command) {
                        parent.onCommandTyped(command)
                    }
                }
            }

            // Detect removed commands
            let removedCommands = seenCommands.subtracting(currentCommands)
            for command in removedCommands {
                parent.onCommandRemoved(command)
            }

            // Update state
            seenCommands = currentCommands
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            let reason = (obj.userInfo?["NSTextMovement"] as? Int) ?? -1
            if reason == NSReturnTextMovement {
                parent.onCommit()
            }
        }

    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NonSelectingTextField(string: text)
        textField.delegate = context.coordinator

        textField.isBordered = false
        textField.drawsBackground = false  // transparent background
        textField.backgroundColor = .clear
        textField.textColor = .white  // white font
        textField.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        textField.focusRingType = .none
        textField.isEditable = true
        textField.isSelectable = true
        textField.isHighlighted = false

        let placeholder = "Ask anything on this AI thing..."
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white.withAlphaComponent(0.7),
            .font: NSFont.systemFont(ofSize: 18, weight: .medium),
        ]

        textField.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: attributes
        )

        DispatchQueue.main.async {
            textField.becomeFirstResponder()
        }

        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
}
