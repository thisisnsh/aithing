//
//  FloatingTextBoxView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import AppKit
import SwiftUI

struct FloatingTextBoxView: View {
    var onClose: () -> Void
    var onSizeChange: (Bool) -> Void  // 👈 Callback to AppDelegate

    @EnvironmentObject var appContext: AppContext

    @State private var aiContext: String = ""
    @State private var aiResponse: String = ""
    @State private var aiResponseError: String = ""
    @State private var debounceWorkItem: DispatchWorkItem?
    @State private var isBlinking = true
    @State private var isLoading: Bool = false
    @State private var query = ""
    @State private var selectedOption = ""
    @State private var showResponseArea = false

    var body: some View {
        VStack {
            HStack {
                StatusPill(text: "MCP Server", status: appContext.mcpStatus)
            }

            ZStack {
                BlurredBackground()
                    .contentShape(Rectangle())  // ✅ clickable for dragging

                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Menu {
                            Button(appContext.appName) { selectedOption = appContext.appName }
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
                        .fixedSize()

                        FocusableTextField(
                            text: $query,
                            onCommit: {
                                Task {
                                    await handleQuery()
                                }
                            }
                        )
                        .onChange(of: query) {
                            debounceWorkItem?.cancel()

                            let task = DispatchWorkItem {
                                if appContext.getSelectedText() == nil {
                                    showResponseArea = true
                                    aiResponseError =
                                        "Usage of selected text not allowed. Copy text to use as AI context."
                                    onSizeChange(true)
                                } else {
                                    aiResponseError = ""
                                    showResponseArea = false
                                    onSizeChange(false)
                                }
                            }

                            debounceWorkItem = task
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: task)
                        }

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
                        ScrollViewReader { proxy in
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
                                                .easeInOut(duration: 0.6).repeatForever(
                                                    autoreverses: true
                                                )
                                            ) {
                                                isBlinking.toggle()
                                            }
                                        }
                                } else {
                                    Text(
                                        .init(
                                            aiResponseError.isEmpty ? aiResponse : aiResponseError
                                        )
                                    )
                                    .foregroundColor(aiResponseError.isEmpty ? .white : .red)
                                    .font(.system(size: 14))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 16)

                                    Color.clear
                                        .frame(height: 1)
                                        .id("BOTTOM")
                                }
                            }
                            .frame(height: 200)
                            .background(Color.black.opacity(0.3))
                            .onChange(of: aiResponse) {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation {
                                        proxy.scrollTo("BOTTOM", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(width: 640, height: showResponseArea ? 248 : 48)
            .background(Color.clear)  // make the full panel draggable
            .overlay(
                Group {
                    if isLoading {
                        AnimatedGradientBorder(
                            cornerRadius: showResponseArea ? 24 : 32,
                            lineWidth: 2
                        )
                    }
                }
            )
            .cornerRadius(showResponseArea ? 24 : 32)
            .onExitCommand(perform: handleClose)
            .onAppear {
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    if event.modifierFlags.contains(.command) {
                        if event.charactersIgnoringModifiers == "l" {
                            selectedOption = appContext.appName
                            return nil
                        } else if event.charactersIgnoringModifiers == "g" {
                            selectedOption = "Global"
                            return nil
                        } else if event.charactersIgnoringModifiers == "r" {
                            appContext.updateClipboardIfRecent()
                            aiContext = appContext.clipboardText
                            return nil
                        }

                    }
                    return event
                }
            }
            .onChange(of: appContext.appName) {
                if selectedOption.isEmpty || selectedOption != "Global" {
                    selectedOption = appContext.appName
                }
            }
        }
    }

    func handleQuery() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        aiResponse = ""
        aiResponseError = ""
        isLoading = true
        showResponseArea = true
        onSizeChange(true)

        await callAI(query: trimmed)
    }

    func handleClose() {
        query = ""
        aiResponse = ""
        aiResponseError = ""
        isLoading = false
        showResponseArea = false
        onSizeChange(false)
        onClose()
    }

    func callAI(query: String) async {
        aiContext =
            appContext.getSelectedText() ?? NSPasteboard.general.string(forType: .string) ?? ""
        
        let model = "claude-sonnet-4-20250514"

        guard let apiKey = Env.get("ANTHROPIC_API_KEY") else {
            isLoading = false
            aiResponseError = "Missing LLM API Key"
            return
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("\(apiKey)", forHTTPHeaderField: "x-api-key")

        var messages: [[String: Any]] = []

        if selectedOption != "Global" {
            messages.append([
                "role": "user",
                "content": "I am using \(selectedOption) application on mac and require help.",
            ])

            if !aiContext.isEmpty {
                messages.append([
                    "role": "user",
                    "content":
                        "I am providing the context in next message that I might refer in my query.",
                ])
                messages.append([
                    "role": "user",
                    "content": aiContext,
                ])
            }
        }

        messages.append(["role": "user", "content": query])
        print(messages)

        let body: [String: Any] = [
            "model": model,
            "stream": true,
            "max_tokens": 1024,
            "temperature": 0.7,
            "messages": messages,
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (stream, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200
            else {
                isLoading = false
                aiResponseError = "Invalid response"
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
            }

        } catch {
            await MainActor.run {
                isLoading = false
                aiResponseError = "Error streaming Claude response: \(error.localizedDescription)"
            }
        }
    }

    func shimmerPlaceholder() -> String {
        return "▌"  // or use "…" or a flashing cursor symbol
    }
}
