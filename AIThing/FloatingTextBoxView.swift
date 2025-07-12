//
//  FloatingTextBoxView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import SwiftUI

struct FloatingTextBoxView: View {
    var onClose: () -> Void
    var onSizeChange: (Bool) -> Void  // 👈 Callback to AppDelegate

    @State private var query = ""
    @State private var selectedOption = "Local"
    @State private var aiResponse: String = ""
    @State private var isLoading: Bool = false
    @State private var isBlinking = true
    @State private var showResponseArea = false

    var body: some View {
        ZStack {
            BlurredBackground()
                .contentShape(Rectangle())  // ✅ clickable for dragging

            VStack(spacing: 0) {

                HStack(spacing: 8) {
                    Menu {
                        Button("Local") { selectedOption = "Local" }
                            .keyboardShortcut("l", modifiers: [.command])  // ⌘L

                        Button("Global") { selectedOption = "Global" }
                            .keyboardShortcut("g", modifiers: [.command])  // ⌘G

                    } label: {
                        Text(selectedOption)
                            .foregroundColor(.white.opacity(0.5))
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .padding(.horizontal, 2)
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                    .frame(width: 64)

                    FocusableTextField(
                        text: $query,
                        onCommit: {
                            Task {
                                await handleQuery()
                            }
                        }
                    )

                    Button(action: handleClose) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 18, height: 18)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .frame(height: 32)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)

                if showResponseArea {
                    ScrollView {
                        if isLoading {
                            Text("Thinking...")
                                .foregroundColor(.white)
                                .font(.system(size: 14))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                                .opacity(isBlinking ? 1 : 0.4)
                                .onAppear {
                                    withAnimation(
                                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                                    ) {
                                        isBlinking.toggle()
                                    }
                                }
                        } else {
                            Text(.init(aiResponse))
                                .foregroundColor(.white)
                                .font(.system(size: 14))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                        }
                    }
                    .frame(height: 200)
                    .background(Color.black.opacity(0.3))
                }
            }
        }
        .frame(width: 640, height: showResponseArea ? 248 : 48)
        .background(Color.clear)  // make the full panel draggable
        .overlay(
            Group {
                if isLoading {
                    AnimatedGradientBorder(cornerRadius: showResponseArea ? 24 : 32, lineWidth: 2)
                }
            }
        )
        .cornerRadius(showResponseArea ? 24 : 32)
        .onExitCommand(perform: handleClose)
    }

    func handleQuery() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        showResponseArea = true
        aiResponse = ""
        onSizeChange(true)

        await callAI(query: trimmed)
    }

    func handleClose() {
        query = ""
        aiResponse = ""
        isLoading = false
        showResponseArea = false
        onSizeChange(false)
        onClose()
    }

    func callAI(query: String) async {
        let model = "claude-sonnet-4-20250514"

        guard let apiKey = Env.get("ANTHROPIC_API_KEY") else {
            aiResponse = "[Missing LLM API Key]"
            return
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("\(apiKey)", forHTTPHeaderField: "x-api-key")

        let body: [String: Any] = [
            "model": model,
            "stream": true,
            "max_tokens": 1024,
            "temperature": 0.7,
            "messages": [
                ["role": "user", "content": query]
            ],
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (stream, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200
            else {
                aiResponse = "[Error: Invalid response]"
                return
            }

            var partial = ""
            for try await line in stream.lines {
                if line.starts(with: "data: ") {
                    let jsonString = line.replacingOccurrences(of: "data: ", with: "")
                    if jsonString == "[DONE]" { break }

                    if let data = jsonString.data(using: .utf8),
                        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                        let content = (json["delta"] as? [String: Any])?["text"] as? String
                    {
                        isLoading = false

                        for char in content {
                            partial += String(char)
                            await MainActor.run {
                                self.aiResponse = partial + " " + shimmerPlaceholder()
                            }
                        }
                    }
                }
            }

            // Remove shimmer after final token
            await MainActor.run {
                self.aiResponse = partial
                print(self.aiResponse)
            }

        } catch {
            await MainActor.run {
                aiResponse = "[Error streaming Claude response: \(error.localizedDescription)]"
            }
        }
    }

    func shimmerPlaceholder() -> String {
        return "▌"  // or use "…" or a flashing cursor symbol
    }
}
