//
//  NotchView+WindowControl.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 10/31/25.
//

import SwiftUI

// MARK: - Window Control & Utilities
extension NotchView {
    func updateHistoryList() async {
        histories = await historyStore.getAll(limit: 100)
        unseen = histories.contains(where: { $0.unseen == true })
    }

    func close(initialClose: Bool = false) {
        windowSize = WindowSize.collapsed
        (width, height) = updateWindowSize(windowSize)        
        screenshotMonitor.updateKnownFiles()
        screenshotMonitor.close()
        stopSelectionPoll()
        showDragIcon = false
        if !initialClose { Task { await refreshManagedAgents(forceRefresh: false) } }
    }

    func open() {
        windowSize = WindowSize.expanded
        (width, height) = updateWindowSize(windowSize)
        gainFocus()
        screenshotMonitor.updateKnownFiles()
        screenshotMonitor.open()
        showDragIcon = true
        Task { await refreshManagedAgents(forceRefresh: false) }
    }

    func sidebarToggle() {
        expandSidebar.toggle()
    }

    func getHistory(tabId: String) async -> History? {
        return await historyStore.get(id: tabId)
    }

    func storeHistory(tabId: String, history: [ChatItem], unseen: Bool? = nil) async {
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
