//
//  InputTextView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import AppKit
import SwiftUI

struct InputTextView: NSViewRepresentable {
    // MARK: - Bindings
    @Binding var text: String
    @Binding var seenCommands: Set<String>
    @Binding var size: CGFloat

    // MARK: - Constants & Closures
    var isNotEditable: Bool
    var onCommit: () -> Void
    var onCommandTyped: (String) -> Void = { _ in }
    var onCommandRemoved: (String) -> Void = { _ in }
    var onDebouncedTextChange: (String) -> Void = { _ in }
    var onSpillover: (Int) -> Void = { _ in }

    // MARK: - Coordinator
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: InputTextView
        private var debounceWorkItem: DispatchWorkItem?
        private let debounceDelay: TimeInterval = 0.3

        init(_ parent: InputTextView) {
            self.parent = parent
        }

        private func commit(from textView: NSTextView) {
            let rawText = textView.string
            let trimmed = rawText.trimmingCharacters(in: .newlines)
            if trimmed != rawText {
                textView.string = trimmed
            }
            parent.text = trimmed

            let lineCount = calculateLineCount(from: textView)
            parent.onSpillover(lineCount)

            parent.onCommit()
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Shift+Enter in AppKit usually maps to insertLineBreak:
            if commandSelector == #selector(NSResponder.insertLineBreak(_:)) {
                // Allow normal newline behavior for Shift+Enter
                return false
            }

            // Plain Enter is insertNewline: (and sometimes insertNewlineIgnoringFieldEditor:)
            if commandSelector == #selector(NSResponder.insertNewline(_:))
                || commandSelector == #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:))
            {
                // If Shift is held, let it fall through (safety check for some keyboards)
                if NSEvent.modifierFlags.contains(.shift) {
                    return false
                }

                // Consume the command and commit instead of inserting a newline
                commit(from: textView)
                return true
            }

            // Anything else: default handling
            return false
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
            applyCommandHighlighting(to: textView)

            // Always update spillover on any text change
            let lineCount = calculateLineCount(from: textView)
            parent.onSpillover(lineCount)

            // Handle @ or \command tracking
            // let pattern = ##"[@\\#]([a-zA-Z]+)"##
            let pattern = #"(?i)(?<!\w)@(?:aithing)(?!\w)"#
            let regex = try? NSRegularExpression(pattern: pattern)
            let nsrange = NSRange(parent.text.startIndex..<parent.text.endIndex, in: parent.text)

            var currentCommands = Set<String>()

            regex?.matches(in: parent.text, options: [], range: nsrange).forEach { match in
                if let wordRange = Range(match.range, in: parent.text) {
                    let command = String(parent.text[wordRange]).lowercased()  // normalize if you want
                    currentCommands.insert(command)

                    if !parent.seenCommands.contains(command) {
                        parent.onCommandTyped(command)
                    }
                }
            }

            let removedCommands = parent.seenCommands.subtracting(currentCommands)
            for command in removedCommands {
                parent.onCommandRemoved(command)
            }

            parent.seenCommands = currentCommands

            // Debounced handler
            debounceWorkItem?.cancel()
            let workItem = DispatchWorkItem {
                self.parent.onDebouncedTextChange(self.parent.text)
            }
            debounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay, execute: workItem)
        }

        func textDidEndEditing(_ notification: Notification) {}

        func applyCommandHighlighting(to textView: NSTextView) {
            let fullText = textView.string
            let baseFont = NSFont.systemFont(ofSize: parent.size, weight: .medium)

            let attributedText = NSMutableAttributedString(
                string: fullText,
                attributes: [
                    .font: baseFont,
                    .foregroundColor: NSColor.white,
                ]
            )

            let pattern = #"(?i)(?<!\w)@(?:aithing)(?!\w)"#
            if let regex = try? NSRegularExpression(pattern: pattern) {
                // Get the full range of the text for regex matching
                let nsrange = NSRange(fullText.startIndex..<fullText.endIndex, in: fullText)

                // Find all matches of the pattern in the text
                for match in regex.matches(in: fullText, range: nsrange) {
                    // Use monospaced font for matched text
                    let monoFont = NSFont.monospacedSystemFont(
                        ofSize: parent.size - 2,
                        weight: .medium
                    )

                    // Calculate baseline shift to visually center it with the base font
                    let baselineShift = (baseFont.capHeight - monoFont.capHeight) / 2

                    // Apply styling attributes to the matched range
                    attributedText.addAttributes(
                        [
                            .font: monoFont,
                            .foregroundColor: NSColor.white.withAlphaComponent(0.7),
                            .baselineOffset: baselineShift,
                        ],
                        range: match.range
                    )
                }
            }

            // Preserve cursor position
            let selectedRange = textView.selectedRange()
            textView.textStorage?.setAttributedString(attributedText)
            textView.setSelectedRange(selectedRange)
        }

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
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = .white
        textView.font = NSFont.systemFont(ofSize: size, weight: .medium)
        textView.textContainerInset = NSSize(width: 0, height: 5)

        if let container = textView.textContainer {
            container.widthTracksTextView = true
            container.lineBreakMode = .byWordWrapping
        }

        // Set initial text
        textView.string = text

        context.coordinator.applyCommandHighlighting(to: textView)

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

