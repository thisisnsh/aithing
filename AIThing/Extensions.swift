//
//  Extensions.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
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
