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
    @StateObject private var monitor = ScreenshotMonitor()

    let logger = Logger(subsystem: "com.thisisnsh.mac.AIThing", category: "TabView")

    @Binding var isFocused: Bool
    var tabId: UUID
    var tabHistory: History?
    @Binding var allTabs: [TabItem]
    @Binding var allClientTools: [String: [[String: Any]]]
    @Binding var managedModels: [ModelInfo]

    @Binding var showSettings: Bool
    @Binding var showHistory: Bool

    @State private var placeholder: String = ""
    @State private var animatePlaceholder: Bool = false

    let onClick: (_ tabId: UUID) -> Void
    let onSetting: () -> Void
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
    @State private var selectedText: String = ""

    @State private var textSize: CGFloat = 18
    @State private var showTools: Bool = false

    @State private var selectedFileUrls: [URL] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 32).overlay(alignment: .bottom) {
                if isFocused, showDragIcon {
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
            .shadow(radius: 4)
            .animation(.easeInOut(duration: 0.25), value: isFocused)
            .onAppear {
                if let tabHistory {
                    modelInput = tabHistory.history
                    modelOutput = assistantMessages(from: tabHistory.history)
                    if !modelOutput.isEmpty {
                        showResponseArea = true
                    }
                    tabTitle = tabHistory.title
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    placeholder =
                        showSettings
                        ? "Settings"
                        : showHistory
                            ? "History"
                            : tabHistory?.history.isEmpty ?? true
                                ? "Ask anything on this AI Thing..." : "Continue conversation..."
                    animatePlaceholder = true
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
            .onReceive(monitor.$latestScreenshot) { ss in
                if let ss = ss, isFocused {
                    Task {
                        let results = await DragFileManager.processPaths([ss.url])
                        for r in results {
                            modelContext.append(r)
                            modelContextZoomed.append(false)
                        }
                        AnalyticsManager.shared.customEvent(
                            type: .action,
                            primary: "file_upload"
                        )
                    }
                }
            }
            .onChange(of: isFocused) { newValue in
                showTools = false
            }
            .onChange(of: showSettings) { _ in
                placeholder =
                    showSettings
                    ? "Settings"
                    : showHistory
                        ? "History"
                        : tabHistory?.history.isEmpty ?? true
                            ? "Ask anything on this AI Thing..." : "Continue conversation..."
                animatePlaceholder = true

            }
            .onChange(of: showHistory) { _ in
                placeholder =
                    showSettings
                    ? "Settings"
                    : showHistory
                        ? "History"
                        : tabHistory?.history.isEmpty ?? true
                            ? "Ask anything on this AI Thing..." : "Continue conversation..."
                animatePlaceholder = true
            }
            .padding(.bottom, 8)

            if isFocused, showTools {
                ToolsView(setPanelPassthrough: setPanelPassthrough)
                    .background(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white, lineWidth: 1.5)
                    }
                    .cornerRadius(24)
                    .shadow(radius: 4)
                    .frame(minWidth: 640, maxWidth: 640, minHeight: 200, maxHeight: 200)
                    .environmentObject(mcp)
                    .onHover { inside in
                        updatePassthrough(inside: inside)
                    }
                    .transition(.identity)
                    .animation(nil, value: isFocused)
                    .padding(.bottom, 8)
            }

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
        .onHover { inside in
            showDragIcon = inside
        }
    }

    private func inputView() -> some View {
        HStack(spacing: 8) {
            LogoShape()
                .fill(isFocused && !showSettings && !showHistory ? .white : .white.opacity(0.5))
                .scaledToFit()
                .frame(width: isFocused ? 32 : 24)
                .padding(.leading, isFocused ? -8 : 0)

            if isFocused {
                ZStack(alignment: .leading) {

                    InputTextView(
                        text: $query,
                        seenCommands: $seenCommands,
                        size: $textSize,
                        isNotEditable: isViewBlinking || showSettings || showHistory,
                        onCommit: {
                            Task {
                                await handleQuery()
                            }
                        },
                        onCommandTyped: { _ in },
                        onCommandRemoved: { _ in },
                        onDebouncedTextChange: { _ in },
                        onSpillover: { count in
                            var newHeight: CGFloat = inputHeight

                            if count >= 2 && count <= 8 {
                                newHeight = inputHeight + CGFloat(count - 1) * inputHeight / 2
                            } else if count > 8 {
                                newHeight = inputHeight + 8 * inputHeight / 2
                            } else {
                                newHeight = inputHeight
                            }

                            inputHeight = newHeight
                        }
                    )
                    .onChange(of: query) { newValue in
                        if query.count > 400 {
                            textSize = 14
                        } else if query.count > 200 {
                            textSize = 16
                        } else {
                            textSize = 18
                        }
                    }
                    .opacity(showSettings || showHistory ? 0 : 1)
                    .frame(width: 482)

                    if query.isEmpty {
                        Text(placeholder)
                            .foregroundColor(.white.opacity(0.6))
                            .font(.system(size: 18, weight: .medium))
                            .padding(.leading, 6)
                            .allowsHitTesting(false)
                            .mask(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: .white, location: 0),
                                        .init(color: .white, location: animatePlaceholder ? 1 : 0),
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .animation(.easeOut(duration: 0.3), value: animatePlaceholder)
                    }
                }

                Button(
                    action: {
                        openFilePanel { url in
                            Task {
                                let results = await DragFileManager.processPaths(url)
                                for r in results {
                                    modelContext.append(r)
                                    modelContextZoomed.append(false)
                                }
                                AnalyticsManager.shared.customEvent(
                                    type: .action,
                                    primary: "file_upload"
                                )
                            }
                        }
                    }
                ) {
                    Image(systemName: "arrowshape.up.circle.fill")
                        .resizable()
                        .scaledToFit()
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 18, height: 18)
                .opacity(isFocused && !showSettings && !showHistory ? 1 : 0)

                Button(
                    action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showTools.toggle()
                        }
                        AnalyticsManager.shared.customEvent(type: .action, primary: "tools")
                    }
                ) {
                    Image(systemName: "hammer.circle.fill")
                        .resizable()
                        .scaledToFit()
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 18, height: 18)
                .opacity(isFocused && !showSettings && !showHistory ? 1 : 0)

                Button(
                    action: {
                        onSetting()
                        AnalyticsManager.shared.customEvent(type: .action, primary: "settings")
                    }
                ) {
                    Image(systemName: "gearshape.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(
                            isFocused && !showSettings && !showHistory
                                ? .white
                                : .white.opacity(0.5)
                        )
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

                        ZStack(alignment: .topTrailing) {
                            MarkdownText(text: modelOutput)
                                .foregroundColor(.white)
                                .font(.system(size: 14))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                        }
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
            .frame(width: 640, height: getResponseHeight())
            .background(Color.black.opacity(0.3))
            .onPreferenceChange(ViewHeightKey.self) { height in
                let checkedHeight = min(max(responseHeightMin, height), responseHeightMax)

                if responseHeight < checkedHeight {
                    responseHeight = checkedHeight
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
                let val = modelContextZoomed[index]
                modelContextZoomed = [Bool](repeating: false, count: modelContextZoomed.count)
                modelContextZoomed[index] = val
            },
            onDelete: { index in
                modelContext.remove(at: index)
                modelContextZoomed.remove(at: index)
                AnalyticsManager.shared.customEvent(
                    type: .action,
                    primary: "file_remove"
                )
            },
            updatePassthrough: { inside in
                updatePassthrough(inside: inside)
            }
        )
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

    private func handleQuery() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        screenshotManager.cancelScreenshot()

        modelOutput = ""

        isThinking = true
        showResponseArea = true

        responseHeight = responseHeightMin
        AnalyticsManager.shared.customEvent(
            type: .tab,
            primary: "handle_query"
        )

        isViewBlinking = true
        await callModel(query: trimmed)
        isViewBlinking = false
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
            AnalyticsManager.shared.customEvent(
                type: .error,
                primary: "breakglass_enabled",
                secondary: .status_failure_low,
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
            AnalyticsManager.shared.customEvent(
                type: .error,
                primary: "version_expired",
                secondary: .status_failure_low,
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
                    AnalyticsManager.shared.customEvent(
                        type: .error,
                        primary: "credits_consumed",
                        secondary: .status_failure_high,
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
            AnalyticsManager.shared.customEvent(
                type: .error,
                primary: "profile_fetch",
                secondary: .status_failure_high,
            )
            return
        default:
            isThinking = false
            await animateOutput(content: loginPromptMessage)
            AnalyticsManager.shared.customEvent(
                type: .error,
                primary: "query_without_login",
                secondary: .status_failure_low,
            )
            return
        }

        // Check if tab is alive, else return without processing
        if isTabClosed() {
            isThinking = false
            logger.info("Exiting callModel for \(tabId) as it was closed")
            AnalyticsManager.shared.customEvent(type: .tab, primary: "query_stop_on_close")
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

        AnalyticsManager.shared.customEvent(
            type: .model,
            primary: model,
            secondary: byok ? .byok_model : .managed_model
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
            AnalyticsManager.shared.customEvent(
                type: .error,
                primary: "missing_api_key",
                secondary: byok ? .status_failure_low : .status_failure_high
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
        let total = costPerQuery + costAgent + costFile

        logger.debug("api key: \(apiKey)")
        logger.debug("model: \(model)")
        logger.debug("tokens: \(getOutputToken())")
        logger.debug("messages: \(String(describing: body["messages"]))")
        logger.debug("tools count: \((body["tools"] as? [[String: Any]])?.count ?? 0)")
        logger.debug(
            "cost query: \(costPerQuery) file: \(costFile) agent: \(costAgent) total: \(total)"
        )

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
                AnalyticsManager.shared.customEvent(
                    type: .error,
                    primary: "credits_not_enough",
                    secondary: .status_failure_high,
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
                AnalyticsManager.shared.customEvent(
                    type: .error,
                    primary: "response_invalid",
                    secondary: .status_failure_high,
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
                    AnalyticsManager.shared.customEvent(
                        type: .error,
                        primary: "response_rate_limit",
                        secondary: byok ? .status_failure_low : .status_failure_high
                    )
                } else {
                    await animateOutput(
                        content:
                            "Error \(httpResponse.statusCode)\n\(error)\n\nReport issue at help@aithing.dev"
                    )
                    AnalyticsManager.shared.customEvent(
                        type: .error,
                        primary: "response_failure",
                        secondary: .status_failure_high,
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
            } else {
                AnalyticsManager.shared.customEvent(
                    type: .error,
                    primary: "cost_not_calculated",
                    secondary: .status_failure_high,
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
                            AnalyticsManager.shared
                                .customEvent(type: .tab, primary: "query_stop_on_close")
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
                        if isTabClosed() {
                            isThinking = false
                            logger.info("Exiting message_delta for \(tabId) as it was closed")
                            AnalyticsManager.shared.customEvent(
                                type: .tab,
                                primary: "query_stop_on_close"
                            )
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

    private func isTabClosed() -> Bool {
        !allTabs.contains(where: { $0.id == tabId })
    }

    private func openFilePanel(completion: @escaping ([URL]) -> Void) {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)

            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false
            panel.canChooseFiles = true

            let response = panel.runModal()
            completion(response == .OK ? panel.urls : [])
        }
    }
}
