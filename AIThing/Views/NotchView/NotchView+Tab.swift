//
//  NotchView+Tab.swift
//  AIThing
//
//  Tab management extension for NotchView.
//

import SwiftUI

// MARK: - Tab Management
extension NotchView {
    func addTab(_ tab: TabItem) {
        let id = tab.id

        // Always update or insert the tab
        tabs[id] = tab

        // If the ID already exists, do not duplicate or move its position
        guard !tabOrder.contains(id) else { return }

        // Insert at end
        tabOrder.append(id)

        // Enforce max tab count
        if tabOrder.count > maxTabs {
            let removedId = tabOrder.removeFirst()
            tabs.removeValue(forKey: removedId)
        }
    }

    func removeTab(id: String) {
        tabs.removeValue(forKey: id)
        tabOrder.removeAll { $0 == id }
    }

    func printTabs() {
        logger.debug("\(tabs.keys)")
    }

    func isTabShowing(tabId: String) -> Bool {
        return tabId == self.focusedTabId && showChatWindow && !showSettings
    }

    func isTabRemoved(tabId: String) -> Bool {
        !tabs.keys.contains(tabId)
    }
}

