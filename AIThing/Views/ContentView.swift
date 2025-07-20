//
//  ContentView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import AppKit
import MCP
import MarkdownUI
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appContext: AppContext

    var onClose: () -> Void
    var onSizeChange: (CGFloat) -> Void

    @State private var width: CGFloat = 100
    @State private var inputHeight: CGFloat = 48
    @State private var responseHeightMin: CGFloat = 100
    @State private var responseHeightMax: CGFloat = 700
    @State private var responseHeight: [String: CGFloat] = [:]  // default 100

    @State private var isThinking: [String: Bool] = [:]  // default false
    @State private var isThinkingBlinking: [String: Bool] = [:]  // default true

    @State private var modelInput: [String: [[String: Any]]] = [:]  // key = tab id // default []
    @State private var modelOutput: [String: String] = [:]  // key = tab id // default ""
    @State private var modelOutputError: [String: String] = [:]  // key = tab id // default ""
    @State private var modelTools: [String: [[String: Any]]] = [:]  // key = client // default []
    @State private var modelClients: [String] = []

    @State private var query: [String: String] = [:]  // key = tab id // default ""
    @State private var showResponseArea: [String: Bool] = [:]  // key = tab id // default false

    @State private var currentTab: String = ""

    var body: some View {
        VStack {
            ZStack {
                BlurredBackground().contentShape(Rectangle())
                VStack(spacing: 0) {
                    inputView()
                    if showResponseArea[currentTab] ?? false {
                        responseView()
                    }
                }
            }
            .frame(
                width: width,
                height: inputHeight + getResponseHeight()
            )
            .background(Color.clear)
            .overlay(
                // todo: Blink the tab
                Group {
                    if isThinking[currentTab] ?? false {
                        AnimatedGradientBorder(
                            cornerRadius: getCornerRadius(),
                            lineWidth: 2
                        )
                    } else {
                        RoundedRectangle(cornerRadius: getCornerRadius())
                            .stroke(Color.white, lineWidth: 1.5)
                    }
                }
            )
            .cornerRadius(getCornerRadius())
            .onAppear {
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    if event.modifierFlags.contains(.control) {
                        switch event.keyCode {
                        case 17:  // T key
                            print("T pressed")
                            addTab()
                        case 13:  // W key
                            print("W pressed")
                            closeTab()
                        case 43:  // Left angular arrow
                            print("< pressed")
                            moveFocus(-1)
                        case 47:  // Right angular bracket
                            print("> pressed")
                            moveFocus(1)
                        default:
                            break
                        }
                    }
                    return event
                }
            }
            .task {
                guard let mcp = appContext.mcpClientManager else { return }

                // Parallel fetching using async let
                var results: [(String, [[String: Any]])] = []
                await withTaskGroup(of: (String, [[String: Any]]).self) { group in
                    for (clientName, _) in mcp.clients {
                        group.addTask {
                            let tools = await mcp.getTools(clientName: clientName)
                            return (clientName, tools)
                        }
                    }

                    for await (clientName, tools) in group {
                        modelTools[clientName] = tools
                    }
                }
            }
        }
    }

    // MARK: - Private SubViews

    private func inputView() -> some View {
        HStack(spacing: 8) {
            Image("logo")
                .resizable()
                .frame(width: 24, height: 24)

            FocusableTextField(
                text: Binding(
                    get: { query[currentTab] ?? "" },
                    set: { query[currentTab] = $0 }
                ),
                onCommit: {
                    Task {
                        await handleQuery()
                    }
                }
            )

            Button(action: handleHelp) {
                Image(systemName: "questionmark.circle.fill")
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
                    if getIsThinking() {
                        Text("Thinking...")
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .opacity(getIsThinkingBlinking() ? 1 : 0.4)
                            .onAppear {
                                withAnimation(
                                    .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                                ) {
                                    toggleIsThinkingBlinking()
                                }
                            }
                    } else {
                        MarkdownText(
                            text: getModelOutputError().isEmpty
                                ? getModelOutput() : getModelOutputError()
                        )
                        .foregroundColor(getModelOutputError().isEmpty ? .white : .red)
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
                height: getResponseHeight()
            )
            .background(Color.black.opacity(0.3))
            .onPreferenceChange(ViewHeightKey.self) { height in
                let checkedHeight = min(max(responseHeightMin, height), responseHeightMax)

                if responseHeight[currentTab] ?? 100 < checkedHeight {
                    responseHeight[currentTab] = checkedHeight
                    onSizeChange(responseHeight[currentTab] ?? 100)
                }
            }
            .onChange(of: modelOutput) {
                if responseHeight[currentTab] == responseHeightMax {
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

    private func getResponseHeight() -> CGFloat {
        var height: CGFloat = 0
        if showResponseArea[currentTab] ?? false {
            height = min(
                max(responseHeightMin, responseHeight[currentTab] ?? 100),
                responseHeightMax
            )
        }
        return height
    }

    private func getCornerRadius() -> CGFloat {
        return showResponseArea[currentTab] ?? false ? 24 : 32
    }

    private func getIsThinking() -> Bool {
        return isThinking[currentTab] ?? false
    }

    private func getIsThinkingBlinking() -> Bool {
        return isThinkingBlinking[currentTab] ?? false
    }

    private func toggleIsThinkingBlinking() {
        if isThinkingBlinking.keys.contains(currentTab) {
            isThinkingBlinking[currentTab] = !isThinkingBlinking[currentTab]!
        }
    }

    private func getModelOutput() -> String {
        return modelOutput[currentTab] ?? ""
    }

    private func getModelOutputError() -> String {
        return modelOutputError[currentTab] ?? ""
    }

    private func handleQuery() async {
        let trimmed = (query[currentTab] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        modelOutput[currentTab] = ""
        modelOutputError[currentTab] = ""
        isThinking[currentTab] = true
        showResponseArea[currentTab] = true
        responseHeight[currentTab] = responseHeightMin
        onSizeChange(responseHeight[currentTab] ?? 100)

        await callModel(query: trimmed, previousContext: "")
    }

    private func handleClose() {
        query[currentTab] = ""
        modelOutput[currentTab] = ""
        modelOutputError[currentTab] = ""
        modelInput[currentTab] = []
        isThinking[currentTab] = false
        showResponseArea[currentTab] = false
        responseHeight[currentTab] = responseHeightMin
        onSizeChange(responseHeight[currentTab] ?? 100)
        onClose()
    }

    private func handleHelp() {
        // todo
    }

    private func callModel(query: String?, previousContext: String) async {
        return await fakeData()

        let model = "claude-sonnet-4-20250514"

        guard
            let apiKey = Env.get("ANTHROPIC_API_KEY_" + appContext.appName.uppercased())
                ?? Env.get("ANTHROPIC_API_KEY")
        else {
            isThinking[currentTab] = false
            modelOutputError[currentTab] = "Missing LLM API Key"
            return
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("\(apiKey)", forHTTPHeaderField: "x-api-key")
        request.setValue("extended-cache-ttl-2025-04-11", forHTTPHeaderField: "anthropic-beta")

        modelContext =
            appContext.getSelectedText() ?? NSPasteboard.general.string(forType: .string) ?? ""

        if modelInput.isEmpty && !selectedContext.isEmpty && selectedContext != "MacOS" {
            modelInput.append([
                "role": "user",
                "content": [
                    [
                        "text":
                            "I am using `\"\(selectedContext)`\" app on Mac and on \"\(appContext.windowName)\" window.",
                        "type": "text",
                    ]
                ],
            ])
        }

        if previousContext != modelContext,
            !modelContext.isEmpty,
            !selectedContext.isEmpty,
            selectedContext != "MacOS"
        {

            modelInput.append([
                "role": "user",
                "content": [
                    [
                        "type": "text",
                        "text": "Additional context from the current app. \n\(modelContext)",
                    ]
                ],
            ])
        }

        if let query, !query.isEmpty {
            modelInput.append([
                "role": "user",
                "content": [
                    ["type": "text", "text": query]
                ],
            ])
        }

        let body: [String: Any] = [
            "model": model,
            "stream": true,
            "max_tokens": 1024,
            "temperature": 0.7,
            "messages": addCacheBlock(input: modelInput, isMessage: true),
            "tools": addCacheBlock(input: selectedContextTools),
            "system": addCacheBlock(input: buildSystemMessages()),

        ]
        print("-------- messages: \((body["messages"] as! [Any]).last ?? "")")
        //        print("system: \(body["system"] as! [Any])")
        print("-------- tools_count: \((body["tools"] as! [Any]).count)")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (stream, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse
            else {
                isThinking = false
                modelOutputError = "Invalid response"
                return
            }

            if httpResponse.statusCode != 200 {
                isThinking = false
                var error = ""
                for try await line in stream.lines {
                    error += line
                }
                modelOutputError = "Error \(httpResponse.statusCode)\n\(error)"
                return
            }

            var finalResponse = ""
            var finalToolUseInputParam = ""
            var finalToolUseId = ""
            var finalToolUseName = ""

            for try await line in stream.lines {
                //                print("-------- line: \(line)")
                if line.starts(with: "data: ") {
                    let jsonString = line.replacingOccurrences(of: "data: ", with: "")

                    guard let data = jsonString.data(using: .utf8) else { continue }
                    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                    else { continue }

                    guard let data_type = json["type"] as? String else { continue }

                    switch data_type {
                    case "content_block_start":
                        guard let content_block = json["content_block"] as? [String: Any] else {
                            continue
                        }
                        guard let content_block_type = content_block["type"] as? String else {
                            continue
                        }

                        switch content_block_type {
                        case "text":
                            continue
                        case "tool_use":
                            guard let id = content_block["id"] as? String else { continue }
                            guard let name = content_block["name"] as? String else { continue }
                            finalToolUseId = id
                            finalToolUseName = name
                        default:
                            continue
                        }

                    case "content_block_delta":
                        guard let delta = json["delta"] as? [String: Any] else { continue }
                        guard let delta_type = delta["type"] as? String else { continue }

                        switch delta_type {
                        case "text_delta":
                            guard let text = delta["text"] as? String else { continue }
                            isThinking = false
                            for char in text {
                                finalResponse += String(char)
                                await MainActor.run {
                                    modelOutput = finalResponse + " " + shimmerPlaceholder()
                                }
                            }

                        case "input_json_delta":
                            guard let partial_json = delta["partial_json"] as? String else {
                                continue
                            }
                            finalToolUseInputParam += partial_json

                        default:
                            continue
                        }

                    case "content_block_stop":
                        await MainActor.run {
                            modelOutput = finalResponse
                        }

                    case "message_delta":
                        guard let delta = json["delta"] as? [String: Any] else { continue }
                        guard let delta_stop_reason = delta["stop_reason"] as? String else {
                            continue
                        }

                        if !modelOutput.isEmpty {
                            modelInput.append([
                                "role": "assistant",
                                "content": [["text": modelOutput, "type": "text"]],
                            ])
                        }

                        switch delta_stop_reason {
                        case "max_tokens":
                            continue
                        case "tool_use":
                            guard let mcpClientManager = appContext.mcpClientManager else {
                                continue
                            }

                            modelInput.append([
                                "role": "assistant",
                                "content": [
                                    [
                                        "type": "tool_use",
                                        "id": finalToolUseId,
                                        "name": finalToolUseName,
                                        "input": parseJSONStringToDictObject(
                                            finalToolUseInputParam
                                        ),
                                    ]
                                ],
                            ])

                            finalResponse += "\n\n```Calling tool: \(finalToolUseName)...```\n\n"
                            await MainActor.run {
                                modelOutput = finalResponse
                            }
                            let result = await mcpClientManager.callTools(
                                appName: selectedContext,
                                name: finalToolUseName,
                                input: finalToolUseInputParam
                            )

                            modelInput.append([
                                "role": "user",
                                "content": [
                                    [
                                        "type": "tool_result",
                                        "tool_use_id": finalToolUseId,
                                        "content": result,
                                    ]
                                ],
                            ])

                            await callModel(query: nil, previousContext: modelContext)
                            return

                        default:
                            continue
                        }

                    default:
                        continue
                    }
                }
            }
        } catch {
            await MainActor.run {
                isThinking = false
                modelOutputError =
                    "Error streaming Claude response: \(error.localizedDescription)"
            }
        }
    }

    private func buildSystemMessages() -> [[String: Any]] {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "en_US")
        let today = formatter.string(from: Date())

        let messages: [[String: Any]] = [
            [
                "type": "text",
                "text": """
                Your name is 'AI Thing', and you are an AI assistant with a unique ability: you can understand 'this'. \
                Similar to local context in programming languages, 'this' refers to the context of the tool or environment \
                in which you are being used. You are helpful, grounded, and capable of executing structured actions via tools.
                """,
            ],
            [
                "type": "text",
                "text": """
                When asked 'what is this?' without any context, reply with a one-line description of yourself, \
                highlighting your special ability to understand 'this'. Do not describe the tools unless explicitly asked.
                """,
            ],
            [
                "type": "text",
                "text": "Today is \(today).",
            ],
            [
                "type": "text",
                "text": """
                You are expected to behave as an agent: you can perceive user instructions, reason about available tools, \
                and invoke them if appropriate. You must be precise, context-aware, and avoid guessing when information is \
                ambiguous or incomplete. You must always output in Markdown.
                """,
            ],
        ]

        return messages
    }

    private func addCacheBlock(input: [[String: Any]], isMessage: Bool = false) -> [[String: Any]] {
        var updated = input

        if isMessage {
            guard var last = input.last,
                var contentArray = last["content"] as? [[String: Any]],
                var lastContent = contentArray.last
            else {
                return input
            }

            lastContent["cache_control"] = [
                "type": "ephemeral",
                "ttl": "5m",
            ]
            contentArray[contentArray.count - 1] = lastContent
            last["content"] = contentArray

            updated[updated.count - 1] = last
        } else {

            guard var last = input.last else {
                return input
            }

            last["cache_control"] = [
                "type": "ephemeral",
                "ttl": "5m",
            ]

            updated[updated.count - 1] = last
        }
        return updated
    }

    private func shimmerPlaceholder() -> String {
        return "▌"  // or use "…" or a flashing cursor symbol
    }

    private func fakeData() async {
        isThinking[currentTab] = false

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
