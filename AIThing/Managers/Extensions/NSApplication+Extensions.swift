//
//  NSApplication+Extensions.swift
//  AIThing
//
//  NSApplication extension utilities.
//

import AppKit
import Foundation

extension NSApplication {
    var keyWindow: NSWindow? {
        return NSApplication.shared.windows.first { $0.isKeyWindow }
    }
}

