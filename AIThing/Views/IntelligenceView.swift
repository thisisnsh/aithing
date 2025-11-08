//
//  IntelligenceView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 11/1/25.
//

import AppKit
import MCP
import MarkdownUI
import SwiftUI
import os

struct IntelligenceView: View {
    @EnvironmentObject var mcpManager: MCPManager
    @EnvironmentObject var loginManager: LoginManager
    @EnvironmentObject var firestoreManager: FirestoreManager
    @StateObject var screenshotMonitor = ScreenshotMonitor()

    @ObservedObject var vm: NotchVM
    let tabId: String
    @Binding var allClientTools: [String: [[String: Any]]]
    @Binding var managedModels: [ModelInfo]

    let close: () -> Void
    let minimize: () -> Void
    let expand: () -> Void
    let isTabShowing: () -> Bool
    let setTabActive: (Bool) -> Void
    let updateHistoryList: () async -> Void
    let reconnectManagedAgents: () async -> Void

    let logger = Logger(subsystem: "com.thisisnsh.mac.AIThing", category: "IntelligenceView")
    let cornerRadius: CGFloat = 24

    @State private var tabTitle: String = "New Chat"
    @State private var inputHeight: CGFloat = 24
    private let baseHeight: CGFloat = 24
    @State private var textSize: CGFloat = 14

    @State private var isThinking: Bool = false
    @State private var isThinkingBlinking: Bool = false

    @State private var history: History?
    @State private var modelInput: [[String: Any]] = []
    @State private var modelOutput: String = ""
    @State private var modelContext: [DroppedContent] = []
    @State private var toolCall: String = ""

    @State private var query: String = ""
    @State private var displayQuery: String = ""
    @State private var selectedText: String = ""

    @State private var isDropping: Bool = false

    @State private var showMcpTools: Bool = false
    @State private var hoverMcpTools: Bool = false

    // Trafic Light
    @State private var hoverRed: Bool = false
    @State private var hoverYellow: Bool = false
    @State private var hoverGreen: Bool = false

    var body: some View {
        ZStack {
            if #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .glassEffect(
                        .regular.tint(.black),
                        in: RoundedRectangle(cornerRadius: cornerRadius)
                    )
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.white.opacity(0.1))
            }

            VStack {
                TitleView()
                    .padding(8)

                Divider()
                    .padding(.horizontal, -8)

                if showMcpTools {
                    ToolsView(cornerRadius: cornerRadius - 4)
                        .environmentObject(mcpManager)
                } else {
                    ResponseView()
                        .padding(.vertical, -8)
                }

                Spacer()

                if #available(macOS 26.0, *) {
                    InputView()
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius - 4))
                } else {
                    InputView()
                        .background(.white.opacity(0.1))
                        .cornerRadius(cornerRadius - 4)
                }

            }
            .padding(8)
            .task {
                modelOutput = ""
                displayQuery = ""
                toolCall = ""
                history = await HistoryStore.shared.get(id: tabId)
                guard let history = history else { return }
                modelInput = history.history
                tabTitle = tabId  // history.title ?? "New Chat"

                let notification = await firestoreManager.getNotification() ?? ""
                if !notification.isEmpty {
                    modelOutput = notification
                }
            }
            .onChange(of: vm.selectedText) { text in
                if isTabShowing() {
                    selectedText = text
                }
            }
            .onReceive(screenshotMonitor.$latestScreenshot) { ss in
                if isTabShowing() {
                    if let ss = ss {
                        Task {
                            let results = await DragFileManager.processPaths([ss.url])
                            for r in results {
                                modelContext.insert(r, at: 0)
                            }
                        }
                    }
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                if isTabShowing() {
                    Task {
                        let results = await DragFileManager.processPaths(urls)
                        for r in results {
                            modelContext.append(r)
                        }
                    }
                }

                // You can’t know yet, so just return true to accept the drop.
                return true
            } isTargeted: {
                if isTabShowing() {
                    isDropping = $0
                }
            }
        }
    }

    private func TitleView() -> some View {
        HStack {
            Circle()
                .frame(width: 12, height: 12)
                .foregroundStyle(hoverRed ? .red.opacity(0.5) : .red)
                .onTapGesture { close() }
                .onHover { hoverRed = $0 }

            Circle()
                .frame(width: 12, height: 12)
                .foregroundStyle(hoverYellow ? .yellow.opacity(0.5) : .yellow)
                .onTapGesture { minimize() }
                .onHover { hoverYellow = $0 }

            Circle()
                .frame(width: 12, height: 12)
                .foregroundStyle(hoverGreen ? .green.opacity(0.5) : .green)
                .onTapGesture { expand() }
                .onHover { hoverGreen = $0 }

            Text(tabTitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.leading, 8)

            Spacer()
        }
        .frame(height: 16)
    }

    private func ResponseView() -> some View {
        ChatView(
            history: $history,
            isThinking: $isThinking,
            isThinkingBlinking: $isThinkingBlinking,
            textSize: $textSize,
            query: $displayQuery,
            modelOutput: $modelOutput,
            toolCall: $toolCall
        )
    }

    private func ContextView() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(modelContext.indices.reversed(), id: \.self) { index in
                    let context = modelContext[index]
                    switch context {
                    case .image(let name, let image, _):
                        FilePill(
                            index: index,
                            name: name,
                            image: image,
                            big: modelContext.count == 1,
                            onDelete: { index in
                                modelContext.remove(at: index)
                                AnalyticsManager.shared.customEvent(
                                    type: .action,
                                    primary: "file_remove"
                                )
                            },
                            cornerRadius: cornerRadius
                        )

                    case .pdf(let name, _, let images, _):
                        FilePill(
                            index: index,
                            name: name,
                            image: images[0],
                            big: modelContext.count == 1,
                            onDelete: { index in
                                modelContext.remove(at: index)
                                AnalyticsManager.shared.customEvent(
                                    type: .action,
                                    primary: "file_remove"
                                )
                            },
                            cornerRadius: cornerRadius
                        )

                    case .text(let name, _, let image):
                        FilePill(
                            index: index,
                            name: name,
                            image: image,
                            big: modelContext.count == 1,
                            onDelete: { index in
                                modelContext.remove(at: index)
                                AnalyticsManager.shared.customEvent(
                                    type: .action,
                                    primary: "file_remove"
                                )
                            },
                            cornerRadius: cornerRadius
                        )
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, -8)
        .clipShape(
            RoundedRectangle(
                cornerRadius: modelContext.count == 1 ? cornerRadius - 8 : cornerRadius
            )
        )
    }

    private func InputView() -> some View {
        VStack(alignment: .leading) {
            if modelContext.count > 0 {
                ContextView()
            }

            if !selectedText.isEmpty {
                ScrollView {
                    MarkdownText(text: "```\n\(selectedText)\n```", noBackground: true)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .textSelection(.enabled)
                }
                .background(.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius - 8))
                .frame(minHeight: 16, maxHeight: 64)
                .overlay(alignment: .topLeading) {
                    Button {
                        selectedText = ""
                    } label: {
                        Image(systemName: "xmark")
                            .resizable()
                            .frame(width: 12, height: 12)
                            .foregroundStyle(.black)
                            .padding(2)
                            .background(.white)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            ZStack(alignment: .leading) {
                if !isThinking, !isDropping {
                    InputTextView(
                        text: $query,
                        seenCommands: .constant([]),
                        size: $textSize,
                        isNotEditable: isThinking || isDropping,
                        onCommit: {
                            Task {
                                await handleQuery()
                            }
                        },
                        onCommandTyped: { _ in },
                        onCommandRemoved: { _ in },
                        onDebouncedTextChange: { _ in },
                        onSpillover: { count in
                            if count >= 2 && count <= 5 {
                                inputHeight = CGFloat(count) * baseHeight
                            } else if count > 5 {
                                inputHeight = 5 * baseHeight
                            } else {
                                inputHeight = baseHeight
                            }
                        }
                    )
                    .onChange(of: query) { _ in }
                }

                if query.isEmpty {
                    Text(
                        isThinking
                            ? "Thinking..."
                            : (isDropping
                                ? "Drop files here..." : "Ask anything on AI Thing...")
                    )
                    .foregroundColor(isDropping ? .blue : .white.opacity(0.6))
                    .font(.system(size: textSize, weight: .medium))
                    .padding(.top, 2)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(height: inputHeight)
            .padding(.vertical, 8)

            HStack {
                Button(action: { showMcpTools.toggle() }) {
                    HStack {
                        Image(systemName: "hammer.fill")
                            .resizable()
                            .frame(width: 12, height: 12)
                            .foregroundStyle(hoverMcpTools ? .black : .white)

                        Text("MCP Tools")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(hoverMcpTools ? .black : .white)
                    }
                    .padding(8)
                    .padding(.horizontal, 4)
                    .background(hoverMcpTools ? .white : .white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { hoverMcpTools = $0 }

                Spacer()
            }
        }
        .padding(8)
        .overlay(
            Group {
                if isThinking {
                    AnimatedGradientBorder(
                        cornerRadius: cornerRadius - 4,
                        lineWidth: 1.5,
                        color: .white
                    )
                } else if isDropping {
                    AnimatedGradientBorder(
                        cornerRadius: cornerRadius - 4,
                        lineWidth: 1.5,
                        color: .blue
                    )
                }
            }
        )
    }
}

extension IntelligenceView {
    private func handleQuery() async {
        if !isTabShowing() { return }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        displayQuery = trimmed
        modelOutput = ""
        isThinking = true
        toolCall = ""
        vm.selectedText = ""

        setTabActive(true)
        let result = await callModel(query: trimmed)
        setTabActive(false)

        query = ""
        await updateHistoryList()
        isThinking = false
        history = await HistoryStore.shared.get(id: tabId)
        if result {
            modelOutput = ""
        }
        displayQuery = ""
        toolCall = ""
        selectedText = ""
    }

    private func callModel(query: String) async -> Bool {
        // Check if version is breakglassed
        if await firestoreManager.getBreakglass() {
            isThinking = false
            await animateOutput(
                content: """
                    This version has been disabled due to an internal issue.
                    We apologize for the inconvenience. The app will be re-enabled soon.
                    For updates, please contact help@aithing.dev.
                    """
                ,
                notification: true
            )
            AnalyticsManager.shared.customEvent(
                type: .error,
                primary: "breakglass_enabled",
                secondary: .status_failure_low,
            )
            return false
        }

        // Check if version is expired
        if await firestoreManager.getExpired() {
            isThinking = false
            await animateOutput(
                content: """
                    Current version has expired.
                    Please [upgrade the version](https://aithing.dev/upgrade) to enjoy new features and continue using the app.
                    """
                ,
                notification: true
            )
            AnalyticsManager.shared.customEvent(
                type: .error,
                primary: "version_expired",
                secondary: .status_failure_low,
            )
            return false
        }

        var appUser: AppUser?
        switch loginManager.authState {
        case .signedIn(let user):
            if let profile = await firestoreManager.getProfile(user: user) {
                // Check if profile is blocked
                if profile.blocked {
                    isThinking = false
                    await animateOutput(
                        content: """
                            You access has been disabled. We apologize for the inconvenience.
                            Please contact help@aithing.dev for more information.
                            """
                        ,
                        notification: true
                    )
                    return false
                }

                appUser = user
                AnalyticsManager.shared.setUserId(user.uid)
                break
            }

            isThinking = false
            await animateOutput(
                content: """
                    Something went wrong. Please log out and log in again. 
                    Report issue at help@aithing.dev
                    """
                ,
                notification: true
            )
            AnalyticsManager.shared.customEvent(
                type: .error,
                primary: "profile_fetch",
                secondary: .status_failure_high,
            )
            return false
        default:
            isThinking = false
            await animateOutput(
                content: """
                    ### 👋 Welcome to **AI Thing**

                    I’m your personal AI assistant — built to handle everything from simple tasks to complex automations.
                    With multiple AI models and specialized agents, I can work in the background to get things done securely.

                    **Please log in from Settings to continue.**

                    [aithing.dev](https://aithing.dev) • [Privacy Policy](https://aithing.dev/privacy)                
                    """
                ,
                notification: true
            )
            AnalyticsManager.shared.customEvent(
                type: .error,
                primary: "query_without_login",
                secondary: .status_failure_low,
            )
            return false
        }

        do {
            // Sleeping just to complete debounce on typing
            try await Task.sleep(nanoseconds: 200_000_000)
        } catch {}

        // Load latest tools
        await reconnectManagedAgents()
        let modelAgentCount = allClientTools.keys.count
        let modelTools = allClientTools.values.flatMap { $0 }

        let model = getModel()

        AnalyticsManager.shared.customEvent(
            type: .model,
            primary: model,
            secondary: .byok_model
        )

        guard let apiKey = getAnthropicAPIKey(), !apiKey.isEmpty
        else {
            let modelTitle = getModelTitle(getModel(), all: managedModels)

            isThinking = false
            await animateOutput(
                content: """
                    API key not found.

                    You have selected the \(modelTitle) model in **Settings** under the *"Use Own API Key"* section in the **Models** tab.

                    This model requires you to provide an API key.

                    You can create one at: https://console.anthropic.com/settings/keys

                    For setup instructions, visit: https://aithing.dev/quickstart
                    """
                ,
                notification: true
            )
            AnalyticsManager.shared.customEvent(
                type: .error,
                primary: "missing_api_key",
                secondary: .status_failure_low
            )
            return false
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return true }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("\(apiKey)", forHTTPHeaderField: "x-api-key")
        request.setValue("extended-cache-ttl-2025-04-11", forHTTPHeaderField: "anthropic-beta")

        var fileCount = 0
        // query is non-empty only on first parse
        if !query.isEmpty {
            for i in 0..<modelContext.count {
                switch modelContext[i] {
                case .image(_, _, let base64):
                    fileCount += 1
                    AnalyticsManager.shared.customEvent(type: .tab, primary: "file_upload_image")
                    modelInput.append(
                        [
                            "role": "user",
                            "content": [
                                [
                                    "type": "image",
                                    "source": [
                                        "type": "base64",
                                        "media_type": "image/jpeg",
                                        "data": base64,
                                    ],
                                ]
                            ],
                        ]
                    )
                case .pdf(_, _, _, let base64s):
                    fileCount += 1
                    for base64 in base64s {
                        AnalyticsManager.shared.customEvent(
                            type: .tab,
                            primary: "file_upload_pdf_page"
                        )
                        modelInput.append(
                            [
                                "role": "user",
                                "content": [
                                    [
                                        "type": "image",
                                        "source": [
                                            "type": "base64",
                                            "media_type": "image/jpeg",
                                            "data": base64,
                                        ],
                                    ]
                                ],
                            ]
                        )
                    }
                case .text(let name, let text, _):
                    fileCount += 1
                    AnalyticsManager.shared.customEvent(type: .tab, primary: "file_upload_text")
                    modelInput.append(
                        [
                            "role": "user",
                            "content": [
                                [
                                    "type": "text",
                                    "text": "File \(name) content:\n\n\(text)",
                                ]
                            ],
                        ]
                    )
                }
            }

            if !selectedText.isEmpty {
                modelInput.append(
                    [
                        "role": "user",
                        "content": [
                            [
                                "type": "text",
                                "text": "Selected text:\n\n\(selectedText)",
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
            "max_tokens": getOutputToken(),
            "temperature": 0.7,
            "messages": addCacheBlock(input: nonUsageMessages(from: modelInput), isMessage: true),
            "tools": addCacheBlock(input: modelTools),
            "system": addCacheBlock(input: buildSystemMessages()),

        ]

        // Cost Calculation
        let costPerQuery = getModelCost(getModel(), all: managedModels)
        let costPerFile = getModelCostImage(getModel(), all: managedModels)
        let costFile = costPerFile * fileCount
        let costAgent = costPerQuery * modelAgentCount
        let _ = costPerQuery + costAgent + costFile

        logger.debug("api key: \(apiKey)")
        logger.debug("model: \(model)")
        logger.debug("max tokens: \(getOutputToken())")
        logger.debug("messages: \(String(describing: body["messages"]))")
        logger.debug("tools count: \((body["tools"] as? [[String: Any]])?.count ?? 0)")
        // logger.debug("cost query: \(costPerQuery) file: \(costFile) agent: \(costAgent) total: \(total)")

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (stream, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse
            else {
                isThinking = false
                await animateOutput(
                    content: "Invalid response\n\nReport issue at help@aithing.dev",
                    notification: true
                )
                AnalyticsManager.shared.customEvent(
                    type: .error,
                    primary: "response_invalid",
                    secondary: .status_failure_high,
                )
                return false
            }

            if httpResponse.statusCode != 200 {
                isThinking = false
                var error = ""
                for try await line in stream.lines {
                    error += line
                }
                if httpResponse.statusCode == 429 {
                    await animateOutput(
                        content: """
                            You’ve reached your API key’s rate limit.

                            Learn more: https://console.anthropic.com/settings/limits
                            """
                        ,
                        notification: true
                    )
                    AnalyticsManager.shared.customEvent(
                        type: .error,
                        primary: "response_rate_limit",
                        secondary: .status_failure_low
                    )
                } else {
                    await animateOutput(
                        content:
                            "Error \(httpResponse.statusCode)\n\(error)\n\nReport issue at help@aithing.dev",
                        notification: true
                    )
                    AnalyticsManager.shared.customEvent(
                        type: .error,
                        primary: "response_failure",
                        secondary: .status_failure_high,
                    )
                }
                return false
            }

            if let appUser {
                let usage = Usage(
                    query: (query.isEmpty ? 0 : 1),
                    agentUse: (query.isEmpty ? 1 : 0),
                    filesAttached: fileCount
                )
                await firestoreManager.incrementUsage(user: appUser, usage: usage)
                modelInput.append([
                    "role": "usage",
                    "content": [
                        [
                            "type": "text",
                            "text": """
                            Total Usage:
                            1 \(query.isEmpty ? "Agent Use" : "Query")
                            \(fileCount) Attached Files                                
                            """,
                        ]
                    ],
                ])

            } else {
                AnalyticsManager.shared.customEvent(
                    type: .error,
                    primary: "cost_not_calculated",
                    secondary: .status_failure_high,
                )
            }

            modelContext.removeAll()

            // Store the current input
            await HistoryStore.shared.store(
                id: tabId,
                title: tabTitle,
                history: modelInput
            )
            // Fetch and display it
            modelOutput = ""
            displayQuery = ""
            toolCall = ""
            history = await HistoryStore.shared.get(id: tabId)

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
                            finalResponse += String(text)
                            await MainActor.run {
                                modelOutput = finalResponse + " " + shimmerPlaceholder()
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

                            await createTitle(
                                query: modelOutput,
                                model: model,
                                apiKey: apiKey,
                                byok: true
                            )

                            await HistoryStore.shared.store(
                                id: tabId,
                                title: tabTitle,
                                history: modelInput
                            )
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

                            toolCall = "Calling tool: \(finalToolUseName)..."
                            let result = await mcpManager.callTools(
                                clientName: getClientName(toolName: finalToolUseName),
                                name: finalToolUseName,
                                input: finalToolUseInputParam
                            )

                            AnalyticsManager.shared.customEvent(
                                type: .tab,
                                primary: "query_tool_called"
                            )
                            AnalyticsManager.shared.customEvent(
                                type: .tool,
                                primary: finalToolUseName,
                            )

                            logger.debug("Call tool: \(finalToolUseName)")
                            logger.debug("Tool input: \(finalToolUseInputParam)")
                            logger.debug("Tool output: \(result)")

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

                            let rc = await callModel(query: "")
                            return rc

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
                modelOutput =
                    "Error streaming response: \(error.localizedDescription)\n\nReport issue at help@aithing.dev"
            }
            return false
        }
        return true
    }

    private func buildQuery(query: String) -> String {
        return query
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
        if !getCacheMessages() {
            return input
        }

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
                    """
                ## Identity  
                - Your name is **AI Thing**.  
                - You are an AI tool with a special abilities. 
                - You can handle simple, complex or repetitive tasks in background.                
                - You have multiple AI models and agents that users can use for their tasks. 
                - You are secure and store all data locally. 
                - Website: aithing.dev
                - Privacy Policy: aithing.dev/privacy                                                 
                """,
            ],
            [
                "type": "text",
                "text": "## Today is \(today).",
            ],
            [
                "type": "text",
                "text":
                    """
                ## Behavior Rules  
                - Act as an **agent**: perceive instructions, reason, and invoke tools when needed.  
                - Be **precise, context-aware**, and never guess if info is missing.                   
                """,
            ],
            [
                "type": "text",
                "text":
                    """
                ## Answer Style  
                - Keep answers **brief** by default.  
                - Only elaborate when explicitly asked.  
                - If in doubt, **ask first** before expanding with detail.  
                - Output response in Markdown.  
                """,
            ],
        ]

        return messages
    }

    private func createTitle(query: String, model: String, apiKey: String, byok: Bool) async {
        if !tabTitle.isEmpty && tabTitle != "New Chat" {
            return
        }

        // Check if version is breakglassed
        if await firestoreManager.getBreakglass() {
            return
        }

        // Check if version is expired
        if await firestoreManager.getExpired() {
            return
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("\(apiKey)", forHTTPHeaderField: "x-api-key")
        request.setValue("extended-cache-ttl-2025-04-11", forHTTPHeaderField: "anthropic-beta")

        let input = [
            [
                "role": "user",
                "content": [
                    ["type": "text", "text": buildQuery(query: query)]
                ],
            ]
        ]

        var bestModel = model
        if let cheapestModel = getCheapestModel(in: managedModels), !byok {
            bestModel = cheapestModel.id
        }

        let body: [String: Any] = [
            "model": bestModel,
            "stream": false,
            "max_tokens": 10,
            "temperature": 0.7,
            "messages": input,
            "system":
                "Generate a concise title of no more than 18 characters. Do not include quotation marks or any extra text. Output only the title, nothing else. If you can not generate the title output \"New Chat\"",
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                (200..<300).contains(httpResponse.statusCode)
            else {
                logger.error("Bad HTTP response")
                return
            }

            // Parse JSON manually
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let contentArray = json["content"] as? [[String: Any]]
            {
                // Find the first item with type = "text"
                for item in contentArray {
                    if let type = item["type"] as? String, type == "text",
                        let text = item["text"] as? String
                    {
                        tabTitle = text
                        return
                    }
                }
            }
            return
        } catch {
            return
        }
    }

    private func animateOutput(content: String, notification: Bool) async {
        var partial = ""
        for text in content.split(separator: " ") {
            partial += String(text) + " "
            await MainActor.run {
                modelOutput = partial + " " + shimmerPlaceholder()
            }
            do {
                try await Task.sleep(for: .milliseconds(10))
            } catch {}
        }
        modelOutput = partial
    }
}
