//
//  Extensions.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import AppKit
import Foundation
import MarkdownUI

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

extension Theme {
  static let fancy = Theme()
    .code {
      FontFamilyVariant(.monospaced)
      FontSize(.em(0.85))
    }
    .link {
      ForegroundColor(.purple)
    }
    
    // More block styles...
}
