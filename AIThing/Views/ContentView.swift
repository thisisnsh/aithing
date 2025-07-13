//
//  ContentView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import AppKit
import MarkdownUI
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appContext: AppContext

    @State private var debounceWorkItem: DispatchWorkItem?
    @State private var isLoading: Bool = false
    @State private var isThinkingBlinking = true
    @State private var modelContext: String = ""
    @State private var modelInput: [[String: String]] = []
    @State private var modelOutput: String = ""
    @State private var modelOutputError: String = ""
    @State private var query = ""
    @State private var selectedContext = ""
    @State private var showResponseArea = false

    var onClose: () -> Void
    var onSizeChange: (Bool) -> Void

    var body: some View {
        VStack {
            statusHeaderView()
            ZStack {
                BlurredBackground().contentShape(Rectangle())  // clickable for dragging
                VStack(spacing: 0) {
                    inputView()
                    if self.showResponseArea {
                        responseView()
                    }
                }
            }
            .frame(width: 640, height: self.showResponseArea ? 248 : 48)
            .background(Color.clear)  // make the full panel draggable
            .overlay(
                Group {
                    if self.isLoading {
                        AnimatedGradientBorder(
                            cornerRadius: self.showResponseArea ? 24 : 32,
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
                            self.selectedContext = self.appContext.appName
                            return nil
                        } else if event.charactersIgnoringModifiers == "g" {
                            self.selectedContext = "Global"
                            return nil
                        } else if event.charactersIgnoringModifiers == "r" {
                            self.appContext.updateClipboardIfRecent()
                            self.modelContext = self.appContext.clipboardText
                            return nil
                        }

                    }
                    return event
                }
            }
            .onChange(of: self.appContext.appName) {
                if self.selectedContext.isEmpty || self.selectedContext != "Global" {
                    self.selectedContext = self.appContext.appName
                }
            }
        }
    }

    // MARK: - Private SubViews

    private func statusHeaderView() -> some View {
        HStack {
            StatusPill(text: "MCP Server", status: self.appContext.mcpStatus)
        }
    }

    private func inputView() -> some View {
        HStack(spacing: 8) {
            Menu {
                Button(appContext.appName) { self.selectedContext = self.appContext.appName }
                    .keyboardShortcut("l", modifiers: [.command])  // ⌘L

                Button("Global") { self.selectedContext = "Global" }
                    .keyboardShortcut("g", modifiers: [.command])  // ⌘G

            } label: {
                Text(selectedContext)
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
            .onChange(of: self.query) {
                self.debounceWorkItem?.cancel()

                let task = DispatchWorkItem {
                    if self.appContext.getSelectedText() == nil {
                        self.showResponseArea = true
                        self.modelOutputError =
                            "Usage of selected text not allowed. Copy text to use as AI context."
                        onSizeChange(true)
                    } else {
                        self.modelOutputError = ""
                        self.showResponseArea = false
                        onSizeChange(false)
                    }
                }

                self.debounceWorkItem = task
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
    }

    private func responseView() -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                if self.isLoading {
                    Text("Thinking...")
                        .foregroundColor(.white)
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .opacity(isThinkingBlinking ? 1 : 0.4)
                        .onAppear {
                            withAnimation(
                                .easeInOut(duration: 0.6).repeatForever(
                                    autoreverses: true
                                )
                            ) {
                                self.isThinkingBlinking.toggle()
                            }
                        }
                } else {
                    MarkdownText(
                        text: self.modelOutputError.isEmpty
                            ? self.modelOutput : self.modelOutputError
                    )
                    .foregroundColor(modelOutputError.isEmpty ? .white : .red)
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
            .onChange(of: self.modelOutput) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        proxy.scrollTo("BOTTOM", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Private Functions

    private func handleQuery() async {
        let trimmed = self.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        self.modelOutput = ""
        self.modelOutputError = ""
        self.isLoading = true
        self.showResponseArea = true
        onSizeChange(true)

        await callModel(query: trimmed)
    }

    private func handleClose() {
        self.query = ""
        self.modelOutput = ""
        self.modelOutputError = ""
        self.modelInput = []
        self.isLoading = false
        self.showResponseArea = false
        onSizeChange(false)
        onClose()
    }

    private func callModel(query: String) async {
        let model = "claude-sonnet-4-20250514"

        guard let apiKey = Env.get("ANTHROPIC_API_KEY") else {
            self.isLoading = false
            self.modelOutputError = "Missing LLM API Key"
            return
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("\(apiKey)", forHTTPHeaderField: "x-api-key")

        self.modelContext =
            self.appContext.getSelectedText() ?? NSPasteboard.general.string(forType: .string) ?? ""

        if self.modelInput.isEmpty && self.selectedContext != "Global" {
            self.modelInput.append([
                "role": "user",
                "content": "I am using \(selectedContext) application on mac and require help.",
            ])
        }

        if !modelContext.isEmpty && self.selectedContext != "Global" {
            self.modelInput.append([
                "role": "user",
                "content":
                    "I am providing the context in next message that I might refer in my self.query.",
            ])
            self.modelInput.append([
                "role": "user",
                "content": self.modelContext,
            ])
        }

        self.modelInput.append(["role": "user", "content": self.query])
        print(modelInput)
        return

        let body: [String: Any] = [
            "model": model,
            "stream": true,
            "max_tokens": 1024,
            "temperature": 0.7,
            "messages": self.modelInput,
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (stream, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200
            else {
                self.isLoading = false
                self.modelOutputError = "Invalid response"
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
                        self.isLoading = false
                        for char in content {
                            partial += String(char)
                            await MainActor.run {
                                self.modelOutput = partial + " " + shimmerPlaceholder()
                            }
                        }
                    }
                }
            }

            await MainActor.run {
                self.modelOutput = partial
            }

        } catch {
            await MainActor.run {
                self.isLoading = false
                self.modelOutputError =
                    "Error streaming Claude response: \(error.localizedDescription)"
            }
        }
    }

    private func shimmerPlaceholder() -> String {
        return "▌"  // or use "…" or a flashing cursor symbol
    }
}
