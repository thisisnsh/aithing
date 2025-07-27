//
//  TabView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import AppKit
import MCP
import MarkdownUI
import SwiftUI

struct TabView: View {
    @EnvironmentObject var mcp: MCPManager

    @Binding var isFocused: Bool
    var allClientTools: [String: [[String: Any]]]
    var onHelp: () -> Void
    var onSizeChange: (CGFloat) -> Void
    var incrementSizePanel: (CGFloat) -> Void

    @State private var imageName: String = "Logo"
    @State private var title: String = "AI Thing"

    @State private var responseHeightMin: CGFloat = 100
    @State private var responseHeightMax: CGFloat = 700
    @State private var responseHeight: CGFloat = 100

    @State private var isThinking: Bool = false
    @State private var isThinkingBlinking: Bool = true
    @State private var isViewBlinking: Bool = false

    @State private var modelInput: [[String: Any]] = []
    @State private var modelOutput: String = ""
    @State private var modelOutputError: String = ""
    @State private var modelTools: [[String: Any]] = []

    @State private var modelInputImage: NSImage? = nil
    @State private var modelInputImageBase64: String? = nil
    @State private var isZoomedModelInputImage = false

    @State private var query: String = ""
    @State private var showResponseArea: Bool = false

    let manager = ScreenshotManager()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear.frame(height: 32)
            VStack(spacing: 0) {
                inputView()
                if isFocused, showResponseArea {
                    responseView()
                }
            }
            .background(.ultraThinMaterial)
            .frame(
                width: isFocused ? 640 : 64,
                height: isFocused ? 48 + getResponseHeight() : 48,
                alignment: .topLeading
            )
            .background(Color.clear)
            .overlay(
                Group {
                    if isThinking || isViewBlinking {
                        AnimatedGradientBorder(
                            cornerRadius: getCornerRadius(),
                            lineWidth: 2.5
                        )
                    } else {
                        RoundedRectangle(cornerRadius: getCornerRadius())
                            .stroke(Color.white, lineWidth: 1.5)
                    }
                }
            )
            .cornerRadius(getCornerRadius())
            .animation(.easeInOut(duration: 0.25), value: isFocused)
            .onAppear {
                onSizeChange(getResponseHeight())
            }
            .onChange(of: isFocused) {
                // Delay size change when in focus so that other
                // views not in focus adjust height first
                if isFocused {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onSizeChange(getResponseHeight())
                    }
                } else {
                    onSizeChange(getResponseHeight())
                }
            }
            if let image = modelInputImage, isFocused {
                withAnimation {
                    contextView(image: image)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Private SubViews

    private func inputView() -> some View {
        HStack(spacing: 8) {
            LogoShape()
                .fill(isFocused ? .white : .white.opacity(0.5))
                .scaledToFit()
                .frame(width: isFocused ? 32 : 24)

            if isFocused {
                FocusableTextField(
                    text: $query,
                    isEditable: $isViewBlinking,  // Do not allow edit when model is thinking
                    onCommit: {
                        Task {
                            await handleQuery()
                        }
                    },
                    onCommandTyped: { command in
                        Task {
                            await handleCommand(type: "add", command: command)
                        }
                    },
                    onCommandRemoved: { command in
                        Task {
                            await handleCommand(type: "remove", command: command)
                        }
                    },
                    onDebouncedTextChange: { _ in
                        Task {
                            await handleCommand(type: "update", command: "")
                        }
                    }
                )
                .padding(.horizontal, 8)

                Button(action: onHelp) {
                    Image(systemName: "questionmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(height: 32)
        .padding(.horizontal, isFocused ? 24 : 20)
        .padding(.vertical, 8)
    }

    private func responseView() -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if isThinking {
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
                            text: modelOutputError.isEmpty
                                ? modelOutput : modelOutputError
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
                height: getResponseHeight()
            )
            .background(Color.black.opacity(0.3))
            .onPreferenceChange(ViewHeightKey.self) { height in
                let checkedHeight = min(max(responseHeightMin, height), responseHeightMax)

                if responseHeight < checkedHeight {
                    responseHeight = checkedHeight
                    if isFocused {
                        onSizeChange(getResponseHeight())
                    }
                }
            }
            .onChange(of: modelOutput) {
                if responseHeight == responseHeightMax {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo("BOTTOM", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private func contextView(image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(
                height: isZoomedModelInputImage ? 200 : 50,
                alignment: .leading
            )
            .clipShape(
                RoundedRectangle(cornerRadius: isZoomedModelInputImage ? getCornerRadius() : 16)
            )
            .overlay {
                RoundedRectangle(cornerRadius: isZoomedModelInputImage ? getCornerRadius() : 16)
                    .stroke(Color.white, lineWidth: 1)
            }
            .onTapGesture {
                withAnimation(
                    .spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.2)
                ) {
                    isZoomedModelInputImage.toggle()
                    incrementSizePanel(isZoomedModelInputImage ? 150 : -150)
                }
            }
            .padding(.vertical, 8)
            .onAppear {
                incrementSizePanel(64)
            }
    }

    // MARK: - Private Functions

    private func getResponseHeight() -> CGFloat {
        var height: CGFloat = 0
        if showResponseArea {
            height = min(max(responseHeightMin, responseHeight), responseHeightMax)
        }
        return height
    }

    private func getCornerRadius() -> CGFloat {
        return showResponseArea ? 24 : 32
    }

    private func handleCommand(type: String, command: String) async {
        switch type {
        case "add":
            if command == "this" || command == "selected" {
                if let (image, base64) = await manager.captureScreenUnderMouse() {
                    modelInputImage = image
                    modelInputImageBase64 = base64
                }
            }
        case "remove":
            if command == "this" || command == "selected" {
                modelInputImage = nil
                modelInputImageBase64 = nil
            }
        case "update":
            // Update screenshot while typing
            if modelInputImage != nil {
                if let (image, base64) = await manager.captureScreenUnderMouse() {
                    modelInputImage = image
                    modelInputImageBase64 = base64
                }
            }
        default:
            break
        }
    }

    private func handleQuery() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        modelOutput = ""
        modelOutputError = ""

        isThinking = true
        showResponseArea = true

        responseHeight = responseHeightMin
        onSizeChange(getResponseHeight())

        if modelInputImage == nil {

        }

        isViewBlinking = true
        await callModel(query: trimmed)
        isViewBlinking = false
    }

    // MARK: - AI Functions

    private func callModel(query: String) async {
        do {
            try await Task.sleep(nanoseconds: 200_000_000)
        } catch {
            // Sleeping just to complete debounce on typing
        }

        return await fakeData(query: query)

        let model = "claude-sonnet-4-20250514"

        guard let apiKey = Env.get("ANTHROPIC_API_KEY")
        else {
            isThinking = false
            modelOutputError = "Missing LLM API Key"
            return
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("\(apiKey)", forHTTPHeaderField: "x-api-key")
        request.setValue("extended-cache-ttl-2025-04-11", forHTTPHeaderField: "anthropic-beta")

        // query is non-empty only on first parse
        if !query.isEmpty {
            if let modelInputImageBase64 = modelInputImageBase64 {
                modelInput.append(
                    [
                        "role": "user",
                        "content": [
                            [
                                "type": "image",
                                "source": [
                                    "type": "base64",
                                    "media_type": "image/jpeg",
                                    "data": modelInputImageBase64,
                                ],
                            ]
                        ],
                    ]
                )
            }
            modelInput.append(
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": buildQuery(query: query)]
                    ],
                ]
            )
        }

        let body: [String: Any] = [
            "model": model,
            "stream": true,
            "max_tokens": 1024,
            "temperature": 0.7,
            "messages": addCacheBlock(input: modelInput, isMessage: true),
            "tools": addCacheBlock(input: modelTools),
            "system": addCacheBlock(input: buildSystemMessages()),

        ]

        print("--------")
        print("messages: \((body["messages"] as! [Any]).last ?? "")")
        print("system: \(body["system"] as! [Any])")
        print("tools_count: \((body["tools"] as! [Any]).count)")

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
                            let result = await mcp.callTools(
                                clientName: getClientName(toolName: finalToolUseName),
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

                            await callModel(query: "")
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
                    "Error streaming response: \(error.localizedDescription)"
            }
        }
    }

    private func buildQuery(query: String) -> String {
        var finalQuery = ""
        finalQuery = query.replacingOccurrences(of: "@this", with: "this")
        return finalQuery

        //        let clipboard = NSPasteboard.general.string(forType: .string) ?? ""
    }

    private func getClientName(toolName: String) -> String {
        for (clientName, tools) in allClientTools {
            for tool in tools {
                if let name = tool["name"] as? String, name == toolName {
                    return clientName
                }
            }
        }
        return ""
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

    private func buildSystemMessages() -> [[String: Any]] {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "en_US")
        let today = formatter.string(from: Date())

        let messages: [[String: Any]] = [
            [
                "type": "text",
                "text":
                    "Your name is 'AI Thing', and you are an AI assistant with a unique ability: you can understand 'this'. You use screenshots to answer questions. But never tell anyone that you use screenshots. Answer questions such that it looks like you can see the screen and are aware of what is happening.",
            ],
            [
                "type": "text",
                "text": "Today is \(today).",
            ],
            [
                "type": "text",
                "text":
                    "You are expected to behave as an agent: you can perceive user instructions, reason about available tools, and invoke them if appropriate. Do not describe the tools unless explicitly asked. You must be precise, context-aware, and avoid guessing when information is ambiguous or incomplete. You must always output in Markdown.",
            ],
        ]

        return messages
    }

    private func fakeData(query: String) async {
        var fakeContent = """
            "Vishal" can refer to several things:

            1. **As a name**: Vishal is a popular Indian name, particularly common in Hindi-speaking regions. It means "large," "vast," or "magnificent" in Sanskrit.

            2. **As a person**: There are many notable people named Vishal, including:
               - Vishal Krishna (Tamil actor and producer)
               - Various other actors, directors, and public figures

            3. **As a business**: Vishal Mega Mart is a popular retail chain in India that sells clothing, accessories, and household items.

            Could you provide more context about which "Vishal" you're asking about? That would help me give you a more specific answer.
            """

        if query == "a" {
            fakeContent += fakeContent + fakeContent
        }

        var fakePartial = ""
        for char in fakeContent {
            fakePartial += String(char)
            await MainActor.run {
                isThinking = false
                modelOutput = fakePartial + " " + shimmerPlaceholder()
            }
            do {
                try await Task.sleep(for: .milliseconds(10))
            } catch {

            }
        }
    }
}
