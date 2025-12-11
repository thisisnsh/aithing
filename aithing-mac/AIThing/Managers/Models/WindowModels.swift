//
//  WindowModels.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 12/4/25.
//

import Foundation
import SwiftUI

enum WindowSize: Int {
    case collapsed = 0
    case expanded = 1
}

enum OutOfBoundsEdge: String {
    case left
    case right
    case top
    case bottom
}

final class NotchViewModel: ObservableObject {
    @Published var openClose = false
    @Published var move = false
    @Published var selectedText = ""
    @Published var selectionPolling = false

    func triggerOpenClose() { openClose.toggle() }
    func triggerMove() { move.toggle() }
    
    func updateSelectedText(text: String) { selectedText = text }    
    func updateSelectionPolling(value: Bool) { selectionPolling = value }
}
