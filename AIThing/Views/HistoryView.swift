//
//  HistoryView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/14/25.
//

import SwiftUI

struct HistoryView: View {
    @Binding var isPresented: Bool
    let setPanelPassthrough: (_ enabled: Bool) -> Void
    private func updatePassthrough(inside: Bool) { setPanelPassthrough(!inside) }
    let continueConversation: (_ history: History) -> Void

    @State private var histories: [History] = []
    @State private var index = 0
    @StateObject private var chatController = ChatController()

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            ChatView(
                controller: chatController,
                lastUpdated: histories[safe: index]?.lastUpdated ?? "—",
                continueConversation: { history in continueConversation(history) }
            )
        }
        .onAppear {
            Task {
                histories = await HistoryStore.shared.getAll()
                if let first = histories.first {
                    chatController.setHistory(first)
                }
            }
        }
        .onHover(perform: updatePassthrough)
    }

    private var sidebar: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: 16)

                ForEach(Array(histories.enumerated()), id: \.offset) { (i, h) in
                    HoverableTabButton(
                        title: h.title ?? title(for: h.history, fallback: "Session #\(i + 1)"),
                        isActive: (i == index),
                        action: {
                            index = i
                            chatController.setHistory(h)
                        },
                        deleteAction: {
                            Task {
                                let isActive = i == index
                                await HistoryStore.shared.delete(id: h.id)
                                histories = await HistoryStore.shared.getAll()
                                if isActive {
                                    if index >= histories.count {
                                        index = max(0, histories.count - 1)
                                    }
                                    let history = histories[safe: index]
                                    chatController.setHistory(history)
                                }
                            }
                        }
                    )
                }

                if histories.isEmpty {
                    Text("No history yet")
                        .foregroundColor(.secondary)
                        .font(.system(size: 10))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }

                Color.clear.frame(height: 16)
            }
        }
        .frame(width: 160)
        .background(Color.gray.opacity(0.08))
    }

    // MARK: - Helpers

    private func title(for history: [[String: Any]], fallback: String) -> String {
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
}

struct HoverableTabButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void
    let deleteAction: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Main clickable area
            Button(action: action) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(isActive ? Color.black.opacity(0.5) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            // Trash button (shown only when hovered)
            if isHovered {
                Button(action: deleteAction) {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .padding(.horizontal, 8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

extension Array {
    fileprivate subscript(safe i: Index) -> Element? { indices.contains(i) ? self[i] : nil }
}
