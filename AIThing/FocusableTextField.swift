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

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: FocusableTextField

        init(_ parent: FocusableTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
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
        let textField = NSTextField(string: text)
        textField.delegate = context.coordinator

        textField.isBordered = false
        textField.drawsBackground = false  // transparent background
        textField.backgroundColor = .clear
        textField.textColor = .white  // white font
        textField.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        textField.focusRingType = .none
        textField.isEditable = true
        textField.isSelectable = true
        textField.placeholderString = "Ask anything to this AI thing..."

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
