//
//  AppContext.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import AppKit
import Foundation

enum McpStatus {
    case available
    case unavailable
}

class AppContext: ObservableObject {
    @Published var appName: String = ""
    @Published var visibleText: String = ""
    @Published var clipboardText: String = ""
    @Published var mcpStatus: McpStatus = .unavailable

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
}
