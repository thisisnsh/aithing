//
//  SidebarView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 10/31/25.
//

import SwiftUI

extension NotchView {
    func Sidebar() -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(histories.enumerated()), id: \.offset) { (index, history) in
                    HoverableTabButton(
                        title: expandSidebar
                            ? (history.title ?? "Session #\(index + 1)")
                            : "",
                        isActive: (focusedTabId == history.id) && !showSettings && isExpanded,
                        action: {
                            open()
                            showSettings = false
                            addTab(TabItem(id: history.id))
                            focusedTabId = history.id
                        },
                        deleteAction: {
                            Task {
                                let isActive = focusedTabId == history.id
                                await historyStore.delete(id: history.id)
                                removeTab(id: history.id)
                                if isActive {
                                    if index + 1 < histories.count {
                                        let newHistory = histories[index + 1]
                                        addTab(TabItem(id: newHistory.id))
                                        focusedTabId = newHistory.id
                                    } else if index - 1 >= 0 && index - 1 < histories.count {
                                        let newHistory = histories[index - 1]
                                        addTab(TabItem(id: newHistory.id))
                                        focusedTabId = newHistory.id
                                    } else {
                                        let tabId = UUID().uuidString
                                        addTab(TabItem(id: tabId))
                                        focusedTabId = tabId
                                    }
                                }
                                histories = await historyStore.getAll(limit: 100)
                                unseen = histories.contains(where: { $0.unseen == true })
                            }
                        },
                        notification: history.unseen
                    )
                }

                if histories.isEmpty {
                    Text("No chats")
                        .foregroundColor(.secondary)
                        .font(.system(size: 10))
                        .padding(20)
                }

                Color.clear.frame(height: 16)
            }
        }
        .frame(width: expandSidebar ? 200 : 60)
    }
}
