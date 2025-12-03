//
//  NotchView+Utility.swift
//  AIThing
//
//  Utility extension for NotchView.
//

import SwiftUI

// MARK: - Utility
extension NotchView {
    func updateHistoryList() async {
        histories = await historyStore.getAll(limit: 100)
        unseen = histories.contains(where: { $0.unseen == true })
    }

    func createTitle(for history: [[String: Any]], fallback: String) -> String {
        for entry in history {
            guard let content = entry["content"] as? [[String: Any]] else { continue }
            for item in content {
                if (item["type"] as? String) == "text",
                    let text = item["text"] as? String,
                    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    return String(text.prefix(60))
                }
            }
        }
        return fallback
    }

    func close(initialClose: Bool = false) {
        AnalyticsManager.shared.customEvent(
            view: .NotchView,
            primary: .function,
            secondary: "close",
            sev: .info
        )
        windowSize = WindowSize.notchIsCollapsed
        (width, height) = updateWindowSize(windowSize)
        lastExpandedWindowSize =
            expandSidebar
            ? WindowSize.sidebarIsExpanded : WindowSize.sidebarIsCollapsed
        screenshotMonitor.updateKnownFiles()
        screenshotMonitor.close()
        stopSelectionPoll()
        if !initialClose {
            Task { await refreshManagedAgents(forceRefresh: false) }
        }
    }

    func open() {
        AnalyticsManager.shared.customEvent(
            view: .NotchView,
            primary: .function,
            secondary: "open",
            sev: .info
        )
        if windowSize == WindowSize.sidebarIsExpanded
            || windowSize == WindowSize.sidebarIsCollapsed
        {
            windowSize = WindowSize.chatIsShown
        } else {
            windowSize = lastExpandedWindowSize
        }
        (width, height) = updateWindowSize(windowSize)
        lastExpandedWindowSize = windowSize
        gainFocus()
        screenshotMonitor.updateKnownFiles()
        screenshotMonitor.open()
        Task { await refreshManagedAgents(forceRefresh: false) }
    }

    func minimize() {
        AnalyticsManager.shared.customEvent(
            view: .NotchView,
            primary: .function,
            secondary: "minimize",
            sev: .info
        )
        windowSize = WindowSize.notchIsCollapsed
        (width, height) = updateWindowSize(windowSize)
        screenshotMonitor.updateKnownFiles()
        screenshotMonitor.close()
        stopSelectionPoll()
        Task { await refreshManagedAgents(forceRefresh: false) }
    }

    func maximize() {
        AnalyticsManager.shared.customEvent(
            view: .NotchView,
            primary: .function,
            secondary: "maximize",
            sev: .info
        )
        if windowSize == WindowSize.chatIsShown {
            windowSize = WindowSize.chatIsExpanded
        } else {
            windowSize = WindowSize.chatIsShown
        }
        (width, height) = updateWindowSize(windowSize)
        lastExpandedWindowSize = windowSize
    }

    func sidebarToggle() {
        AnalyticsManager.shared.customEvent(
            view: .NotchView,
            primary: .function,
            secondary: "sidebarToggle",
            sev: .info
        )
        expandSidebar.toggle()

        if windowSize == WindowSize.sidebarIsExpanded {
            windowSize = WindowSize.sidebarIsCollapsed
        } else if windowSize == WindowSize.sidebarIsCollapsed {
            windowSize = WindowSize.sidebarIsExpanded
        }

        (width, height) = updateWindowSize(windowSize)
        lastExpandedWindowSize = windowSize
    }

    func dragViewY(multiplier: CGFloat) {
        if windowSize == WindowSize.notchIsCollapsed {
            return
        }
        if windowSize == WindowSize.chatIsExpanded {
            toastText = ""
            toastText = "Can not reposition AI Thing when it is expanded."
            return
        }
        let offset: CGFloat = 16
        modifyWindowTopOffset(offset * multiplier, lastExpandedWindowSize)
    }

    func getHistory(tabId: String) async -> History? {
        return await historyStore.get(id: tabId)
    }

    func storeHistory(
        tabId: String,
        history: [[String: Any]],
        unseen: Bool? = nil
    ) async {
        await historyStore.store(id: tabId, history: history, unseen: unseen)
    }

    func setUnseen(id: String, unseen: Bool) async {
        if await historyStore.setUnseen(id: id, unseen: unseen) {
            await updateHistoryList()
        }
    }

    func setTitle(id: String, title: String) async {
        if await historyStore.setTitle(id: id, title: title) {
            await updateHistoryList()
        }
    }
}

