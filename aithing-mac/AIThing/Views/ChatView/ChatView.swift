//
//  ChatView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/15/25.
//

import AppKit
import SwiftUI
import os

struct ChatView: View {
    // MARK: - Bindings
    @Binding var history: History?
    @Binding var query: String
    @Binding var modelOutput: String
    @Binding var toolCall: String
    @Binding var showRefreshButton: Bool
    @Binding var isThinking: Bool

    // MARK: - Constants
    private let debouncer = Debouncer()

    // MARK: - State
    @State var scrollToBottom: Bool = true
    @State var hasMoreChats: Bool = false
    @State var items: [ChatItem] = []
    @State var bottomPadding: CGFloat = 64

    // MARK: - Body
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    if hasMoreChats {
                        Button {
                            scrollToBottom = false
                            setHistory(history, showFullChat: true)
                        } label: {
                            Text("Load Old Messages")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(4)
                                .padding(.horizontal, 8)
                                .background(.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }

                    ForEach(items) { item in
                        ChatBubble(item: item)
                            .id(item.id)
                    }

                    // Temporary Query
                    if !query.isEmpty {
                        ChatBubble(
                            item: ChatItem(
                                role: .user,
                                payload: ChatPayload.text(text: query)
                            )
                        )
                    }

                    // Temporary Output
                    if !modelOutput.isEmpty {
                        ChatBubble(
                            item: ChatItem(
                                role: .assistant,
                                payload: ChatPayload.text(text: modelOutput)
                            )
                        )
                    }

                    // Temporary Tool Calling...
                    if !toolCall.isEmpty {
                        ToolBubble(text: toolCall)
                            .frame(maxWidth: 500, alignment: .leading)
                    }

                    Divider().opacity(0).id("Bottom")
                        .padding(.bottom, bottomPadding)
                }
                .padding(.vertical, 16)
                .onChange(of: items.count) { _ in
                    if scrollToBottom {
                        scrollToBottomFunc(proxy)
                    } else {
                        scrollToBottom = true
                    }
                }
                .onChange(of: modelOutput) { _ in
                    debouncer.debounce(delay: 0.43) {
                        scrollToBottomFunc(proxy)
                    }
                }
                .onChange(of: query) { _ in
                    scrollToBottomFunc(proxy)
                }
                .onAppear {
                    scrollToBottomFunc(proxy)
                }
            }
        }
        .onAppear {
            setHistory(history)
        }
        .onChange(of: history?.history.count) { _ in
            setHistory(history)
        }
    }

    func scrollToBottomFunc(_ proxy: ScrollViewProxy) {
        proxy.scrollTo("Bottom", anchor: .bottom)
    }

    private func setHistory(_ history: History?, showFullChat: Bool = false) {
        guard let history = history else { return }

        items = []

        for item in history.history {
            // Ignore empty payload messages
            if item.payloads.isEmpty {
                continue
            }

            if item.payloads.count > 1 {
                // Split item into multiple items by combining image payloads
                // and separating other payloads. This is to show all images
                // together in clubbed layout
                var imagePayloads: [ChatPayload] = []

                for payload in item.payloads {
                    // Ignore tool result
                    if case .toolResult = payload {
                        continue
                    }

                    if payload.isImage {
                        imagePayloads.append(payload)
                        continue
                    }

                    // Add any contiguous images before adding non-image payload
                    if !imagePayloads.isEmpty {
                        items.append(ChatItem(role: item.role, payloads: imagePayloads))
                        imagePayloads = []
                    }
                    items.append(ChatItem(role: item.role, payload: payload))

                }

                // Add any remaining images
                if !imagePayloads.isEmpty {
                    items.append(ChatItem(role: item.role, payloads: imagePayloads))
                    imagePayloads = []
                }
            } else {
                // Add item directly if it has one or less payloads
                items.append(item)
            }

        }

        if showFullChat {
            hasMoreChats = false
        } else {
            // Show last 2 conversations
            // From second last occurance of role = .user and payload.isText in items

            let indices = items.indices.filter {
                items[$0].role == .user && items[$0].payloads.last!.isText
            }

            let secondLastIndex = indices.count >= 2 ? indices[indices.count - 2] : 0
            items = Array(items[secondLastIndex...])

            hasMoreChats = secondLastIndex > 0
            scrollToBottom = true
        }

        if let last = items.last, modelOutput.isEmpty {
            showRefreshButton = last.role != .assistant || !last.payloads.last!.isText
        }
    }
}
