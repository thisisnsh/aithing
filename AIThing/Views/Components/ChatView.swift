//
//  ChatView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/15/25.
//

import AppKit
import SwiftUI

// MARK: - Chat parsing primitives

enum ChatRole {
    case user
    case assistant
}

enum ChatPayload: Equatable {
    case text(String)
    case image(NSImage)
    case toolUse(name: String)

    static func == (lhs: ChatPayload, rhs: ChatPayload) -> Bool {
        switch (lhs, rhs) {
        case let (.text(a), .text(b)): return a == b
        case let (.toolUse(a), .toolUse(b)): return a == b
        case (.image, .image): return false  // NSImage not Equatable; treat as unequal
        default: return false
        }
    }
}

struct ChatItem: Identifiable, Equatable {
    let id = UUID()
    let role: ChatRole
    let payload: ChatPayload
}

func assistantMessages(from history: [[String: Any]]) -> String {
    let chatItems = parseHistory(history).filter { $0.role == .assistant }
    var messages = ""
    let last = chatItems.last
    if last != nil {
        switch last!.payload {
        case .text(let text):
            messages += "\(text)\n\n"
        case .image(let _):
            ()
        case .toolUse(let name):
            messages += "`Called tool: \(name)`\n\n"
        }
    }

    return messages
}

func parseHistory(_ history: [[String: Any]]) -> [ChatItem] {
    var items: [ChatItem] = []

    for entry in history {
        guard let roleStr = entry["role"] as? String,
            let contents = entry["content"] as? [[String: Any]]
        else { continue }

        let role: ChatRole? = {
            switch roleStr.lowercased() {
            case "user": return .user
            case "assistant": return .assistant
            default: return nil
            }
        }()
        guard let roleUnwrapped = role else { continue }

        for content in contents {
            guard let type = content["type"] as? String else { continue }

            if roleUnwrapped == .user {
                switch type {
                case "text":
                    if let text = content["text"] as? String {
                        items.append(ChatItem(role: .user, payload: .text(text)))
                    }
                case "image":
                    if let source = content["source"] as? [String: Any],
                        let srcType = source["type"] as? String, srcType == "base64",
                        let mediaType = source["media_type"] as? String,
                        mediaType.lowercased().hasPrefix("image/"),
                        let dataStr = source["data"] as? String,
                        let img = base64ToNSImage(dataStr)
                    {
                        items.append(ChatItem(role: .user, payload: .image(img)))
                    }
                default:
                    break
                }
            } else {  // assistant
                switch type {
                case "text":
                    if let text = content["text"] as? String {
                        items.append(ChatItem(role: .assistant, payload: .text(text)))
                    }
                case "tool_use":
                    let name = (content["name"] as? String) ?? "Unknown Tool"
                    items.append(ChatItem(role: .assistant, payload: .toolUse(name: name)))
                default:
                    break
                }
            }
        }
    }
    return items
}

private func base64ToNSImage(_ base64: String) -> NSImage? {
    guard let data = Data(base64Encoded: base64, options: [.ignoreUnknownCharacters]),
        let img = NSImage(data: data)
    else { return nil }
    return img
}

// MARK: - Chat controller

final class ChatController: ObservableObject {
    @Published var items: [ChatItem] = []
    @Published var history: History?
    func setHistory(_ history: History) {
        items = parseHistory(history.history)
        self.history = history
    }
}

// MARK: - Chat UI

struct ChatView: View {
    @ObservedObject var controller: ChatController
    let lastUpdated: String
    let continueConversation: (_ history: History) -> Void

    var formattedLastUpdated: String? {
        return formatEpoch(lastUpdated)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let formattedLastUpdated {
                HStack {
                    Text("Last updated: \(formattedLastUpdated)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Spacer()
                    if controller.history != nil {
                        Button {
                            continueConversation(controller.history!)
                        } label: {
                            HStack {
                                Text("Continue")
                                    .font(.system(size: 12, weight: .medium))
                                Image(systemName: "arrow.up.right")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 8)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.black.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Divider()
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(controller.items) { item in
                            ChatBubble(item: item)
                                .id(item.id)
                        }
                    }
                    .padding(16)
                }
                .onReceive(controller.$items) { _ in
                    if let lastID = controller.items.last?.id {
                        DispatchQueue.main.async {
                            withAnimation(.easeOut(duration: 0.25)) {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct ChatBubble: View {
    let item: ChatItem

    var body: some View {
        HStack {
            if item.role == .assistant { Spacer().frame(width: 0) }

            switch item.payload {
            case .text(let text):
                TextBubble(text: text, isUser: item.role == .user)
                    .frame(maxWidth: 500, alignment: item.role == .user ? .trailing : .leading)
            case .image(let image):
                ImageBubble(image: image, isUser: item.role == .user)
                    .frame(maxWidth: 320, alignment: item.role == .user ? .trailing : .leading)
            case .toolUse(let name):
                TextBubble(text: "Called tool: \(name)", isUser: false)
                    .frame(maxWidth: 500, alignment: item.role == .user ? .trailing : .leading)
            }

            if item.role == .user { Spacer().frame(width: 0) }
        }
        .frame(maxWidth: .infinity, alignment: item.role == .user ? .trailing : .leading)
    }
}

struct TextBubble: View {
    let text: String
    let isUser: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .textSelection(.enabled)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isUser
                            ? Color.gray.opacity(0.1) : Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.gray.opacity(0.5), lineWidth: isUser ? 0 : 1)
            )
    }
}

struct ImageBubble: View {
    let image: NSImage
    let isUser: Bool

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isUser
                            ? Color.gray.opacity(0.1) : Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.gray.opacity(0.5), lineWidth: isUser ? 0 : 1)
            )
    }
}

func formatEpoch(_ epochS: String, format: String = "MMMM, dd yyyy HH:mm") -> String? {
    if let epoch = Double(epochS) {
        let date = Date(timeIntervalSince1970: epoch)
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    } else {
        return nil
    }
}
