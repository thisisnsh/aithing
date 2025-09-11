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
import os

struct TabView: View {
    @EnvironmentObject var mcp: MCPManager
    @EnvironmentObject var loginManager: LoginManager
    @EnvironmentObject var screenshotManager: ScreenshotManager
    @EnvironmentObject var firestoreManager: FirestoreManager

    let logger = Logger(subsystem: "com.thisisnsh.mac.AIThing", category: "TabView")

    @Binding var isFocused: Bool
    var tabId: UUID
    var tabHistory: History?
    @Binding var allTabs: [TabItem]
    @Binding var allClientTools: [String: [[String: Any]]]
    @Binding var managedModels: [ModelInfo]

    @Binding var showSettings: Bool
    @Binding var showHistory: Bool

    let onClick: (_ tabId: UUID) -> Void
    let onSetting: () -> Void
    let onHelp: () -> Void
    let updatePanelSizeFromDefault: (CGFloat) -> Void
    let updatePanelSizeFromCurrent: (CGFloat) -> Void
    let setPanelPassthrough: (_ enabled: Bool) -> Void
    let reconnectManagedAgents: () async -> Void

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

    @State private var modelContextSubmitted: [DroppedContent] = []
    @State private var modelContext: [DroppedContent] = []
    @State private var modelContextZoomed: [Bool] = []

    @State private var query: String = ""
    @State private var seenCommands: Set<String> = []
    @State private var showResponseArea: Bool = false

    @State private var showDragIcon: Bool = false

    @State private var selectionContext: Bool = false
    @State private var selectedText: String = ""
    @State private var hereContext: Bool = false
    @State private var takingScreenshot: Bool = false
    @State private var isDropping: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 32).overlay(alignment: .bottom) {
                if showDragIcon {
                    Image(systemName: "square.grid.3x2.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .shadow(color: .black, radius: 1)
                        .onHover { inside in
                            if inside {
                                NSCursor.openHand.set()
                            } else {
                                NSCursor.arrow.set()
                            }
                            updatePassthrough(inside: inside)
                        }
                }
                if takingScreenshot {
                    Text(
                        "Click on the application to capture the entire window\nDrag to select a specific area."
                    )
                    .font(.system(size: 10, weight: .medium))
                    .multilineTextAlignment(.center)
                    .shadow(color: .black, radius: 1)
                }
            }
            .onHover { inside in
                showDragIcon = inside
            }
            .padding(.bottom, 8)

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
                    } else if isDropping {
                        RoundedRectangle(cornerRadius: getCornerRadius())
                            .stroke(Color.blue, lineWidth: 1.5)
                    } else {
                        RoundedRectangle(cornerRadius: getCornerRadius())
                            .stroke(Color.white, lineWidth: 1.5)
                    }
                }
            )
            .cornerRadius(getCornerRadius())
            .shadow(radius: 4)
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
            .task {
                let notification = await firestoreManager.getNotification() ?? ""
                if !notification.isEmpty {
                    modelOutput = notification
                    showResponseArea = true
                }
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
            .padding(.bottom, 8)

            if isFocused {
                contextView()
                    .transition(.identity)
                    .animation(nil, value: isFocused)
            }
        }
        .onTapGesture {
            if !isFocused && !showSettings && !showHistory {
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

            if isFocused {
                ZStack(alignment: .leading) {
                    if !isDropping {
                        InputTextView(
                            text: showSettings
                                ? .constant("Settings")
                                : (showHistory ? .constant("History") : $query),
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
                    }

                    if query.isEmpty && !showSettings && !showHistory && !isDropping {
                        Text(
                            tabHistory?.history.isEmpty ?? true
                                ? "Ask anything on this AI Thing..." : "Continue conversation..."
                        )
                        .foregroundColor(.white.opacity(0.6))
                        .font(.system(size: 18, weight: .medium))
                        .padding(.leading, 6)
                        .allowsHitTesting(false)
                    }

                    if isDropping {
                        Text("Drop files here...")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.system(size: 18, weight: .medium))
                            .padding(.leading, 6)
                            .allowsHitTesting(false)
                            .frame(width: 526)
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
        .dropDestination(for: URL.self) { urls, _ in
            if !isFocused { return false }

            Task {
                let results = await DragFileManager.processPaths(urls)
                for r in results {
                    modelContext.append(r)
                    modelContextZoomed.append(false)
                }
            }

            // You can’t know yet, so just return true to accept the drop.
            return true
        } isTargeted: {
            if isFocused {
                isDropping = $0
            }
        }
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
                        if !modelContextSubmitted.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(Array(modelContextSubmitted.enumerated()), id: \.offset)
                                    {
                                        (index, context) in
                                        switch context {
                                        case .image(let name, let image, _):
                                            ImageContextView(
                                                name: name,
                                                image: image,
                                                compact: true,
                                                isZoomed: false,
                                                onTap: {},
                                                onDelete: {}
                                            )
                                        case .pdf(let name, _, let images, _):
                                            PDFContextView(
                                                name: name,
                                                image: images[0],
                                                compact: true,
                                                isZoomed: false,
                                                onTap: {},
                                                onDelete: {}
                                            )
                                        case .text(let name, _, let image):
                                            if let image {
                                                ImageContextView(
                                                    name: name,
                                                    image: image,
                                                    compact: true,
                                                    isZoomed: false,
                                                    onTap: {},
                                                    onDelete: {}
                                                )
                                            } else {
                                                TextContextView(
                                                    name: name,
                                                    compact: true,
                                                    isZoomed: false,
                                                    onTap: {},
                                                    onDelete: {}
                                                )
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.top, 16)
                            }
                            .frame(height: 100)
                        }

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

    private func contextView() -> some View {
        ContextGridView(
            modelContext: $modelContext,
            modelContextZoomed: $modelContextZoomed,
            onTap: { index in
                guard index < modelContextZoomed.count else { return }
                modelContextZoomed[index].toggle()
            },
            onDelete: { index in
                modelContext.remove(at: index)
                modelContextZoomed.remove(at: index)
                AnalyticsManager.shared.customEventTab(
                    action: "tab_file_remove"
                )
            },
            updatePassthrough: { inside in
                updatePassthrough(inside: inside)
            }
        )
        .onAppear {
            updatePanelSizeFromCurrent(500)
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
                takingScreenshot = true
                if let (image, base64) =
                    await screenshotManager.captureSelectedScreenUnderMouse()
                {
                    modelContext.append(.image("screenshot", image, base64))
                    modelContextZoomed.append(false)
                    AnalyticsManager.shared.customEventTab(action: "tab_image_add_selected")
                } else {
                    AnalyticsManager.shared.customError(
                        type: "failure_tab_image_add_selected",
                        severity: "high",
                        location: "tab_view"
                    )
                }
                takingScreenshot = false
                AnalyticsManager.shared.customEventTab(action: "tab_context_add_this")
            } else if command == "@selected" {
                selectionContext = true
                selectedText = TypingManager.shared.getSelectedText() ?? ""
                AnalyticsManager.shared.customEventTab(action: "tab_context_add_selected")
            } else if command == "@here" {
                hereContext = true
                TypingManager.shared.requestAXIfNeeded()
                AnalyticsManager.shared.customEventTab(action: "tab_context_add_here")
            }
        case "remove":
            if command == "@this" {
                screenshotManager.cancelScreenshot()
                AnalyticsManager.shared.customEventTab(action: "tab_context_remove_this")
            } else if command == "@selected" {
                selectionContext = false
                selectedText = ""
                AnalyticsManager.shared.customEventTab(action: "tab_context_remove_selected")
            } else if command == "@here" {
                hereContext = false
                AnalyticsManager.shared.customEventTab(action: "tab_context_remove_here")
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
        let byok = getByokSelected()
        var creditsTotal = 0
        var creditsUsed = 0

        switch loginManager.authState {
        case .signedIn(let user):
            if let profile = await firestoreManager.getProfile(user: user) {
                let creditsPlans = await firestoreManager.fetchCreditsPlans(
                    email: profile.email
                )
                creditsTotal = profile.creditsTotal + creditsPlans

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

                creditsUsed = profile.creditsUsed
                if !byok && creditsUsed >= creditsTotal {
                    isThinking = false
                    await animateOutput(content: creditErrorMessage)
                    AnalyticsManager.shared.customError(
                        type: "credits_consumed",
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
        if isTabClosed() {
            isThinking = false
            logger.info("Exiting callModel for \(tabId) as it was closed")
            AnalyticsManager.shared.customEventTab(action: "query_stop_on_close")
            return
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

        var fileCount = 0
        // query is non-empty only on first parse
        if !query.isEmpty {
            for i in 0..<modelContext.count {
                switch modelContext[i] {
                case .image(_, _, let base64):
                    fileCount += 1
                    AnalyticsManager.shared.customEventTab(action: "file_upload_image")
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
                        AnalyticsManager.shared.customEventTab(action: "file_upload_pdf_page")
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
                    AnalyticsManager.shared.customEventTab(action: "file_upload_text")
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

            if selectionContext {
                selectedText = TypingManager.shared.getSelectedText() ?? ""
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
                } else {
                    isThinking = false
                    await animateOutput(
                        content: """
                            No selection detected. Please select again. 

                            Another reason could be that the application may not support selected text. Use `@this` to capture the selected text. 
                                                        
                            Please report issues to help@aithing.dev
                            """
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
        let total = costPerQuery + costAgent + costFile

        logger.debug("api key: \(apiKey)")
        logger.debug("model: \(model)")
        logger.debug("tokens: \(getOutputToken())")
        logger.debug("messages: \(String(describing: body["messages"]))")
        logger.debug("tools count: \((body["tools"] as? [[String: Any]])?.count ?? 0)")
        logger.debug("cost query: \(costPerQuery) file: \(costFile) agent: \(costAgent) total: \(total)")

        // Check enough credits if not BYOK
        if !byok {
            let remainingCredits = creditsTotal - creditsUsed
            if creditsUsed + total > creditsTotal {
                isThinking = false
                let creditErrorMessage = """
                    You don’t have enough credits for this query. Please [purchase more credits](https://get.aithing.dev) to continue.

                    Remaining: \(remainingCredits) Credit\(remainingCredits > 1 ? "s" : "")

                    Required: \(total) Credit\(total > 1 ? "s" : "")
                    - 1 \(query.isEmpty ? "Agent Use" : "Query"): \(costPerQuery) Credit\(costPerQuery > 1 ? "s" : "")
                    - \(fileCount) Attached Files: \(costFile) Credit\(costFile > 1 ? "s" : "")
                    - \(modelAgentCount) Agent\(modelAgentCount > 1 ? "s" : "") Enabled: \(costAgent) Credit\(costAgent > 1 ? "s" : "")

                    Learn more about [usage and credits](https://aithing.dev/billing/usage).
                    """

                await animateOutput(content: creditErrorMessage)
                AnalyticsManager.shared.customError(
                    type: "credits_not_enough",
                    severity: "high",
                    location: "tab_view"
                )
                return
            }
        }

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
                let usage = Usage(
                    query: (query.isEmpty ? 0 : 1),
                    agentUse: (query.isEmpty ? 1 : 0),
                    filesAttached: fileCount
                )
                await firestoreManager.incrementUsage(user: appUser, usage: usage)

                if byok {
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
                    await firestoreManager.incrementCredits(user: appUser, by: total)
                    modelInput.append([
                        "role": "usage",
                        "content": [
                            [
                                "type": "text",
                                "text": """
                                Total Usage: \(total) Credits
                                1 \(query.isEmpty ? "Agent Use" : "Query"): \(costPerQuery) Credit\(costPerQuery > 1 ? "s" : "")
                                \(fileCount) Attached Files: \(costFile) Credit\(costFile > 1 ? "s" : "")
                                \(modelAgentCount) Agent\(modelAgentCount > 1 ? "s" : "") Enabled: \(costAgent) Credit\(costAgent > 1 ? "s" : "")
                                """,
                            ]
                        ],
                    ])
                }

                AnalyticsManager.shared.customEventCost(
                    type: (query.isEmpty ? "Agent Use" : "Query"),
                    value: costPerQuery
                )
                AnalyticsManager.shared.customEventCost(type: "Attached Files", value: costFile)
                AnalyticsManager.shared.customEventCost(
                    type: "Agents Enabled",
                    value: costAgent
                )
            } else {
                AnalyticsManager.shared.customError(
                    type: "cost_not_calculated",
                    severity: "high",
                    location: "tab_view"
                )
            }

            modelContextSubmitted.append(contentsOf: modelContext)
            modelContext.removeAll()
            modelContextZoomed.removeAll()

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
                        if isTabClosed() {
                            isThinking = false
                            logger.info("Exiting text_delta for \(tabId) as it was closed")
                            AnalyticsManager.shared.customEventTab(action: "query_stop_on_close")
                            return
                        }

                        guard let delta = json["delta"] as? [String: Any] else { continue }
                        guard let delta_type = delta["type"] as? String else { continue }

                        switch delta_type {
                        case "text_delta":
                            guard let text = delta["text"] as? String else { continue }
                            isThinking = false
                            finalResponse += String(text)
                            await MainActor.run {
                                modelOutput = finalResponse + " " + shimmerPlaceholder()
                                if hereContext {
                                    TypingManager.shared.typeText(text)
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
                            if hereContext {
                                TypingManager.shared.endTypeText()
                            }
                        }

                    case "message_delta":
                        if isTabClosed() {
                            isThinking = false
                            logger.info("Exiting message_delta for \(tabId) as it was closed")
                            AnalyticsManager.shared.customEventTab(action: "query_stop_on_close")
                            return
                        }

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
                            AnalyticsManager.shared.customEventTool(name: finalToolUseName)

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
        return query
        // var finalQuery = ""
        // finalQuery = query.replacingOccurrences(of: "@this", with: "this")
        // return finalQuery
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
                - You are an AI tool with a special ability: you can understand what is happening on the screen and take action directly in the applications. 
                - Output response in Markdown.
                """,
            ],
            [
                "type": "text",
                "text":
                    """
                ## Special Keywords & Behaviors  
                - **@this** → 
                  - Use the provided image in context to answer the query.  

                - **@file** → 
                  - Use the provided file in context to answer the query.  

                - **@selected** → 
                  - Use the selected text in context to answer the query.  
                  
                - **@here** → 
                  - Output ONLY the text that goes into the file with ```text code formatting.  
                  - No extra output or commentary. Just OUTPUT text that replaces @selected text.
                  - Do not output @here word.
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
                - Do **NOT** describe tools unless explicitly asked.  
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
                """,
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

    private func copyToClipboard(string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    func isTabClosed() -> Bool {
        !allTabs.contains(where: { $0.id == tabId })
    }
}
