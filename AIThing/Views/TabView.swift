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
    @EnvironmentObject var loginManager: LoginManager
    @EnvironmentObject var screenshotManager: ScreenshotManager

    @Binding var isFocused: Bool
    var tabId: UUID
    @Binding var allTabs: [TabItem]
    @Binding var allClientTools: [String: [[String: Any]]]
    @Binding var showSettings: Bool
    var onSetting: () -> Void
    var onHelp: () -> Void
    var resizePanel: (CGFloat) -> Void
    var incrementSizePanel: (CGFloat) -> Void

    @State private var inputHeight: CGFloat = 48
    @State private var imageName: String = "Logo"
    @State private var title: String = "AI Thing"

    let responseHeightMin: CGFloat = 100
    let responseHeightMax: CGFloat = 700
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
    @State private var seenCommands: Set<String> = []
    @State private var showResponseArea: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear.frame(height: 32)
            VStack(alignment: .leading, spacing: 0) {
                inputView()
                if isFocused, showResponseArea {
                    responseView()
                }
            }
            .background(.ultraThinMaterial)
            .frame(
                width: isFocused ? 640 : 64,
                height: isFocused ? inputHeight + getResponseHeight() : 48,
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
                        .frame(
                            width: isFocused ? 640 : 64,
                            height: isFocused ? inputHeight + getResponseHeight() : 48,
                            alignment: .topLeading
                        )
                    } else {
                        RoundedRectangle(cornerRadius: getCornerRadius())
                            .stroke(Color.white, lineWidth: 1.5)
                            .frame(
                                width: isFocused ? 640 : 64,
                                height: isFocused ? inputHeight + getResponseHeight() : 48,
                                alignment: .topLeading
                            )
                    }
                }
            )
            .cornerRadius(getCornerRadius())
            .animation(.easeInOut(duration: 0.25), value: isFocused)
            .onAppear {
                DispatchQueue.main.async {
                    resizePanel(getResponseHeight())
                }
            }
            .onChange(of: isFocused) {
                // Delay size change when in focus so that other
                // views not in focus adjust height first
                if isFocused {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        resizePanel(getResponseHeight())
                    }
                } else {
                    DispatchQueue.main.async {
                        resizePanel(getResponseHeight())
                    }
                }
            }

            if let image = modelInputImage, isFocused {
                contextView(image: image)
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
                .onTapGesture {
                    if isFocused {
                        onSetting()
                    }
                }

            if isFocused {
                ZStack(alignment: .leading) {
                    InputTextView(
                        text: $query,
                        seenCommands: $seenCommands,
                        isNotEditable: isViewBlinking || showSettings,
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
                        },
                        onSpillover: { count in
                            var newHeight: CGFloat = 48
                            if count == 2 {
                                newHeight = 48 + 24
                            } else if count >= 3 {
                                newHeight = 48 + 24 + 24
                            } else {
                                newHeight = 48
                            }
                            incrementSizePanel(newHeight - inputHeight)
                            inputHeight = newHeight
                        }
                    )

                    if query.isEmpty {
                        Text("Ask anything on this AI Thing...")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.system(size: 18, weight: .medium))
                            .padding(.leading, 8)
                    }
                }
                Button(
                    action: {
                        if modelOutput.isEmpty {
                            onHelp()
                        } else {
                            copyToClipboard(string: modelOutput)
                        }
                    }
                ) {
                    Image(
                        systemName: modelOutput.isEmpty
                            ? "questionmark.circle.fill" : "document.on.document.fill"
                    )
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundColor(modelOutput.isEmpty ? .white.opacity(0.5) : .white)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(height: isFocused ? inputHeight - 16 : 48)
        .padding(.horizontal, isFocused ? 24 : 20)
        .padding(.vertical, isFocused ? 8 : 0)
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
            .frame(height: getResponseHeight())
            .background(Color.black.opacity(0.3))
            .onPreferenceChange(ViewHeightKey.self) { height in
                let checkedHeight = min(max(responseHeightMin, height), responseHeightMax)

                if responseHeight < checkedHeight {
                    responseHeight = checkedHeight
                    if isFocused {
                        DispatchQueue.main.async {
                            resizePanel(getResponseHeight())
                        }
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
        ZStack {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(
                    height: isZoomedModelInputImage ? 200 : 50,
                    alignment: .leading
                )
                .background(.ultraThinMaterial)
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

            Button(action: {
                incrementSizePanel(-64)
                if isZoomedModelInputImage {
                    incrementSizePanel(-150)
                }
                isZoomedModelInputImage = false
                modelInputImage = nil
                modelInputImageBase64 = nil
            }) {
                Image(systemName: "xmark.circle.fill")
                    .frame(width: 12, height: 12)
                    .padding(8)
            }
            .buttonStyle(PlainButtonStyle())
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
            if command == "@this" {
                screenshotManager.cancelScreenshot()
                if getPreferencesCaptureFullScreen() {
                    if let (image, base64) = await screenshotManager.captureScreenUnderMouse() {
                        modelInputImage = image
                        modelInputImageBase64 = base64
                    }
                } else {
                    if let (image, base64) =
                        await screenshotManager.captureSelectedScreenUnderMouse()
                    {
                        modelInputImage = image
                        modelInputImageBase64 = base64
                    }
                }
            }
        case "remove":
            if command == "@this" {
                screenshotManager.cancelScreenshot()
                modelInputImage = nil
                modelInputImageBase64 = nil
            }
        default:
            break
        }
    }

    private func handleQuery() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        screenshotManager.cancelScreenshot()

        modelOutput = ""
        modelOutputError = ""

        isThinking = true
        showResponseArea = true

        responseHeight = responseHeightMin
        DispatchQueue.main.async {
            resizePanel(getResponseHeight())
        }

        isViewBlinking = true
        await callModel(query: trimmed)
        isViewBlinking = false
    }

    // MARK: - AI Functions

    private func callModel(query: String) async {
        // Check if user is logged in
        switch loginManager.authState {
        case .signedIn(_):
            ()
        default:
            isThinking = false
            await animateOutput(
                content: """
                    Please log in to use AI Thing. [Privacy Policy](https://aithing.dev/privacy)

                    1. Open Settings by pressing  ` ^ (Control) + S `
                    2. Click on  ` Google `
                    """
            )
            return
        }

        // Check if tab is alive, else return without processing
        if !allTabs.contains(where: { $0.id == tabId }) {
            isThinking = false
            print("Exiting callModel for \(tabId)")
            return
        }

        do {
            // Sleeping just to complete debounce on typing
            try await Task.sleep(nanoseconds: 200_000_000)
        } catch {}

        // Load latest tools
        modelTools = allClientTools.values.flatMap { $0 }

        // Fake data // DEBUG_MODE
        // await callModel(query: query + "X")
        return await fakeData(query: query)

        let model = "claude-sonnet-4-20250514"

        guard let apiKey = getAnthropicAPIKey(), !apiKey.isEmpty
        else {
            isThinking = false
            modelOutputError = "Missing Anthropic API Key"
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
        print("messages:", body["messages"] as! [[String: Any]])
        print("tools:", (body["tools"] as! [[String: Any]]).count)

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
                            print("--------")
                            print("call tool: \(finalToolUseName)")
                            print("tool input: \(finalToolUseInputParam)")

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
            [
                "type": "text",
                "text":
                    "Give brief answers until asked to elaborate. Ask before giving a detailed response.",
            ],
        ]

        return messages
    }

    private func fakeData(query: String) async {
        let fakeContent = """
            "Vishal" can refer to several things:

            1. **As a name**: Vishal is a popular Indian name, particularly common in Hindi-speaking regions. It means "large," "vast," or "magnificent" in Sanskrit.

            2. **As a person**: There are many notable people named Vishal, including:
               - Vishal Krishna (Tamil actor and producer)
               - Various other actors, directors, and public figures

            3. **As a business**: Vishal Mega Mart is a popular retail chain in India that sells clothing, accessories, and household items.

            Could you provide more context about which "Vishal" you're asking about? That would help me give you a more specific answer.
            """

        do {
            try await Task.sleep(for: .seconds(3))
        } catch {}

        isThinking = false
        await animateOutput(content: fakeContent + fakeContent)
    }

    private func animateOutput(content: String) async {
        var partial = ""
        for char in content {
            partial += String(char)
            await MainActor.run {
                modelOutput = partial + " " + shimmerPlaceholder()
            }
            do {
                try await Task.sleep(for: .milliseconds(10))
            } catch {}
        }
        modelOutput = partial
    }

    private func copyToClipboard(string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

}
