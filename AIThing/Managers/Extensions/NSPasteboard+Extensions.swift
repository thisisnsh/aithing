//
//  NSPasteboard+Extensions.swift
//  AIThing
//
//  NSPasteboard extension utilities.
//

import AppKit
import Foundation

extension NSPasteboard {
    private static var lastKnownChangeCount: Int = 0
    private static var lastChangeTime: Date?

    func changeCountTimestamp() -> Date? {
        if changeCount != Self.lastKnownChangeCount {
            Self.lastKnownChangeCount = changeCount
            Self.lastChangeTime = Date()
        }
        return Self.lastChangeTime
    }
}

