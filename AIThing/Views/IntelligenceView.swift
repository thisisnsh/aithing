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

struct SavedQuery: Identifiable, Decodable, Encodable {
    let id: String
    let title: String
    let instruction: String
}

struct IntelligenceView: View {
    @EnvironmentObject var mcpManager: MCPManager
    @EnvironmentObject var loginManager: LoginManager
    @EnvironmentObject var firestoreManager: FirestoreManager
    @EnvironmentObject var appContext: AppContext
    @StateObject var screenshotMonitor = ScreenshotMonitor()

    @ObservedObject var vm: NotchVM
    let tabId: String
    @Binding var currentTabId: String
    @Binding var allClientTools: [String: [[String: Any]]]
    @Binding var managedModels: [ModelInfo]
    @Binding var showMcpToolsButton: Bool

    let close: () -> Void
    let minimize: () -> Void
    let expand: () -> Void
    let isTabShowing: () -> Bool
    let setTabActive: (Bool) -> Void
    let updateHistoryList: () async -> Void
    let reconnectManagedAgents: () async -> Void
    let getHistory: (String) async -> History?
    let storeHistory: (String, String, [[String: Any]]) async -> Void
    let setUnseen: (String, Bool) async -> Void
    let setTitle: (String, String) async -> Void
    let startSelectionPoll: () -> Void
    let stopSelectionPoll: () -> Void

    let logger = Logger(subsystem: "com.thisisnsh.mac.AIThing", category: "IntelligenceView")
    let cornerRadius: CGFloat = 24

    @State private var tabTitle: String = ""
    @State private var inputHeight: CGFloat = 24
    private let baseHeight: CGFloat = 24
    @State private var textSize: CGFloat = 14
    @FocusState private var isFocused: Bool

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

    @State private var savedQueries = getSavedQueries()
    @State private var showSavedQueries: Bool = false

    @State private var isDropping: Bool = false
    @State private var showMcpTools: Bool = false
    @State private var hoverMcpTools: Bool = false
    @State private var selectionEnabled: Bool = false
    @State private var hoverSelectionEnabled: Bool = false

    @State private var appContextEnabled: Bool = false
    @State private var hoverAppContextEnabled: Bool = false
    @State private var selectedAppIcon: NSImage? = nil
    @State private var selectedAppName = ""
    @State private var selectedWindowName = ""

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

            ZStack(alignment: .bottom) {
                VStack {
                    TitleView()
                        .padding(8)

                    Divider()
                        .padding(.horizontal, -8)

                    if showMcpTools {
                        ToolsView(cornerRadius: cornerRadius - 4)
                            .environmentObject(mcpManager)
                    } else {
                        ZStack {
                            ResponseView()
                                .padding(.vertical, -8)
                                .padding(.bottom, -24)
                                .frame(
                                    maxWidth: .infinity,
                                    maxHeight: .infinity,
                                    alignment: .topLeading
                                )

                            if !isThinking, showSavedQueries {
                                SaveQueryView()
                                    .frame(
                                        maxWidth: .infinity,
                                        maxHeight: .infinity,
                                        alignment: .bottomLeading
                                    )
                                    .padding(.leading, -8)
                            }
                        }
                    }

                    Spacer()

                    if #available(macOS 26.0, *) {
                        InputView()
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius - 4))
                            .glassEffect(
                                .regular.interactive(),
                                in: RoundedRectangle(cornerRadius: cornerRadius - 4)
                            )
                    } else {
                        InputView()
                            .background(.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius - 4))
                    }

                }

                ContextView()
                    .clipShape(
                        VariableRoundedRectangle(
                            topLeft: 0,
                            topRight: 0,
                            bottomLeft: cornerRadius,
                            bottomRight: cornerRadius
                        )
                    )
            }
            .id(tabId)
            .padding(8)
            .onAppear {
                AnalyticsManager.shared.screenView(screenName: .IntelligenceView)
            }
            .task {
                history = await getHistory(tabId)
                if let history = history {
                    modelInput = history.history
                    tabTitle = history.title ?? "New Chat"
                } else {
                    tabTitle = "New Chat"

                    let greeting = await firestoreManager.getGreeting() ?? ""
                    if !greeting.isEmpty {
                        modelOutput = greeting
                    }
                }

                let notification = await firestoreManager.getNotification() ?? ""
                if !notification.isEmpty {
                    modelOutput = notification
                }

                await setUnseen(tabId, false)

                if modelInput.isEmpty {
                    showSavedQueries = true
                }
            }
            .onChange(of: currentTabId) { _ in
                Task {
                    if currentTabId == tabId {
                        await setUnseen(tabId, false)
                    }
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
                                AnalyticsManager.shared
                                    .customEvent(
                                        view: .IntelligenceView,
                                        primary: .file,
                                        secondary: "screenshot",
                                        sev: .info
                                    )
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
                            modelContext.insert(r, at: 0)
                            AnalyticsManager.shared
                                .customEvent(
                                    view: .IntelligenceView,
                                    primary: .file,
                                    secondary: "add",
                                    sev: .info
                                )
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
                .onTapGesture {
                    selectionEnabled = false
                    close()
                }
                .onHover { hoverRed = $0 }

            Circle()
                .frame(width: 12, height: 12)
                .foregroundStyle(hoverYellow ? .yellow.opacity(0.5) : .yellow)
                .onTapGesture {
                    selectionEnabled = false
                    minimize()
                }
                .onHover { hoverYellow = $0 }

            TextField("Enter Title", text: $tabTitle)
                .focused($isFocused)
                .onSubmit {
                    isFocused = false
                    Task {
                        if !tabTitle.isEmpty, tabTitle.count < 64, tabTitle != "New Chat" {
                            await setTitle(tabId, tabTitle)
                        }
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.leading, 8)
                .textFieldStyle(.plain)

            Spacer()

            if let lastUpdated = history?.lastUpdated {
                Text(formatEpoch(lastUpdated) ?? "")
                    .foregroundColor(.secondary)
                    .font(.system(size: 10))
            }
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

    private func SaveQueryView() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(savedQueries.enumerated()), id: \.offset) { index, savedQuery in
                HoverableTabButton(
                    title: savedQuery.title,
                    isActive: true,
                    action: {
                        query = savedQuery.instruction
                    },
                    deleteAction: {
                        savedQueries.remove(at: index)
                        setSavedQueries(value: savedQueries)
                    },
                    image: "apple.intelligence",
                    isDeletable: true,
                    isExpanded: true,
                    fixedSize: true,
                    cornerRadius: 16
                )
                .padding(.bottom, 4)
            }
            if savedQueries.count < 7 {
                HoverableTabButton(
                    title: "Save Query",
                    isActive: false,
                    action: {
                        if !query.isEmpty {
                            savedQueries
                                .append(
                                    SavedQuery(
                                        id: UUID().uuidString,
                                        title: query.count > 32 ? "\(query.prefix(32))..." : query,
                                        instruction: query
                                    )
                                )
                            setSavedQueries(value: savedQueries)
                        }
                    },
                    deleteAction: {},
                    image: "apple.writing.tools",
                    isDeletable: false,
                    isExpanded: true,
                    fixedSize: true,
                    cornerRadius: 16
                )
            }
        }
    }

    private func InputView() -> some View {
        VStack(alignment: .leading, spacing: 0) {
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

                // MCP Tool Button
                if query.isEmpty {
                    Button(action: { showMcpTools.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "hammer.fill")
                                .resizable()
                                .frame(width: 12, height: 12)
                                .foregroundStyle(hoverMcpTools ? .white : .white.opacity(0.6))

                            Text("Tools")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(hoverMcpTools ? .white : .white.opacity(0.6))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { hoverMcpTools = $0 }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 4)
                }
            }
            .frame(height: inputHeight)
            .padding(.vertical, 8)
            .padding(.bottom, 40)
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

    private func ContextView() -> some View {
        VStack(alignment: .leading) {
            if hoverAppContextEnabled, appContextEnabled {
                let image = getAppContextBase64(
                    appName: selectedAppName,
                    windowName: selectedWindowName
                )
                if let image = image {
                    Image(nsImage: image.screenshot)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 128)
                        .cornerRadius(cornerRadius - 8)
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius - 8, style: .continuous)
                                .stroke(Color.white, lineWidth: 2)
                        }
                } else {
                    Color.clear
                        .onAppear {
                            appContext.refresh()
                            appContextEnabled = false
                            selectedAppIcon = nil
                            selectedAppName = ""
                            selectedWindowName = ""
                        }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom) {

                    // App Context Button
                    if appContextEnabled {
                        Button(action: {
                            appContextEnabled = false
                            selectedAppIcon = nil
                            selectedAppName = ""
                            selectedWindowName = ""
                        }) {
                            HStack {
                                if let icon = selectedAppIcon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 12, height: 12)
                                }

                                Text(
                                    "\(selectedAppName)\(selectedWindowName.count > 0 ? ": " : "")\(selectedWindowName)"
                                )
                                .lineLimit(1)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.black)
                                .frame(maxWidth: 164)
                            }
                            .padding(8)
                            .padding(.horizontal, 4)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hoverAppContextEnabled = $0 }
                    } else {
                        if !appContext.appName.isEmpty {
                            Button(action: {
                                selectedAppIcon = appContext.appIcon
                                selectedAppName = appContext.appName
                                selectedWindowName = appContext.windowName
                                appContextEnabled = true

                                // Check if screenshot can not be taken disable the button
                                if getAppContextBase64(
                                    appName: selectedAppName,
                                    windowName: selectedWindowName
                                ) == nil {
                                    appContext.refresh()
                                    appContextEnabled = false
                                    selectedAppIcon = nil
                                    selectedAppName = ""
                                    selectedWindowName = ""
                                }

                            }) {
                                HStack {
                                    if let icon = appContext.appIcon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 12, height: 12)
                                    }

                                    Text(
                                        "\(appContext.appName)\(appContext.windowName.count > 0 ? ": " : "")\(appContext.windowName)"
                                    )
                                    .lineLimit(1)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(
                                        hoverAppContextEnabled || appContextEnabled
                                            ? .black : .white
                                    )
                                    .frame(maxWidth: 164)
                                }
                                .padding(8)
                                .padding(.horizontal, 4)
                                .background(
                                    hoverAppContextEnabled || appContextEnabled
                                        ? .white : .white.opacity(0.1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .onHover {
                                hoverAppContextEnabled = $0
                                if !appContextEnabled {
                                    appContext.refresh()
                                    selectedAppIcon = nil
                                    selectedAppName = ""
                                    selectedWindowName = ""
                                }
                            }
                        }
                    }

                    // Text Selection Button
                    Button(action: {
                        // Accessibility trust (prompt once as needed)
                        if !AXIsProcessTrusted() {
                            let opts: NSDictionary = [
                                kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true
                            ]
                            _ = AXIsProcessTrustedWithOptions(opts)
                            return
                        } else {
                            selectionEnabled.toggle()
                        }

                        if selectionEnabled {
                            startSelectionPoll()
                        } else {
                            selectedText = ""
                            vm.selectedText = ""
                            stopSelectionPoll()
                            AnalyticsManager.shared
                                .customEvent(
                                    view: .IntelligenceView,
                                    primary: .selection,
                                    secondary: "remove",
                                    sev: .info
                                )
                        }

                        AnalyticsManager.shared
                            .customEvent(
                                view: .IntelligenceView,
                                primary: .selection,
                                secondary: "\(selectionEnabled)",
                                sev: .info
                            )
                    }) {
                        HStack {
                            Image(
                                systemName: selectionEnabled
                                    ? "text.redaction" : "text.alignleft"
                            )
                            .resizable()
                            .frame(width: 12, height: 12)
                            .foregroundStyle(
                                hoverSelectionEnabled || selectionEnabled ? .black : .white
                            )

                            Text("Text Selection")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(
                                    hoverSelectionEnabled || selectionEnabled ? .black : .white
                                )
                        }
                        .padding(8)
                        .padding(.horizontal, 4)
                        .background(
                            hoverSelectionEnabled || selectionEnabled ? .white : .white.opacity(0.1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { hoverSelectionEnabled = $0 }

                    if modelContext.count > 0, !isThinking {
                        ForEach(modelContext.indices.reversed(), id: \.self) { index in
                            let context = modelContext[index]
                            switch context {
                            case .image(let name, let image, _):
                                FilePill(
                                    index: index,
                                    name: name,
                                    image: image,
                                    systemName: "photo",
                                    big: modelContext.count == 1,
                                    onDelete: { index in
                                        modelContext.remove(at: index)
                                        AnalyticsManager.shared
                                            .customEvent(
                                                view: .IntelligenceView,
                                                primary: .file,
                                                secondary: "remove",
                                                sev: .info
                                            )
                                    },
                                    cornerRadius: cornerRadius
                                )

                            case .pdf(let name, _, let images, _):
                                FilePill(
                                    index: index,
                                    name: name,
                                    image: images[0],
                                    systemName: "text.page",
                                    big: false,
                                    onDelete: { index in
                                        modelContext.remove(at: index)
                                        AnalyticsManager.shared
                                            .customEvent(
                                                view: .IntelligenceView,
                                                primary: .file,
                                                secondary: "remove",
                                                sev: .info
                                            )
                                    },
                                    cornerRadius: cornerRadius
                                )

                            case .text(let name, _, let image):
                                FilePill(
                                    index: index,
                                    name: name,
                                    image: image,
                                    systemName: "text.alignleft",
                                    big: false,
                                    onDelete: { index in
                                        modelContext.remove(at: index)
                                        AnalyticsManager.shared
                                            .customEvent(
                                                view: .IntelligenceView,
                                                primary: .file,
                                                secondary: "remove",
                                                sev: .info
                                            )
                                    },
                                    cornerRadius: cornerRadius
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(.horizontal, -8)
        }
        .padding(8)
    }
}

extension IntelligenceView {
    private func handleQuery() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var appContextBase64: AppContextModel? = nil
        if appContextEnabled {
            if let ss = getAppContextBase64(
                appName: selectedAppName,
                windowName: selectedWindowName
            ) {
                appContextBase64 = ss
            } else {
                appContext.refresh()
                appContextEnabled = false
                selectedAppIcon = nil
                selectedAppName = ""
                selectedWindowName = ""
                return
            }
        }

        displayQuery = trimmed
        modelOutput = ""
        isThinking = true
        toolCall = ""
        query = ""
        inputHeight = baseHeight
        showSavedQueries = false

        AnalyticsManager.shared.customEvent(
            view: .IntelligenceView,
            primary: .query,
            secondary: "start",
            sev: .info
        )

        setTabActive(true)

        let result = await callModel(
            tabId: tabId,
            query: trimmed,
            getAppContextBase64: { return appContextBase64 },
            getSelectedText: { return selectedText },
            setSelectedText: { selectedText = $0 },
            getSelectionEnabled: { return selectionEnabled },
            setSelectionEnabled: { selectionEnabled = $0 },
            getTabTitle: { return tabTitle },
            setTabTitle: { tabTitle = $0 },
            setDisplayQuery: { displayQuery = $0 },
            setToolCall: { toolCall = $0 },
            getHistory: { return await self.getHistory($0) },
            storeHistory: { await storeHistory($0, $1, $2) },
            setHistory: { history = $0 },
            setIsThinking: { isThinking = $0 },
            getModelInput: { return modelInput },
            appendModelInput: { modelInput.append($0) },
            getModelOutput: { return modelOutput },
            setModelOutput: { modelOutput = $0 },
            animateOutput: { await self.animateOutput(content: $0, notification: $1) },
            getAllClientTools: { return allClientTools },
            reconnectManagedAgents: { await self.reconnectManagedAgents() },
            getModelContext: { return modelContext },
            clearModelContext: { modelContext.removeAll() },
            getManagedModels: { return managedModels },
            firestoreManager: firestoreManager,
            loginManager: loginManager,
            mcpManager: mcpManager
        )

        setTabActive(false)
        if !isTabShowing() {
            await setUnseen(tabId, true)
        } else {
            await setUnseen(tabId, false)
        }

        AnalyticsManager.shared.customEvent(
            view: .IntelligenceView,
            primary: .query,
            secondary: "end",
            sev: .info
        )

        vm.selectedText = ""
        selectedText = ""
        selectionEnabled = false

        isThinking = false
        history = await getHistory(tabId)
        if result {
            modelOutput = ""
        }
        displayQuery = ""
        toolCall = ""

        await updateHistoryList()
    }

    private func getAppContextBase64(appName: String, windowName: String?) -> AppContextModel? {
        if !appContextEnabled || appName.isEmpty {
            print("nishant3")
            return nil
        }

        if let image = captureWindow(
            appName: appName,
            windowTitle: windowName
        ) {
            let thumb = image.resized(maxDimension: 1024)
            guard let data = thumb.jpegData() else {
                print("nishant1")
                return nil
            }
            return AppContextModel(
                appName: selectedAppName,
                windowName: selectedWindowName,
                screenshot: thumb,
                base64: data.base64EncodedString()
            )
        }

        print("nishant2")
        return nil
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

    private func shimmerPlaceholder() -> String {
        return "▌"  // or use "…" or a flashing cursor symbol
    }

    private func formatEpoch(_ epochS: String, format: String = "MMMM, dd yyyy HH:mm") -> String? {
        if let epoch = Double(epochS) {
            let date = Date(timeIntervalSince1970: epoch)
            let formatter = DateFormatter()
            formatter.dateFormat = format
            return formatter.string(from: date)
        } else {
            return nil
        }
    }
}
