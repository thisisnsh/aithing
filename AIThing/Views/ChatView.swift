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
    case file
}

enum ChatPayload: Equatable {
    case text(String)
    case image([NSImage])
    case toolUse(name: String)
    case file(text: String, skipNextMessages: Bool)

    static func == (lhs: ChatPayload, rhs: ChatPayload) -> Bool {
        switch (lhs, rhs) {
        case (.text(let a), .text(let b)): return a == b
        case (.toolUse(let a), .toolUse(let b)): return a == b
        case (.file(let a, _), .file(let b, _)): return a == b
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
    @Binding var toolCall: String

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
                        }

                        if !toolCall.isEmpty {
                            ExtraBubble(text: toolCall)
                                .frame(maxWidth: 500, alignment: .leading)
                        }

                        if isThinking {
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
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) {
                        proxy.scrollTo("Bottom", anchor: .bottom)
                    }
                }
                .onChange(of: modelOutput) { _ in
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) {
                        proxy.scrollTo("Bottom", anchor: .bottom)
                    }
                }
                .onChange(of: isThinking) { _ in
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) {
                        proxy.scrollTo("Bottom", anchor: .bottom)
                    }
                }
            }
        }
        .onAppear {
            setHistory(history)
        }
        .onChange(of: history) { _ in
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
            case .file(let name, _):
                ExtraBubble(text: name)
                    .frame(maxWidth: 800, alignment: .trailing)
            case .text(let text):
                if item.role != .usage {
                    TextBubble(text: text, isUser: item.role == .user)
                        .frame(maxWidth: 800, alignment: item.role == .user ? .trailing : .leading)
                }
            case .image(let image):
                ImageBubble(image: image, isUser: item.role == .user)
                    .frame(maxWidth: 300, alignment: item.role == .user ? .trailing : .leading)
            case .toolUse(let name):
                ExtraBubble(text: "Called tool: \(name)")
                    .frame(maxWidth: 800, alignment: .leading)
            }

            if item.role == .user { Spacer().frame(width: 0) }
        }
        .frame(maxWidth: .infinity, alignment: item.role == .user ? .trailing : .leading)
    }
}

struct ExtraBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .textSelection(.enabled)
            .padding(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
            )
            .padding(.leading, 8)
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
    let image: [NSImage]
    let isUser: Bool

    @State private var index = 0

    var body: some View {
        ZStack {
            if image.count > 2 {
                ImageView(image: image[(index + 2) % image.count])
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .scaleEffect(0.6, anchor: .trailing)
                    .offset(x: -160)

            }

            if image.count > 1 {
                ImageView(image: image[(index + 1) % image.count])
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .scaleEffect(0.8, anchor: .trailing)
                    .offset(x: -80)
            }

            ImageView(image: image[index % image.count])
                .frame(maxWidth: .infinity, alignment: .trailing)
                .scaleEffect(1, anchor: .trailing)
                .onTapGesture {
                    index = (index + 1) % image.count
                }
        }
    }

    private func ImageView(image: NSImage) -> some View {
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

func nonUsageFileMessages(from history: [[String: Any]]) -> [[String: Any]] {
    var nonUsageFileMessages: [[String: Any]] = []
    for entry in history {
        guard let roleStr = entry["role"] as? String
        else { continue }

        if roleStr.lowercased() == "usage" || roleStr.lowercased() == "file" {
            continue
        }
        nonUsageFileMessages.append(entry)
    }
    return nonUsageFileMessages
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
            case "file": return .file
            default: return nil
            }
        }()
        guard let roleUnwrapped = role else { continue }

        var userImages: [NSImage] = []

        for content in contents {
            guard let type = content["type"] as? String else { continue }

            if roleUnwrapped == .file {
                switch type {
                case "file":
                    if let text = content["text"] as? String {
                        let skipNextMessages = (content["skip_next_messages"] as? Bool) ?? false
                        items.append(
                            ChatItem(
                                role: .file,
                                payload: .file(text: text, skipNextMessages: skipNextMessages)
                            )
                        )
                    }
                default:
                    break
                }
            } else if roleUnwrapped == .usage {
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
                        userImages.append(img)
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

        if userImages.count > 0 {
            print("add image")
            items.append(ChatItem(role: .user, payload: .image(userImages)))
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
