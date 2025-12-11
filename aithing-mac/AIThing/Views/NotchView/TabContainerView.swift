//
//  TabContainerView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 10/31/25.
//

import SwiftUI

extension NotchView {
    struct TabContainer<Content: View>: View {
        let tabOrder: [String]
        let tabs: [String: TabItem]
        let tabView: (TabItem) -> Content

        var body: some View {
            ForEach(tabOrder, id: \.self) { id in
                if let tab = tabs[id] {
                    tabView(tab)
                }
            }
        }
    }

    @ViewBuilder
    func tabView(tab: TabItem) -> some View {
        IntelligenceView(
            viewModel: viewModel,
            currentTabId: $focusedTabId,
            allClientTools: $allClientTools,
            allModels: $allModels,
            toastText: $toastText,
            tabId: tab.id,
            close: { close() },
            isTabShowing: { isTabShowing(tabId: tab.id) },
            isTabRemoved: { isTabRemoved(tabId: tab.id) },
            updateHistoryList: { await updateHistoryList() },
            getHistory: { return await getHistory(tabId: $0) },
            storeHistory: { await storeHistory(tabId: $0, history: $1) },
            setUnseen: { await setUnseen(id: $0, unseen: $1) },
            setTitle: { await setTitle(id: $0, title: $1) },
            startSelectionPoll: { self.startSelectionPoll() },
            stopSelectionPoll: { self.stopSelectionPoll() }
        )        
        .opacity(isExpanded && !showSettings && !focusedTabId.isEmpty ? 1 : 0)
        .environmentObject(connectionManager)
        .environmentObject(loginManager)
        .environmentObject(firestoreManager)
        .environmentObject(appContext)
        .environmentObject(automationManager)
        .environmentObject(screenshotMonitor)
    }
}

