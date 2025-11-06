//
//  ChatView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/15/25.
//

import AppKit
import SwiftUI

enum ChatRole {
    case user
    case assistant
    case usage
}

enum ChatPayload: Equatable {
    case text(String)
    case image(NSImage)
    case toolUse(name: String)

    static func == (lhs: ChatPayload, rhs: ChatPayload) -> Bool {
        switch (lhs, rhs) {
        case (.text(let a), .text(let b)): return a == b
        case (.toolUse(let a), .toolUse(let b)): return a == b
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

struct ChatView: View {
    @Binding var history: History?
    @Binding var isThinking: Bool
    @Binding var isThinkingBlinking: Bool
    @Binding var textSize: CGFloat
    @Binding var query: String
    @Binding var modelOutput: String

    @State private var items: [ChatItem] = []

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(items) { item in
                            ChatBubble(item: item)
                        }

                        // Temporary Output
                        if !modelOutput.isEmpty {
                            ChatBubble(
                                item: ChatItem(
                                    role: .assistant,
                                    payload: ChatPayload.text(modelOutput)
                                )
                            )
                        } else if isThinking {
                            ChatBubble(
                                item: ChatItem(
                                    role: .assistant,
                                    payload: ChatPayload.text("Thinking...")
                                )
                            )
                            .opacity(isThinkingBlinking ? 1 : 0.4)
                            .onAppear {
                                withAnimation(
                                    .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                                ) { isThinkingBlinking.toggle() }
                            }
                        }

                        Divider().opacity(0).id("Bottom")
                    }
                    .padding(.vertical, 16)
                }
                .onChange(of: items) { _ in
                    DispatchQueue.main.async {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo("Bottom", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: modelOutput) { _ in
                    DispatchQueue.main.async {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo("Bottom", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isThinking) { _ in
                    DispatchQueue.main.async {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo("Bottom", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .onChange(of: history) { _ in
            print("history changed")
            setHistory(history)
        }
    }

    private func setHistory(_ history: History?) {
        if let history {
            items = parseHistory(history.history)
            self.history = history
        } else {
            items = []
            self.history = history
        }
    }
}

struct ChatBubble: View {
    let item: ChatItem

    var body: some View {
        HStack {
            if item.role == .assistant { Spacer().frame(width: 0) }
            if item.role == .usage { Spacer().frame(width: 0) }

            switch item.payload {
            case .text(let text):
                if item.role != .usage {
                    TextBubble(text: text, isUser: item.role == .user)
                        .frame(maxWidth: 500, alignment: item.role == .user ? .trailing : .leading)
                }
            case .image(let image):
                ImageBubble(image: image, isUser: item.role == .user)
                    .frame(maxWidth: 300, alignment: item.role == .user ? .trailing : .leading)
            case .toolUse(let name):
                TextBubble(text: "Called tool: \(name)", isUser: false)
                    .frame(maxWidth: 500, alignment: item.role == .user ? .trailing : .leading)
            }

            if item.role == .user { Spacer().frame(width: 0) }
        }
        .frame(maxWidth: .infinity, alignment: item.role == .user ? .trailing : .leading)
    }
}

struct UsageBubble: View {
    let text: String

    var body: some View {
        MarkdownText(text: text)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .textSelection(.enabled)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
            )
    }
}

struct TextBubble: View {
    let text: String
    let isUser: Bool

    var body: some View {
        MarkdownText(text: text)
            .font(.system(size: 12, weight: .medium))
            .textSelection(.enabled)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isUser ? Color.gray.opacity(0.1) : Color.clear)
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

func assistantMessages(from history: [[String: Any]]) -> String {
    let chatItems = parseHistory(history).filter { $0.role == .assistant }
    var messages = ""
    let last = chatItems.last
    if last != nil {
        switch last!.payload {
        case .text(let text):
            messages += "\(text)\n\n"
        case .image(_):
            ()
        case .toolUse(let name):
            messages += "`Called tool: \(name)`\n\n"
        }
    }

    return messages
}

func nonUsageMessages(from history: [[String: Any]]) -> [[String: Any]] {
    var nonUsageMessages: [[String: Any]] = []
    for entry in history {
        guard let roleStr = entry["role"] as? String
        else { continue }

        if roleStr.lowercased() == "usage" {
            continue
        }
        nonUsageMessages.append(entry)
    }
    return nonUsageMessages
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
            case "usage": return .usage
            default: return nil
            }
        }()
        guard let roleUnwrapped = role else { continue }

        for content in contents {
            guard let type = content["type"] as? String else { continue }

            if roleUnwrapped == .usage {
                switch type {
                case "text":
                    if let text = content["text"] as? String {
                        items.append(ChatItem(role: .usage, payload: .text(text)))
                    }
                default:
                    break
                }
            } else if roleUnwrapped == .user {
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
