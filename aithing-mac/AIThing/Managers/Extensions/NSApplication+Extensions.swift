//
//  NSApplication+Extensions.swift
//  AIThing
//
//  Created by Nishant Singh Hada.
//

import AppKit
import Foundation

extension NSApplication {
    var keyWindow: NSWindow? {
        return NSApplication.shared.windows.first { $0.isKeyWindow }
    }

    static func forceDarkMode() {
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }
}
