//
//  WindowModels.swift
//  AIThing
//
//  Models for window management.
//

import Foundation
import SwiftUI

enum WindowSize: Int {
    case notchIsCollapsed = 0
    case sidebarIsCollapsed = 1
    case sidebarIsExpanded = 2
    case chatIsShown = 3
    case chatIsExpanded = 4
}

enum OutOfBoundsEdge: String {
    case left
    case right
    case top
    case bottom
}

final class NotchViewModel: ObservableObject {
    @Published var refresh = false
    @Published var minimize = false
    @Published var open = false
    @Published var toggle = false
    @Published var selectedText = ""
    @Published var selectionPolling = false
    @Published var move = false

    func refreshDimensions() { refresh.toggle() }
    func minimizeDimensions() { minimize.toggle() }
    func openDimensions() { open.toggle() }
    func toggleDimensions() { toggle.toggle() }
    func updateSelectedText(text: String) { selectedText = text }
    func toggleMove() { move.toggle() }
    func updateSelectionPolling(value: Bool) { selectionPolling = value }
}

