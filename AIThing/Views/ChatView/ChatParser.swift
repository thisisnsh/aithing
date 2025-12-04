//
//  ChatParser.swift
//  AIThing
//
//  Helper functions for parsing chat history.
//

import AppKit
import Foundation

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
    var isNextFileMessage = false
    var fileName = ""

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
                        isNextFileMessage = skipNextMessages
                        fileName = text

                        if !skipNextMessages {
                            items.append(
                                ChatItem(
                                    role: .file,
                                    payload: .file(
                                        text: text,
                                        skipNextMessages: skipNextMessages,
                                        content: ""
                                    )
                                )
                            )
                        }
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
                        if isNextFileMessage {
                            items.append(
                                ChatItem(
                                    role: .file,
                                    payload: .file(
                                        text: fileName,
                                        skipNextMessages: false,
                                        content: text
                                    )
                                )
                            )
                            fileName = ""
                            isNextFileMessage = false
                        } else {
                            items.append(ChatItem(role: .user, payload: .text(text)))
                        }
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
            items.append(ChatItem(role: .user, payload: .image(userImages)))
        }
    }
    return items
}

func base64ToNSImage(_ base64: String) -> NSImage? {
    guard let data = Data(base64Encoded: base64, options: [.ignoreUnknownCharacters]),
        let img = NSImage(data: data)
    else { return nil }
    return img
}

