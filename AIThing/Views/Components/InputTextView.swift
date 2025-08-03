//
//  InputTextView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import AppKit
import SwiftUI

struct InputTextView: NSViewRepresentable {
    @Binding var text: String
    var isNotEditable: Bool

    var onCommit: () -> Void
    var onCommandTyped: (String) -> Void = { _ in }
    var onCommandRemoved: (String) -> Void = { _ in }  // ← new
    var onDebouncedTextChange: (String) -> Void = { _ in }
    var onSpillover: (Int) -> Void = { _ in }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: InputTextView
        private var seenCommands = Set<String>()
        private var debounceWorkItem: DispatchWorkItem?
        private let debounceDelay: TimeInterval = 0.3

        init(_ parent: InputTextView) {
            self.parent = parent
        }

        func calculateLineCount(from textView: NSTextView) -> Int {
            guard let layoutManager = textView.layoutManager,
                let container = textView.textContainer
            else { return 0 }

            layoutManager.ensureLayout(for: container)
            let glyphRange = layoutManager.glyphRange(for: container)

            var lineCount = 0
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, _, _, _, _ in
                lineCount += 1
            }
            return lineCount
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string

            // Handle Return key (Commit)
            if let event = NSApp.currentEvent, event.type == .keyDown {
                if event.keyCode == 36, !event.modifierFlags.contains(.shift) {
                    // 36 = Return key
                    // Commit on plain Enter
                    let rawText = textView.string
                    let trimmed = rawText.trimmingCharacters(in: .newlines)
                    textView.string = trimmed
                    parent.text = trimmed

                    // Always update spillover on any text change
                    let lineCount = calculateLineCount(from: textView)
                    parent.onSpillover(lineCount)

                    parent.onCommit()
                    return
                }
            }

            // Always update spillover on any text change
            let lineCount = calculateLineCount(from: textView)
            parent.onSpillover(lineCount)

            // Handle @ or \command tracking
            let pattern = ##"[@\\#]([a-zA-Z]+)"##
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

            let removedCommands = seenCommands.subtracting(currentCommands)
            for command in removedCommands {
                parent.onCommandRemoved(command)
            }

            seenCommands = currentCommands

            // Debounced handler
            debounceWorkItem?.cancel()
            let workItem = DispatchWorkItem {
                self.parent.onDebouncedTextChange(self.parent.text)
            }
            debounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay, execute: workItem)
        }

        func textDidEndEditing(_ notification: Notification) {}
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        // Create text view scroll view
        let theTextView = NSTextView.scrollableTextView()
        theTextView.drawsBackground = false
        theTextView.hasVerticalScroller = false
        theTextView.hasHorizontalScroller = false
        theTextView.borderType = .noBorder

        let textView = (theTextView.documentView as! NSTextView)
        textView.delegate = context.coordinator

        textView.isEditable = !isNotEditable
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = .white
        textView.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        textView.textContainerInset = NSSize(width: 0, height: 5)

        if let container = textView.textContainer {
            container.widthTracksTextView = true
            container.lineBreakMode = .byWordWrapping
        }

        // Set initial text
        textView.string = text

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        return theTextView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            if textView.string != text {
                textView.string = text
            }
            textView.isEditable = !isNotEditable
        }
    }
}
