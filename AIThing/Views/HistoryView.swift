//
//  HistoryView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/14/25.
//

import SwiftUI

struct HistoryView: View {
    // If you use these:
    // @EnvironmentObject var loginManager: LoginManager
    // @EnvironmentObject var firestoreManager: FirestoreManager

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

    // MARK: - Sidebar

    private var sidebar: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: 16)

                ForEach(Array(histories.enumerated()), id: \.offset) { (i, h) in
                    sidebarButton(
                        h.title ?? title(for: h.history, fallback: "Session #\(i + 1)"),
                        subtitle: h.lastUpdated,
                        isActive: (i == index)
                    ) {
                        index = i
                        chatController.setHistory(h)
                    }
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
        .frame(width: 150)
        .background(Color.gray.opacity(0.08))
    }

    private func sidebarButton(
        _ title: String,
        subtitle: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isActive ? Color.black.opacity(0.5) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
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

extension Array {
    fileprivate subscript(safe i: Index) -> Element? { indices.contains(i) ? self[i] : nil }
}
