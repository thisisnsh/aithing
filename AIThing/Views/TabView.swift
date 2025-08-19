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
    @EnvironmentObject var firestoreManager: FirestoreManager

    @Binding var isFocused: Bool
    var tabId: UUID
    var tabHistory: History?
    @Binding var allTabs: [TabItem]
    @Binding var allClientTools: [String: [[String: Any]]]
    @Binding var managedModels: [ModelInfo]

    @Binding var showSettings: Bool
    @Binding var showHistory: Bool

    var onClick: (_ tabId: UUID) -> Void
    var onSetting: () -> Void
    var onHelp: () -> Void
    var updatePanelSizeFromDefault: (CGFloat) -> Void
    var updatePanelSizeFromCurrent: (CGFloat) -> Void
    let setPanelPassthrough: (_ enabled: Bool) -> Void

    private func updatePassthrough(inside: Bool) {
        setPanelPassthrough(!inside)
    }

    @State private var tabTitle: String?

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

    @State private var modelImageCount: Int = 0
    @State private var modelInputImage: NSImage? = nil
    @State private var modelInputImageBase64: String? = nil
    @State private var isZoomedModelInputImage = false

    @State private var query: String = ""
    @State private var seenCommands: Set<String> = []
    @State private var showResponseArea: Bool = false

    @State private var showDragIcon: Bool = false

    @State private var selectionContext: Bool = false
    @State private var selectedText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear.frame(height: 32).overlay(alignment: .bottom) {
                if showDragIcon {
                    Image(systemName: "square.grid.3x2.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .onHover { inside in
                            if inside {
                                NSCursor.openHand.set()
                            } else {
                                NSCursor.arrow.set()
                            }
                            updatePassthrough(inside: inside)
                        }
                }
            }
            .onHover { inside in
                showDragIcon = inside
            }

            VStack(alignment: .leading, spacing: 0) {
                inputView()
                    .onHover { inside in
                        updatePassthrough(inside: inside)
                    }
                if isFocused, showResponseArea {
                    responseView()
                        .onHover { inside in
                            updatePassthrough(inside: inside)
                        }
                }
            }
            .background(.ultraThinMaterial)
            .frame(
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
                    } else {
                        RoundedRectangle(cornerRadius: getCornerRadius())
                            .stroke(Color.white, lineWidth: 1.5)
                    }
                }
            )
            .cornerRadius(getCornerRadius())
            .animation(.easeInOut(duration: 0.25), value: isFocused)
            .onAppear {
                DispatchQueue.main.async {
                    updatePanelSizeFromDefault(getResponseHeight())
                }
                if let tabHistory {
                    modelInput = tabHistory.history
                    modelOutput = assistantMessages(from: tabHistory.history)
                    if !modelOutput.isEmpty {
                        showResponseArea = true
                    }
                    tabTitle = tabHistory.title
                }
                AnalyticsManager.shared.screenView(
                    screenName: "tab_view",
                    screenClass: "tab_view"
                )
            }
            .onChange(of: isFocused) { newValue in
                // Delay size change when in focus so that other
                // views not in focus adjust height first
                if isFocused {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        updatePanelSizeFromDefault(getResponseHeight())
                    }
                } else {
                    DispatchQueue.main.async {
                        updatePanelSizeFromDefault(getResponseHeight())
                    }
                }
            }

            if let image = modelInputImage, isFocused {
                contextView(image: image)
                    .onHover { inside in
                        updatePassthrough(inside: inside)
                    }
            }
        }
        .onTapGesture {
            if !isFocused {
                onClick(tabId)
            }
        }
    }

    private func inputView() -> some View {
        HStack(spacing: 8) {
            LogoShape()
                .fill(isFocused && !showSettings && !showHistory ? .white : .white.opacity(0.5))
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
                        text: showSettings
                            ? .constant("Settings") : (showHistory ? .constant("History") : $query),
                        seenCommands: $seenCommands,
                        isNotEditable: isViewBlinking || showSettings || showHistory,
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
                            updatePanelSizeFromCurrent(newHeight - inputHeight)
                            inputHeight = newHeight
                        }
                    )
                    .opacity(showSettings || showHistory ? 0.6 : 1)
                    .frame(width: 526)

                    if query.isEmpty && !showSettings && !showHistory {
                        Text(
                            tabHistory?.history.isEmpty ?? true
                                ? "Ask anything on this AI Thing..." : "Continue conversation..."
                        )
                        .foregroundColor(.white.opacity(0.6))
                        .font(.system(size: 18, weight: .medium))
                        .padding(.leading, 6)
                    }
                }

                Button(
                    action: {
                        if modelOutput.isEmpty {
                            onHelp()
                            AnalyticsManager.shared.customEventTab(action: "tab_click_help")
                        } else {
                            copyToClipboard(string: modelOutput)
                            AnalyticsManager.shared.customEventTab(action: "tab_click_copy")
                        }
                    }
                ) {
                    Image(
                        systemName: modelOutput.isEmpty || showSettings || showHistory
                            ? "questionmark.circle.fill" : "document.on.document.fill"
                    )
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 18, height: 18)

            } else if let tabTitle, !tabTitle.isEmpty {
                Text(tabTitle)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.5))
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
                        MarkdownText(text: modelOutput)
                            .foregroundColor(.white)
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
            .frame(width: 24 + 32 + 8 + 526 + 8 + 18 + 24, height: getResponseHeight())
            .background(Color.black.opacity(0.3))
            .onPreferenceChange(ViewHeightKey.self) { height in
                let checkedHeight = min(max(responseHeightMin, height), responseHeightMax)

                if responseHeight < checkedHeight {
                    responseHeight = checkedHeight
                    if isFocused {
                        DispatchQueue.main.async {
                            updatePanelSizeFromDefault(getResponseHeight())
                        }
                    }
                }
            }
            .onChange(of: modelOutput) { newValue in
                if responseHeight == responseHeightMax {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
                        updatePanelSizeFromCurrent(isZoomedModelInputImage ? 150 : -150)
                    }
                }
                .padding(.vertical, 8)
                .onAppear {
                    updatePanelSizeFromCurrent(64)
                }

            Button(action: {
                updatePanelSizeFromCurrent(-64)
                if isZoomedModelInputImage {
                    updatePanelSizeFromCurrent(-150)
                }
                isZoomedModelInputImage = false
                modelInputImage = nil
                modelInputImageBase64 = nil
                AnalyticsManager.shared.customEventTab(action: "tab_image_remove")
            }) {
                Image(systemName: "xmark.circle.fill")
                    .frame(width: 12, height: 12)
                    .padding(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

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
                if let (image, base64) =
                    await screenshotManager.captureSelectedScreenUnderMouse()
                {
                    modelInputImage = image
                    modelInputImageBase64 = base64
                    AnalyticsManager.shared.customEventTab(action: "tab_image_add_selected")
                } else {
                    AnalyticsManager.shared.customError(
                        type: "failure_tab_image_add_selected",
                        severity: "high",
                        location: "tab_view"
                    )
                }
            } else if command == "@selected" {
                screenshotManager.cancelScreenshot()
                modelInputImage = nil
                modelInputImageBase64 = nil

                selectionContext = true
                selectedText = ""
            }
        case "remove":
            if command == "@this" {
                screenshotManager.cancelScreenshot()
                modelInputImage = nil
                modelInputImageBase64 = nil
            } else if command == "@selected" {
                selectionContext = false
                selectedText = ""
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

        isThinking = true
        showResponseArea = true

        responseHeight = responseHeightMin
        DispatchQueue.main.async {
            updatePanelSizeFromDefault(getResponseHeight())
        }

        AnalyticsManager.shared.customEventTab(action: "tab_query_handle_start")

        isViewBlinking = true
        await callModel(query: trimmed)
        isViewBlinking = false

        AnalyticsManager.shared.customEventTab(action: "tab_query_handle_end")
    }

    private func callModel(query: String) async {
        // Check if version is breakglassed
        if await firestoreManager.getBreakglass() {
            isThinking = false
            await animateOutput(
                content: """
                    This version has been disabled due to an internal issue.
                    We apologize for the inconvenience. The app will be re-enabled soon.
                    For updates, please contact help@aithing.dev.
                    """
            )
            AnalyticsManager.shared.customError(
                type: "breakglass_enabled",
                severity: "low",
                location: "tab_view"
            )
            return
        }

        // Check if version is expired
        if await firestoreManager.getExpired() {
            isThinking = false
            await animateOutput(
                content: """
                    Current version has expired.
                    Please [upgrade the version](https://aithing.dev/upgrade) to enjoy new features and continue using the app.
                    """
            )
            AnalyticsManager.shared.customError(
                type: "version_expired",
                severity: "low",
                location: "tab_view"
            )
            return
        }

        let profileErrorMessage = """
            Something went wrong. Please log out and log in again. 

            Report issue at help@aithing.dev
            """

        let creditErrorMessage = """
            You don’t have enough credits. Please [purchase more credits](https://get.aithing.dev) to continue.

            Learn more about [usage and credits](https://aithing.dev/billing/usage).
            """

        let loginPromptMessage = """
            Please log in to receive **free credits.** 

            1. Open **Settings** by pressing `Control (^) + S`
            2. Click on **Google** to log in using your Google account

            Read our [Privacy Policy](https://aithing.dev/privacy)
            """

        var apiKeyManaged = ""
        var appUser: AppUser?

        switch loginManager.authState {
        case .signedIn(let user):
            if let profile = await firestoreManager.getProfile(user: user) {
                let creditsPlans = await firestoreManager.fetchCreditsPlans(
                    email: profile.email
                )
                let creditsTotal = profile.creditsTotal + creditsPlans

                if profile.blocked {
                    isThinking = false
                    await animateOutput(
                        content: """
                            You access has been disabled. We apologize for the inconvenience.
                            Please contact help@aithing.dev.
                            """
                    )
                    return
                }

                if profile.creditsUsed >= creditsTotal {
                    isThinking = false
                    await animateOutput(content: creditErrorMessage)
                    AnalyticsManager.shared.customError(
                        type: "credits_not_enough",
                        severity: "high",
                        location: "tab_view"
                    )
                    return
                }

                appUser = user
                apiKeyManaged = profile.apiKeyAnthropic
                AnalyticsManager.shared.setUserId(user.uid)
                break
            }

            isThinking = false
            await animateOutput(content: profileErrorMessage)
            AnalyticsManager.shared.customError(
                type: "profile_error",
                severity: "high",
                location: "tab_view"
            )
            return
        default:
            isThinking = false
            await animateOutput(content: loginPromptMessage)
            AnalyticsManager.shared.customError(
                type: "query_without_login",
                severity: "low",
                location: "tab_view"
            )
            return
        }

        // Check if tab is alive, else return without processing
        if !allTabs.contains(where: { $0.id == tabId }) {
            isThinking = false
            print("Exiting callModel for \(tabId) as it was closed")
            AnalyticsManager.shared.customEventTab(action: "query_stop_on_close")
            return
        }

        do {
            // Sleeping just to complete debounce on typing
            try await Task.sleep(nanoseconds: 200_000_000)
        } catch {}

        // Load latest tools
        let modelTools = allClientTools.values.flatMap { $0 }

        // Fake data // DEBUG_MODE
        // await callModel(query: query + "X")
        // return await fakeData(query: query)

        let byok = getByokSelected()
        let model = getModel()

        AnalyticsManager.shared.customEventModel(
            name: model,
            type: byok ? "byok" : "managed"
        )

        guard let apiKey = byok ? getAnthropicAPIKey() : apiKeyManaged, !apiKey.isEmpty
        else {
            var apiErrorMessage = ""
            let modelTitle = getModelTitle(getModel(), all: managedModels)
            if byok {
                apiErrorMessage = """
                    API key not found.

                    You have selected the \(modelTitle) model in **Settings** under the *"Use Own API Key"* section in the **Models** tab.

                    This model requires you to provide an API key.

                    You can create one at: https://console.anthropic.com/settings/keys

                    For setup instructions, visit: https://aithing.dev/quickstart
                    """
            } else {
                apiErrorMessage = """
                    API key not found. Please quit and restart the app.

                    1. Open **Settings** by pressing `Control (^) + S`
                    2. Click **Quit** in the bottom-left corner
                    3. Reopen **AI Thing** from the Applications folder

                    Report issue at help@aithing.dev
                    """
            }

            isThinking = false
            await animateOutput(content: apiErrorMessage)
            AnalyticsManager.shared.customError(
                type: "missing_api_key",
                severity: byok ? "low" : "high",
                location: "tab_view"
            )
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
                modelImageCount += 1
            }

            if selectionContext {
                selectedText = TypingManager.shared.getSelectedText() ?? ""
                if !selectedText.isEmpty {
                    print("selectedText", selectedText)
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
                } else {
                    isThinking = false
                    await animateOutput(
                        content:
                            "No selection found. This feature is in development. Please report issues at help@aithing.dev"
                    )
                    AnalyticsManager.shared.customError(
                        type: "query_no_selection_found",
                        severity: "low",
                        location: "tab_view"
                    )
                    return
                }
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

        // print("apiKey:", apiKey)
        // print("model:", model)
        // print("cost:", getModelCost(getModel()))
        // print("messages:", body["messages"] as! [[String: Any]])
        // print("tools:", (body["tools"] as! [[String: Any]]).count)

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (stream, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse
            else {
                isThinking = false
                await animateOutput(content: "Invalid response\n\nReport issue at help@aithing.dev")
                AnalyticsManager.shared.customError(
                    type: "response_invalid",
                    severity: "high",
                    location: "tab_view"
                )
                return
            }

            if httpResponse.statusCode != 200 {
                isThinking = false
                var error = ""
                for try await line in stream.lines {
                    error += line
                }
                if httpResponse.statusCode == 429 {
                    if byok {
                        await animateOutput(
                            content: """
                                You’ve reached your API key’s rate limit.

                                Learn more: https://console.anthropic.com/settings/limits
                                """
                        )
                    } else {
                        await animateOutput(
                            content: """
                                The system is under heavy load. Please try again in a minute. 

                                We apologize for the disruption. Read more about this [error](https://aithing.dev/errors/rate-limit). 
                                """
                        )
                    }
                    AnalyticsManager.shared.customError(
                        type: "response_rate_limit",
                        severity: byok ? "low" : "high",
                        location: "tab_view"
                    )
                } else {
                    await animateOutput(
                        content:
                            "Error \(httpResponse.statusCode)\n\(error)\n\nReport issue at help@aithing.dev"
                    )
                    AnalyticsManager.shared.customError(
                        type: "response_failure",
                        severity: "high",
                        location: "tab_view"
                    )
                }
                return
            }

            if let appUser {
                if !byok {
                    let cost = getModelCost(getModel(), all: managedModels)
                    let costImage = getModelCostImage(getModel(), all: managedModels)
                    print("cost:", cost + costImage * modelImageCount)
                    await firestoreManager.incrementCredits(
                        user: appUser,
                        by: cost + costImage * modelImageCount
                    )
                }
            } else {
                AnalyticsManager.shared.customError(
                    type: "cost_not_calculated",
                    severity: "high",
                    location: "tab_view"
                )
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
                            if selectionContext {
                                TypingManager.shared.typeText(stripCodeBlock(from: finalResponse))
                            }
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
                                byok: byok
                            )

                            await HistoryStore.shared.store(
                                id: tabId.uuidString,
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

                            finalResponse += "\n\n```Calling tool: \(finalToolUseName)...```\n\n"
                            await MainActor.run {
                                modelOutput = finalResponse
                            }
                            let result = await mcp.callTools(
                                clientName: getClientName(toolName: finalToolUseName),
                                name: finalToolUseName,
                                input: finalToolUseInputParam
                            )

                            AnalyticsManager.shared.customEventTab(action: "query_tool_called")

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
                modelOutput =
                    "Error streaming response: \(error.localizedDescription)\n\nReport issue at help@aithing.dev"
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
                    "Your name is 'AI Thing', and you are an AI assistant with a unique ability: you can understand 'this'. Use image that is provided in context, to answer questions. Usually the image is provided when query has \"@this\" keyword",
            ],
            [
                "type": "text",
                "text":
                    "If query has \"selected\" keyword. The query is about replacing the selected item with another one. Just output the response that will replace the selected data. # Do not create code blocks or anything fancy in the response. Output simple response that can be copy-pasted as is.",
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

    private func createTitle(query: String, model: String, apiKey: String, byok: Bool) async {
        if tabTitle != nil && !tabTitle!.isEmpty {
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
        // print("title model:", bestModel)
        let body: [String: Any] = [
            "model": bestModel,
            "stream": false,
            "max_tokens": 10,
            "temperature": 0.7,
            "messages": input,
            "system":
                "Generate a concise title of no more than 18 characters. Do not include quotation marks or any extra text. Output only the title, nothing else.",
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                (200..<300).contains(httpResponse.statusCode)
            else {
                print("Bad HTTP response")
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

    func stripCodeBlock(from text: String) -> String {
        // Regex matches:
        // - opening ``` + optional word + newline
        // - newline + closing ```
        let pattern = #"^```[\w]*\n|\n```$"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }

}
