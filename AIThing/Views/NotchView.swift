//
//  NotchView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 10/31/25.
//

import SwiftUI
import os

struct Tab: Equatable {
    let id: String
    let intelligenceView: IntelligenceView
    var active: Bool = true
    var lastUpdated: Date = Date()

    static func == (lhs: Tab, rhs: Tab) -> Bool {
        lhs.id == rhs.id
    }
}

struct NotchView: View {
    @StateObject private var mcpManager = MCPManager()
    @StateObject private var loginManager = LoginManager()
    @StateObject private var firestoreManager = FirestoreManager()
    @StateObject private var automationManager = AutomationManager(onExecute: { _ in })

    let logger = Logger(subsystem: "com.thisisnsh.mac.AIThing", category: "NotchView")
    let historyStore = HistoryStore()

    @ObservedObject var vm: NotchVM
    let updateWindowSize: (WindowSize) -> (CGFloat, CGFloat)
    let modifyWindowBaseSize: (CGSize, WindowSize) -> (CGFloat, CGFloat)
    let modifyWindowOriginalSize: () -> Void
    let modifyWindowTopOffset: (CGFloat, WindowSize) -> Void
    let gainFocus: () -> Void
    let isTouchingRightEdge: () -> Bool
    let windowMoveable: (Bool) -> Void

    let cornerRadiusLeft: CGFloat = 38
    let shadowBuffer: CGFloat = 32

    @State private var width: CGFloat = 0
    @State private var height: CGFloat = 0
    @State private var windowSize = WindowSize.notchIsCollapsed
    @State private var lastExpandedWindowSize = WindowSize.sidebarIsExpanded
    @State private var hoverTask: Task<Void, Never>?
    @State private var circularNotch = false

    @State private var managedModels: [ModelInfo] = []
    @State private var agents: [AgentEntry] = []
    @State private var allClientTools: [String: [[String: Any]]] = [:]
    @State private var showMcpToolsButton = false

    @State private var tabId: String = ""
    @State private var tabs: [String: Tab] = [:]
    @State private var histories: [History] = []

    @State private var showDragIcon = false
    @State private var showSettings = false
    @State private var showToast = false
    @State private var toastText = ""
    @State private var toastColor: Color = .yellow
    @State private var hoverSidebar = false
    @State private var expandSidebar = false
    @State private var previousExpandSidebar = false

    private var showChatWindow: Bool {
        windowSize.rawValue >= WindowSize.chatIsShown.rawValue
    }
    private var expandNotch: Bool {
        windowSize.rawValue >= WindowSize.sidebarIsCollapsed.rawValue
    }

    // Resize
    @State private var showResizeX = false
    @State private var showResizeY = false
    @State private var smoothedY: CGFloat = 0
    @State private var smoothedX: CGFloat = 0
    @State private var smoothedDragY: CGFloat = 0
    @State private var lastAppliedY: CGFloat = 0
    @State private var lastAppliedX: CGFloat = 0
    @State private var lastAppliedDragY: CGFloat = 0
    private let alpha: CGFloat = 0.25
    private let pixelStep: CGFloat = 1.0
    @State private var resizeHoverTask: Task<Void, Never>?

    // Managed Agents
    // StateObjects not persisted after application quit
    // This is due to the nature of these servers that require token refresh
    // Best way is to disable then and enable to fetch new token
    @StateObject private var googleOAuthManager = GoogleOAuthManager()
    @StateObject private var githubOAuthManager = GithubOAuthManager()
    @StateObject private var mcpOAuthManagers = McpOAuthManagers()

    var body: some View {
        ZStack {
            NotchShapeExt()

            HStack(spacing: 0) {
                if showChatWindow {
                    ResizeViewX()
                }

                VStack(spacing: 0) {
                    if showChatWindow {
                        if showSettings {
                            SettingsView(
                                isPresented: $showSettings,
                                managedModels: $managedModels,
                                close: {
                                    showSettings = false
                                    close()
                                },
                                minimize: {
                                    showSettings = false
                                    minimize()
                                },
                                expand: { maximize() },

                            )
                            .environmentObject(loginManager)
                            .environmentObject(firestoreManager)
                            .environmentObject(googleOAuthManager)
                            .environmentObject(githubOAuthManager)
                            .environmentObject(mcpOAuthManagers)
                            .environmentObject(automationManager)
                        } else {
                            if !tabId.isEmpty {
                                getIntelligenceView(tabId: tabId)
                                    .environmentObject(mcpManager)
                                    .environmentObject(loginManager)
                                    .environmentObject(firestoreManager)
                                    .id(tabId)
                            }
                        }
                    }

                    if showChatWindow {
                        ResizeViewY()
                    }
                }

                VStack(alignment: expandSidebar ? .leading : .center, spacing: 0) {
                    HStack {
                        if !expandNotch || expandSidebar {
                            LogoShape()
                                .fill(.white)
                                .scaledToFit()
                                .frame(height: 32)
                        }

                        if expandNotch, expandSidebar {
                            Spacer()

                            Image(systemName: "rectangle.grid.3x1.fill")
                                .resizable()
                                .frame(width: 14, height: 14)
                                .padding(8)
                                .background(hoverSidebar ? Color.white.opacity(0.1) : .clear)
                                .cornerRadius(8)
                                .onHover { hoverSidebar = $0 }
                                .onTapGesture { sidebarToggle() }
                                .rotationEffect(Angle(degrees: 270))
                        }
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, expandNotch && expandSidebar ? 16 : 0)

                    if expandNotch {
                        Divider().opacity(0)

                        HoverableTabButton(
                            title: "New Chat",
                            isActive: false,
                            action: {
                                open()
                                showSettings = false
                                tabId = UUID().uuidString
                                createIntelligenceView(tabId: tabId)
                            },
                            deleteAction: {},
                            image: "plus.circle.fill",
                            isDeletable: false,
                            isExpanded: expandSidebar
                        )
                        .padding(.top, expandSidebar ? 8 : 0)

                        HoverableTabButton(
                            title: "Settings",
                            isActive: false,
                            action: {
                                open()
                                if tabId.isEmpty {
                                    tabId = UUID().uuidString
                                    createIntelligenceView(tabId: tabId)
                                }
                                showSettings.toggle()
                            },
                            deleteAction: {},
                            image: "gearshape.fill",
                            isDeletable: false,
                            isExpanded: expandSidebar
                        )

                        if !expandSidebar {
                            HoverableTabButton(
                                title: "Expand Sidebar",
                                isActive: false,
                                action: {
                                    sidebarToggle()
                                },
                                deleteAction: {},
                                image: "rectangle.grid.1x2.fill",
                                isDeletable: false,
                                isExpanded: expandSidebar,
                                rotateImage: Angle(degrees: 270)
                            )
                        }

                        if expandSidebar {
                            if histories.count > 0 {
                                Divider().opacity(0).padding(.vertical, 8)
                            }

                            Sidebar()
                        }
                    }

                    Spacer()
                }
                .frame(width: expandNotch ? (expandSidebar ? 200 : 60) : 60)
            }
            .padding(.vertical, 24)

            if showToast, showChatWindow {
                Toast()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            self.showToast = false
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(32)
            }

            if showDragIcon {
                Image(systemName: "square.grid.3x2.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12)
                    .shadow(radius: 4)
                    .onHover { hover in
                        windowMoveable(hover)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.horizontal, 24)
            }

        }
        .padding(.leading, shadowBuffer)
        .frame(width: width, height: height)
        .onAppear {
            AnalyticsManager.shared.screenView(screenName: .NotchView)
            close()

            automationManager.onExecute = { (automation: Automation) async in
                logger.debug("Called automation: \(automation.id)")
                var modelInput: [[String: Any]] = []
                var modelOutput: String = ""
                let tabId = UUID().uuidString
                var title = ""
                var history: [[String: Any]] = []

                let _ = await callModel(
                    tabId: tabId,
                    query: automation.instructions,
                    getSelectedText: { return "" },
                    setSelectedText: { _ in },
                    getSelectionEnabled: { return false },
                    setSelectionEnabled: { _ in },
                    getTabTitle: { return title },
                    setTabTitle: { title = $0 },
                    setDisplayQuery: { _ in },
                    setToolCall: { _ in },
                    getHistory: { await self.getHistory(tabId: $0) },
                    storeHistory: {
                        title = $1
                        history = $2
                    },
                    setHistory: { _ in },
                    setIsThinking: { _ in },
                    getModelInput: { return modelInput },
                    appendModelInput: { modelInput.append($0) },
                    getModelOutput: { return modelOutput },
                    setModelOutput: { modelOutput = $0 },
                    animateOutput: { (_, _) async in },
                    getAllClientTools: { return allClientTools },
                    reconnectManagedAgents: { await self.reconnectManagedAgents() },
                    getModelContext: { return [] },
                    clearModelContext: {},
                    getManagedModels: { return managedModels },
                    firestoreManager: firestoreManager,
                    loginManager: loginManager,
                    mcpManager: mcpManager
                )

                if !history.isEmpty {
                    await self.storeHistory(tabId: tabId, tabTitle: title, history: history)
                }

                await updateHistoryList()
            }
        }
        .onChange(of: showSettings) { newValue in
            Task {
                managedModels = await firestoreManager.getModelInfos()
                await loadAllClientTools()
                await reconnectManagedAgents()
                showMcpToolsButton = await mcpManager.getAllTools().count > 0
            }
        }
        .onChange(of: vm.refresh) { _ in
            (width, height) = updateWindowSize(lastExpandedWindowSize)
        }
        .onChange(of: vm.toggle) { _ in
            if windowSize == WindowSize.notchIsCollapsed {
                open()
            } else {
                minimize()
            }
        }
        .onChange(of: vm.move) { _ in
            circularNotch = !isTouchingRightEdge()
        }
        .onReceive(
            Timer.publish(every: 60, on: .main, in: .common).autoconnect()
        ) { _ in
            removeTabs()
        }
        .task {
            switch loginManager.authState {
            case .signedIn(let user):
                AnalyticsManager.shared.setUserId(user.uid)
            default:
                AnalyticsManager.shared.setUserId(nil)
            }

            histories = await historyStore.getAll(limit: 100)

            managedModels = await firestoreManager.getModelInfos()
            await loadAllClientTools()
            await reconnectManagedAgents()
            showMcpToolsButton = await mcpManager.getAllTools().count > 0
        }
        .onHover { hovering in
            hoverTask?.cancel()  // cancel any pending hover change
            hoverTask = Task { @MainActor in
                // delay a bit before applying the hover state
                try? await Task.sleep(nanoseconds: 150_000_000)  // 150ms
                guard !Task.isCancelled else { return }

                showDragIcon = hovering

                if windowSize != WindowSize.chatIsShown {
                    if hovering {
                        if windowSize == WindowSize.notchIsCollapsed {
                            open()
                        }
                    } else {
                        if windowSize == WindowSize.sidebarIsExpanded
                            || windowSize == WindowSize.sidebarIsCollapsed
                        {
                            close()
                        }
                    }
                }
            }
        }
    }

    private func NotchShapeExt() -> some View {
        Group {
            if #available(macOS 26.0, *) {
                NotchShape(
                    width: width,
                    height: height,
                    cornerRadiusLeft: showChatWindow ? cornerRadiusLeft : 16,
                    cornerRadiusRight: 16,
                    circularNotch: circularNotch
                )
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(showChatWindow ? 0.3 : 1.0),
                            Color.black.opacity(1.0),
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(
                        NotchShape(
                            width: width,
                            height: height,
                            cornerRadiusLeft: showChatWindow ? cornerRadiusLeft : 16,
                            cornerRadiusRight: 16,
                            circularNotch: circularNotch
                        )
                    )
                )
                .glassEffect(
                    .regular.tint(.black),
                    in: NotchShape(
                        width: width,
                        height: height,
                        cornerRadiusLeft: showChatWindow ? cornerRadiusLeft : 16,
                        cornerRadiusRight: 16,
                        circularNotch: circularNotch
                    )
                )
            } else {
                NotchShape(
                    width: width,
                    height: height,
                    cornerRadiusLeft: showChatWindow ? cornerRadiusLeft : 16,
                    cornerRadiusRight: 16,
                    circularNotch: circularNotch
                )
                .fill(.ultraThickMaterial)
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(showChatWindow ? 0.3 : 1.0),
                            Color.black.opacity(1.0),
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .blendMode(.overlay)
                    .clipShape(
                        NotchShape(
                            width: width,
                            height: height,
                            cornerRadiusLeft: showChatWindow ? cornerRadiusLeft : 16,
                            cornerRadiusRight: 16,
                            circularNotch: circularNotch
                        )
                    )
                )
            }
        }
    }

    private func Sidebar() -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(histories.enumerated()), id: \.offset) { (i, h) in
                    HoverableTabButton(
                        title: expandSidebar
                            ? (h.title ?? createTitle(for: h.history, fallback: "Session #\(i + 1)"))
                            : "ABC",
                        isActive: (tabId == h.id),
                        action: {
                            open()
                            showSettings = false
                            tabId = h.id
                            createIntelligenceView(tabId: tabId)
                            removeTabs()
                        },
                        deleteAction: {
                            Task {
                                let isActive = tabId == h.id
                                await historyStore.delete(id: h.id)
                                setTabActive(tabId: h.id, active: false)
                                histories = await historyStore.getAll(limit: 100)
                                if isActive {
                                    if let history = histories.first {
                                        tabId = history.id
                                        createIntelligenceView(tabId: tabId)
                                    } else {
                                        tabId = UUID().uuidString
                                        createIntelligenceView(tabId: tabId)
                                    }
                                }
                            }
                        }
                    )
                }

                if histories.isEmpty {
                    Text("No chats")
                        .foregroundColor(.secondary)
                        .font(.system(size: 10))
                        .padding(20)
                }

                Color.clear.frame(height: 16)
            }
        }
        .frame(width: expandSidebar ? 200 : 60)
    }

    private func ResizeViewX() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.clear)
                .frame(width: 8)
                .onHover { inside in
                    if windowSize == WindowSize.chatIsExpanded { return }

                    resizeHoverTask?.cancel()
                    resizeHoverTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        guard !Task.isCancelled else { return }
                        if inside {
                            showResizeX = inside
                        } else {
                            DispatchQueue.main.asyncAfter(
                                deadline: .now() + 3,
                                execute: {
                                    showResizeX = inside
                                }
                            )
                        }

                        if inside {
                            NSCursor.resizeLeftRight.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
                }

            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.3))
                .padding(.horizontal, 2)
                .frame(width: 8, height: 64)
                .opacity(showResizeX ? 1 : 0)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            NSCursor.resizeLeftRight.set()
                            let rawX = value.translation.width * -1
                            smoothedX += (rawX - smoothedX) * alpha
                            let roundedX = (smoothedX / pixelStep).rounded() * pixelStep
                            if roundedX != lastAppliedX {
                                lastAppliedX = roundedX
                                let size = CGSize(width: roundedX, height: 0)
                                (width, height) = modifyWindowBaseSize(size, lastExpandedWindowSize)
                                AnalyticsManager.shared
                                    .customEvent(
                                        view: .NotchView,
                                        primary: .dragLeft,
                                        secondary: "\(roundedX)",
                                        sev: .info
                                    )
                            }

                        }
                        .onEnded { _ in
                            smoothedX = 0
                            lastAppliedX = 0
                            modifyWindowOriginalSize()
                            NSCursor.arrow.set()
                        }
                )
        }
        .padding(.vertical, 32)
    }

    private func ResizeViewY() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.clear)
                .frame(height: 8)
                .onHover { inside in
                    if windowSize == WindowSize.chatIsExpanded { return }

                    resizeHoverTask?.cancel()
                    resizeHoverTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        guard !Task.isCancelled else { return }
                        if inside {
                            showResizeY = inside
                        } else {
                            DispatchQueue.main.asyncAfter(
                                deadline: .now() + 3,
                                execute: {
                                    showResizeY = inside
                                }
                            )
                        }

                        if inside {
                            NSCursor.resizeUpDown.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
                }

            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.3))
                .padding(.vertical, 2)
                .frame(width: 64, height: 8)
                .opacity(showResizeY ? 1 : 0)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            NSCursor.resizeUpDown.set()
                            let rawY = value.translation.height
                            smoothedY += (rawY - smoothedY) * alpha
                            let roundedY = (smoothedY / pixelStep).rounded() * pixelStep
                            if roundedY != lastAppliedY {
                                lastAppliedY = roundedY
                                let size = CGSize(width: 0, height: roundedY)
                                (width, height) = modifyWindowBaseSize(size, lastExpandedWindowSize)
                                AnalyticsManager.shared
                                    .customEvent(
                                        view: .NotchView,
                                        primary: .dragDown,
                                        secondary: "\(roundedY)",
                                        sev: .info
                                    )
                            }
                        }
                        .onEnded { _ in
                            smoothedY = 0
                            lastAppliedY = 0
                            modifyWindowOriginalSize()
                            NSCursor.arrow.set()
                        }
                )

        }
        .padding(.horizontal, 32)
        .padding(.bottom, -8)
    }

    private func Toast() -> some View {
        Group {
            if #available(macOS 26.0, *) {
                Text(toastText)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 32))
                    .overlay {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(toastColor.opacity(0.5), lineWidth: 1)
                    }
            } else {
                Text(toastText)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .overlay {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(toastColor.opacity(0.5), lineWidth: 1)
                    }
            }
        }
    }
}

// MARK: Tab Stuff
extension NotchView {
    private func createIntelligenceView(tabId: String) {
        printTabs()
        tabs[tabId] = Tab(
            id: tabId,
            intelligenceView: IntelligenceView(
                vm: vm,
                tabId: tabId,
                allClientTools: $allClientTools,
                managedModels: $managedModels,
                showMcpToolsButton: $showMcpToolsButton,
                close: { close() },
                minimize: { minimize() },
                expand: { maximize() },
                isTabShowing: { isTabShowing(tabId: tabId) },
                setTabActive: { setTabActive(tabId: tabId, active: $0) },
                updateHistoryList: { await updateHistoryList() },
                reconnectManagedAgents: reconnectManagedAgents,
                getHistory: { return await getHistory(tabId: $0) },
                storeHistory: { await storeHistory(tabId: $0, tabTitle: $1, history: $2) }
            ),
            active: false
        )
        removeTabs()
        printTabs()
        AnalyticsManager.shared.customEvent(
            view: .NotchView,
            primary: .createTab,
            secondary: "",
            sev: .info
        )
    }

    private func printTabs() {}

    private func getIntelligenceView(tabId: String) -> some View {
        Group {
            if tabs.keys.contains(tabId) {
                tabs[tabId]?.intelligenceView
            } else {
                Text("Open a tab")
            }
        }
    }

    private func isTabShowing(tabId: String) -> Bool {
        printTabs()
        return tabId == self.tabId
    }

    private func setTabActive(tabId: String, active: Bool) {
        guard var tab = tabs[tabId] else { return }

        tab.active = active
        tab.lastUpdated = Date()
        tabs[tabId] = tab

        printTabs()
        AnalyticsManager.shared.customEvent(
            view: .NotchView,
            primary: .activateTab,
            secondary: "\(active)",
            sev: .info
        )
    }

    // Remove tabs that are inactive for longer than 10 minutes
    private func removeTabs() {
        printTabs()
        let minutes: Double = 10
        let cutoff = Date().addingTimeInterval(-(minutes * 60))
        let countStart = tabs.count
        tabs = tabs.filter { _, tab in
            tab.active || tab.lastUpdated >= cutoff || tab.id == self.tabId
        }
        let countEnd = tabs.count
        printTabs()
        AnalyticsManager.shared
            .customEvent(
                view: .NotchView,
                primary: .removeTabs,
                secondary: "\(countStart - countEnd)",
                sev: .info
            )
    }
}

// MARK: AI Stuff
extension NotchView {
    private func loadAllClientTools() async {
        let newAgents = getAgentEntries()
        var allMatch = true

        if agents.count == newAgents.count {
            for (i, agent) in newAgents.enumerated() {
                let existing = agents[i]
                if existing.id != agent.id || existing.isEnabled != agent.isEnabled {
                    allMatch = false
                    break
                }
            }
        } else {
            allMatch = false
        }

        if allMatch {
            return
        }

        agents = newAgents
        toastText = "Waking up Agents..."
        showToast = true

        var failure = ""

        let disconnectRc = await mcpManager.disconnect()
        if !disconnectRc.isEmpty {
            toastColor = .red
            toastText = "Failed to wake up agents: \(disconnectRc)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showToast = false
                toastColor = .white
            }
            return
        }

        allClientTools.removeAll()
        mcpOAuthManagers.selfManagers.removeAll()

        for agent in agents {
            if !agent.isEnabled {
                continue
            }

            let name: String
            let primary: String
            var connectRc: String = ""
            var oauth: Bool = false

            switch agent.entry {
            case .url(let n, let url):
                name = n
                primary = url

                // URL is oauth ready if it has well known URLs
                oauth = await McpOAuthManager.hasWellKnownUrls(url: url)

                // Skip connecting to oauth servers now, they will be connected during query
                if oauth {
                    mcpOAuthManagers.selfManagers[name] = McpOAuthManager(
                        server: McpServer(
                            id: name,
                            image: nil,
                            name: name,
                            url: url,
                            version: nil,
                            enabled: true
                        )
                    )
                    mcpOAuthManagers.selfManagers[name]?.enabled = true
                } else {
                    connectRc = await mcpManager.connect(clientName: name, url: url, authToken: nil)
                }

            case .urlWithToken(let n, let url, let token):
                name = n
                primary = url

                connectRc = await mcpManager.connect(clientName: name, url: url, authToken: token)

            case .command(let n, let command, let arguments):
                name = n
                primary = command

                connectRc = await mcpManager.connect(
                    clientName: name,
                    command: command,
                    args: arguments
                )
            }

            AnalyticsManager.shared.customEvent(
                view: .NotchView,
                primary: .agentLoad,
                secondary: "\(name) \(primary)",
                sev: .info
            )

            logger.info("Agent Name: \(name)")
            logger.info("OAuth Ready: \(oauth)")

            if !oauth {
                if connectRc.isEmpty {
                    let tools = await mcpManager.getTools(clientName: name, filter: [])
                    allClientTools[name] = tools
                } else {
                    failure += "\n\n\(name): \(connectRc)"
                }
            }

        }

        if !failure.isEmpty {
            toastColor = .red
            toastText = "Failed to wake up agents\n" + failure
            AnalyticsManager.shared
                .customEvent(view: .NotchView, primary: .agentLoad, secondary: failure, sev: .error)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (failure.isEmpty ? 2 : 5)) {
            showToast = false
            toastColor = .white
        }
    }

    private func reconnectManagedAgents() async {
        var enabledClients: [String] = []

        if googleOAuthManager.enabled.count > 0 {
            let clientName = "managed_google_mcp"
            var accessToken: String?
            var refreshedAccessToken: String?

            if googleOAuthManager.user != nil {
                accessToken = googleOAuthManager.user?.accessToken.tokenString
                logger.debug("AccessToken \(String(describing: accessToken))")
            }

            if let user = await googleOAuthManager.generateToken(refresh: true) {
                refreshedAccessToken = user.accessToken.tokenString
                // If token has been refreshed OR client does not exist
                logger.debug("RefreshedAccessToken \(String(describing: refreshedAccessToken))")
                if accessToken != refreshedAccessToken
                    || !mcpManager.clientExists(clientName: clientName)
                {
                    _ = await mcpManager.reconnect(
                        clientName: clientName,
                        url: "https://google.mcp.aithing.dev/mcp",
                        authToken: refreshedAccessToken!
                    )
                }
            }

            let tools = await mcpManager.getTools(
                clientName: clientName,
                filter: googleOAuthManager.enabledCapabilities()
            )
            allClientTools[clientName] = tools
            logger.debug("Google Enabled Capabilities: \(tools)")
            enabledClients.append(clientName)
        } else {
            allClientTools.removeValue(forKey: "managed_google_mcp")
        }

        if githubOAuthManager.enabled.count > 0 {
            let clientName = "managed_github_mcp"
            var accessToken: String?
            var refreshedAccessToken: String?

            if githubOAuthManager.user != nil {
                accessToken = githubOAuthManager.user?.accessToken
                logger.debug("AccessToken \(String(describing: accessToken))")
            }

            if let user = await githubOAuthManager.generateToken(refresh: true) {
                refreshedAccessToken = user.accessToken
                // If token has been refreshed OR client does not exist
                logger.debug("RefreshedAccessToken \(String(describing: refreshedAccessToken))")
                if accessToken != refreshedAccessToken
                    || !mcpManager.clientExists(clientName: clientName)
                {
                    _ = await mcpManager.reconnect(
                        clientName: clientName,
                        url: "https://api.githubcopilot.com/mcp",
                        authToken: refreshedAccessToken!
                    )
                }
            }
            let tools = await mcpManager.getTools(
                clientName: clientName,
                filter: githubOAuthManager.enabledCapabilities()
            )
            allClientTools[clientName] = tools
            logger.debug("Github Enabled Capabilities: \(tools)")
            enabledClients.append(clientName)
        } else {
            allClientTools.removeValue(forKey: "managed_github_mcp")
        }

        let keepingCurrent = mcpOAuthManagers.managers.merging(mcpOAuthManagers.selfManagers) {
            (current, _) in current
        }
        for (clientName, agentOAuthManager) in keepingCurrent {
            if agentOAuthManager.enabled {
                var accessToken: String?
                var refreshedAccessToken: String?

                if agentOAuthManager.user != nil {
                    accessToken = agentOAuthManager.user?.accessToken
                    logger.debug("AccessToken \(String(describing: accessToken))")
                }
                if let user = await agentOAuthManager.generateToken(refresh: true) {
                    refreshedAccessToken = user.accessToken
                    // If token has been refreshed OR client does not exist
                    logger.debug("RefreshedAccessToken \(String(describing: refreshedAccessToken))")
                    if accessToken != refreshedAccessToken
                        || !mcpManager.clientExists(clientName: clientName)
                    {
                        _ = await mcpManager.reconnect(
                            clientName: clientName,
                            url: agentOAuthManager.server.url,
                            authToken: refreshedAccessToken!
                        )
                    }
                }
                let tools = await mcpManager.getTools(clientName: clientName, filter: [])
                allClientTools[clientName] = tools
                enabledClients.append(clientName)
            } else {
                allClientTools.removeValue(forKey: clientName)
            }
        }
    }
}

// MARK: Utility
extension NotchView {
    private func updateHistoryList() async {
        histories = await historyStore.getAll(limit: 100)
    }

    private func createTitle(for history: [[String: Any]], fallback: String) -> String {
        for entry in history {
            guard let content = entry["content"] as? [[String: Any]] else { continue }
            for item in content {
                if (item["type"] as? String) == "text",
                    let text = item["text"] as? String,
                    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    return String(text.prefix(60))
                }
            }
        }
        return fallback
    }

    private func close() {
        AnalyticsManager.shared.customEvent(
            view: .NotchView,
            primary: .function,
            secondary: "close",
            sev: .info
        )
        windowSize = WindowSize.notchIsCollapsed
        (width, height) = updateWindowSize(windowSize)
        lastExpandedWindowSize =
            expandSidebar
            ? WindowSize.sidebarIsExpanded : WindowSize.sidebarIsCollapsed
    }

    private func open() {
        AnalyticsManager.shared.customEvent(
            view: .NotchView,
            primary: .function,
            secondary: "open",
            sev: .info
        )
        if windowSize == WindowSize.sidebarIsExpanded
            || windowSize == WindowSize.sidebarIsCollapsed
        {
            windowSize = WindowSize.chatIsShown
        } else {
            windowSize = lastExpandedWindowSize
        }
        (width, height) = updateWindowSize(windowSize)
        lastExpandedWindowSize = windowSize
        gainFocus()
    }

    private func minimize() {
        AnalyticsManager.shared.customEvent(
            view: .NotchView,
            primary: .function,
            secondary: "minimize",
            sev: .info
        )
        windowSize = WindowSize.notchIsCollapsed
        (width, height) = updateWindowSize(windowSize)
    }

    private func maximize() {
        AnalyticsManager.shared.customEvent(
            view: .NotchView,
            primary: .function,
            secondary: "maximize",
            sev: .info
        )
        if windowSize == WindowSize.chatIsShown {
            windowSize = WindowSize.chatIsExpanded
        } else {
            windowSize = WindowSize.chatIsShown
        }
        (width, height) = updateWindowSize(windowSize)
        lastExpandedWindowSize = windowSize
    }

    private func sidebarToggle() {
        AnalyticsManager.shared.customEvent(
            view: .NotchView,
            primary: .function,
            secondary: "sidebarToggle",
            sev: .info
        )
        expandSidebar.toggle()

        if windowSize == WindowSize.sidebarIsExpanded {
            windowSize = WindowSize.sidebarIsCollapsed
        } else if windowSize == WindowSize.sidebarIsCollapsed {
            windowSize = WindowSize.sidebarIsExpanded
        }

        (width, height) = updateWindowSize(windowSize)
        lastExpandedWindowSize = windowSize
    }

    private func dragViewY(multiplier: CGFloat) {
        if windowSize == WindowSize.notchIsCollapsed {
            return
        }
        if windowSize == WindowSize.chatIsExpanded {
            toastText = "Can not reposition AI Thing when it is expanded."
            showToast = true
            return
        }
        let offset: CGFloat = 16
        modifyWindowTopOffset(offset * multiplier, lastExpandedWindowSize)
    }

    private func getHistory(tabId: String) async -> History? {
        return await historyStore.get(id: tabId)
    }

    private func storeHistory(tabId: String, tabTitle: String, history: [[String: Any]]) async {
        await historyStore.store(id: tabId, title: tabTitle, history: history)
    }
}

extension Array {
    fileprivate subscript(safe i: Index) -> Element? { indices.contains(i) ? self[i] : nil }
}
