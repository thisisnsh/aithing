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

    @State private var contentMinHeight: CGFloat = 100
    @State private var contentHeight: CGFloat = 100
    @State private var contentMaxHeight: CGFloat = 1000
    @State private var debounceWorkItem: DispatchWorkItem?
    @State private var isLoading: Bool = false
    @State private var isThinkingBlinking = true
    @State private var isClipboardContext = false
    @State private var modelContext: String = ""
    @State private var modelInput: [[String: String]] = []
    @State private var modelOutput: String = ""
    @State private var modelOutputError: String = ""
    @State private var query = ""
    @State private var resizeWorkItem: DispatchWorkItem?
    @State private var selectedContext = ""
    @State private var showResponseArea = false

    var onClose: () -> Void
    var onSizeChange: (CGFloat) -> Void

    var body: some View {
        VStack {
            statusHeaderView()
            ZStack {
                BlurredBackground().contentShape(Rectangle())  // clickable for dragging
                VStack(spacing: 0) {
                    inputView()
                    if showResponseArea {
                        responseView()
                    }
                }
            }
            .frame(
                width: 640,
                height: showResponseArea
                    ? 48 + min(max(contentMinHeight, contentHeight), contentMaxHeight) : 48
            )
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
                            selectedContext = appContext.appName
                            return nil
                        } else if event.charactersIgnoringModifiers == "g" {
                            selectedContext = "Global"
                            return nil
                        } else if event.charactersIgnoringModifiers == "r" {
                            appContext.updateClipboardIfRecent()
                            modelContext = appContext.clipboardText
                            return nil
                        }

                    }
                    return event
                }
            }
            .onChange(of: appContext.appName) {
                if selectedContext.isEmpty || selectedContext != "Global" {
                    selectedContext = appContext.appName
                }
            }
        }
    }

    // MARK: - Private SubViews

    private func statusHeaderView() -> some View {
        HStack {
            StatusPill(
                text: "MCP Server",
                help: "Status of MCP Server",
                status: appContext.mcpStatus
            )
            if isClipboardContext {
                StatusPill(
                    text: "Clipboard Context",
                    help: "Copied text on clipboard will be used as context for the model.",
                    status: nil
                )
            } else {
                StatusPill(
                    text: "Selection Context",
                    help: "Selected text on the screen will be used as context for the model.",
                    status: nil
                )
            }
        }
    }

    private func inputView() -> some View {
        HStack(spacing: 8) {
            Menu {
                Button(appContext.appName) { selectedContext = appContext.appName }
                    .keyboardShortcut("l", modifiers: [.command])  // ⌘L

                Button("Global") { selectedContext = "Global" }
                    .keyboardShortcut("g", modifiers: [.command])  // ⌘G

            } label: {
                Text(selectedContext)
                    .foregroundColor(.white.opacity(0.5))
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .padding(.horizontal, 2)
                    .help("Scope of the context provided to the model.")
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
                        isClipboardContext = true
                    } else {
                        isClipboardContext = false
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
    }

    private func responseView() -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if isLoading {
                        Text("Thinking...")
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .opacity(isThinkingBlinking ? 1 : 0.4)
                            .onAppear {
                                withAnimation(
                                    .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                                ) {
                                    isThinkingBlinking.toggle()
                                }
                            }
                    } else {
                        MarkdownText(
                            text: modelOutputError.isEmpty ? modelOutput : modelOutputError
                        )
                        .foregroundColor(modelOutputError.isEmpty ? .white : .red)
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("BOTTOM")
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: ViewHeightKey.self, value: geo.size.height)
                    }
                )
            }
            .frame(
                height: min(max(contentMinHeight, contentHeight), contentMaxHeight)
            )  // clamp between 200–1000
            .background(Color.black.opacity(0.3))
            .onPreferenceChange(ViewHeightKey.self) { height in
                let checkedHeight = min(max(contentMinHeight, height), contentMaxHeight)

                if contentHeight < checkedHeight {
                    contentHeight = checkedHeight
                    onSizeChange(checkedHeight)
                }
            }
            .onChange(of: modelOutput) {
                if contentHeight == contentMaxHeight {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo("BOTTOM", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Private Functions

    private func handleQuery() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        modelOutput = ""
        modelOutputError = ""
        isLoading = true
        showResponseArea = true

        await callModel(query: trimmed)
    }

    private func handleClose() {
        query = ""
        modelOutput = ""
        modelOutputError = ""
        modelInput = []
        isLoading = false
        showResponseArea = false
        onSizeChange(0.0)
        contentHeight = contentMinHeight
        onClose()
    }

    private func callModel(query: String) async {
        let model = "claude-sonnet-4-20250514"

        guard let apiKey = Env.get("ANTHROPIC_API_KEY") else {
            isLoading = false
            modelOutputError = "Missing LLM API Key"
            return
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("\(apiKey)", forHTTPHeaderField: "x-api-key")

        modelContext =
            appContext.getSelectedText() ?? NSPasteboard.general.string(forType: .string) ?? ""

        if modelInput.isEmpty && selectedContext != "Global" {
            modelInput.append([
                "role": "user",
                "content": "I am using \(selectedContext) application on mac and require help.",
            ])
        }

        if !modelContext.isEmpty && selectedContext != "Global" {
            modelInput.append([
                "role": "user",
                "content":
                    "I am providing the context in next message that I might refer in my query.",
            ])
            modelInput.append([
                "role": "user",
                "content": modelContext,
            ])
        }

        modelInput.append(["role": "user", "content": query])
        return await fakeData()

        let body: [String: Any] = [
            "model": model,
            "stream": true,
            "max_tokens": 1024,
            "temperature": 0.7,
            "messages": modelInput,
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (stream, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200
            else {
                isLoading = false
                modelOutputError = "Invalid response"
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
                                modelOutput = partial + " " + shimmerPlaceholder()
                            }
                        }
                    }
                }
            }

            await MainActor.run {
                modelOutput = partial
            }

        } catch {
            await MainActor.run {
                isLoading = false
                modelOutputError =
                    "Error streaming Claude response: \(error.localizedDescription)"
            }
        }
    }

    private func shimmerPlaceholder() -> String {
        return "▌"  // or use "…" or a flashing cursor symbol
    }

    private func fakeData() async {
        print(modelInput)
        isLoading = false

        let fakeContent = """
            "Vishal" can refer to several things:

            1. **As a name**: Vishal is a popular Indian name, particularly common in Hindi-speaking regions. It means "large," "vast," or "magnificent" in Sanskrit.

            2. **As a person**: There are many notable people named Vishal, including:
               - Vishal Krishna (Tamil actor and producer)
               - Various other actors, directors, and public figures

            3. **As a business**: Vishal Mega Mart is a popular retail chain in India that sells clothing, accessories, and household items.

            Could you provide more context about which "Vishal" you're asking about? That would help me give you a more specific answer.
            """

        var fakePartial = ""
        for char in fakeContent {
            fakePartial += String(char)
            await MainActor.run {
                modelOutput = fakePartial + " " + shimmerPlaceholder()
            }
        }
    }
}
