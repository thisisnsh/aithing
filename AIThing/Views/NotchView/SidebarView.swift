//
//  SidebarView.swift
//  AIThing
//
//  Sidebar component showing chat history.
//

import SwiftUI

extension NotchView {
    func Sidebar() -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(histories.enumerated()), id: \.offset) { (i, h) in
                    HoverableTabButton(
                        title: expandSidebar
                            ? (h.title ?? createTitle(for: h.history, fallback: "Session #\(i + 1)"))
                            : "",
                        isActive: (focusedTabId == h.id) && !showSettings && showChatWindow,
                        action: {
                            open()
                            showSettings = false
                            addTab(TabItem(id: h.id))
                            focusedTabId = h.id
                        },
                        deleteAction: {
                            Task {
                                let isActive = focusedTabId == h.id
                                await historyStore.delete(id: h.id)
                                removeTab(id: h.id)
                                histories = await historyStore.getAll(limit: 100)
                                if isActive {
                                    if let history = histories.first {
                                        addTab(TabItem(id: history.id))
                                        focusedTabId = history.id
                                    } else {
                                        let tabId = UUID().uuidString
                                        addTab(TabItem(id: tabId))
                                        focusedTabId = tabId
                                    }
                                }
                                unseen = histories.contains(where: { $0.unseen == true })
                            }
                        },
                        notification: h.unseen
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

