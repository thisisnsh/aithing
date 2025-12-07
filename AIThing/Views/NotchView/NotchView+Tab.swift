//
//  NotchView+Tab.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 10/31/25.
//

import SwiftUI

// MARK: - Tab Management

extension NotchView {
    /// Adds or updates a tab in the tab list.
    ///
    /// If a tab with the same ID already exists, it updates the tab data
    /// without changing its position. New tabs are added to the end.
    /// Enforces the maximum tab count by removing the oldest tab if needed.
    ///
    /// - Parameter tab: The tab item to add or update
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

    /// Removes a tab from the tab list.
    ///
    /// - Parameter id: The ID of the tab to remove
    func removeTab(id: String) {
        tabs.removeValue(forKey: id)
        tabOrder.removeAll { $0 == id }
    }

    /// Prints all tab IDs to the debug log.
    func printTabs() {
        logger.debug("\(tabs.keys)")
    }

    /// Checks if a specific tab is currently visible.
    ///
    /// A tab is showing if it's focused, the view is expanded, and settings are not showing.
    ///
    /// - Parameter tabId: The ID of the tab to check
    /// - Returns: `true` if the tab is currently visible
    func isTabShowing(tabId: String) -> Bool {
        return tabId == self.focusedTabId && isExpanded && !showSettings
    }

    /// Checks if a tab has been removed from the tab list.
    ///
    /// - Parameter tabId: The ID of the tab to check
    /// - Returns: `true` if the tab no longer exists
    func isTabRemoved(tabId: String) -> Bool {
        !tabs.keys.contains(tabId)
    }
}

