//
//  NotchView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 10/31/25.
//

import Sparkle
import SwiftUI
import os

struct TabItem: Equatable {
    let id: String
    var active: Bool = false
    var lastUpdated: Date = Date()

    static func == (lhs: TabItem, rhs: TabItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct NotchView: View {
    @EnvironmentObject var appContext: AppContext

    @StateObject private var mcpManager = MCPManager()
    @StateObject private var loginManager = LoginManager()
    @StateObject private var firestoreManager = FirestoreManager()
    @StateObject private var automationManager = AutomationManager(onExecute: { _ in })
    @StateObject private var screenshotMonitor = ScreenshotMonitor()

    let logger = Logger(subsystem: "com.thisisnsh.mac.AIThing", category: "NotchView")
    let historyStore = HistoryStore()
    let aiThingMcpManager = AIThingMCPManager()

    @ObservedObject var vm: NotchVM
    let updater: SPUUpdater
    let updateWindowSize: (WindowSize) -> (CGFloat, CGFloat)
    let modifyWindowBaseSize: (CGSize, WindowSize) -> (CGFloat, CGFloat)
    let modifyWindowOriginalSize: () -> Void
    let modifyWindowTopOffset: (CGFloat, WindowSize) -> Void
    let gainFocus: () -> Void
    let isTouchingRightEdge: () -> Bool
    let windowMoveable: (Bool) -> Void
    let startSelectionPoll: () -> Void
    let stopSelectionPoll: () -> Void
    let setPanelVisibility: () -> Void

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

    @State private var focusedTabId: String = ""
    @State private var tabs: [String: TabItem] = [:]
    @State private var histories: [History] = []
    @State private var unseen: Bool = false

    @State private var showDragIcon = false
    @State private var showSettings = false
    @State private var toastText = ""
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
                    if showChatWindow && showSettings {
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
                            setPanelVisibility: { self.setPanelVisibility() },
                            getManagedAgents: getManagedAgents,
                            updater: updater
                        )
                        .environmentObject(loginManager)
                        .environmentObject(firestoreManager)
                        .environmentObject(googleOAuthManager)
                        .environmentObject(githubOAuthManager)
                        .environmentObject(mcpOAuthManagers)
                        .environmentObject(automationManager)
                        .environmentObject(screenshotMonitor)
                    }

                    ForEach(Array(tabs.values.enumerated()), id: \.element.id) { index, tab in
                        tabView(tab: tab)
                    }

                    if showChatWindow {
                        ResizeViewY()
                    }
                }

                VStack(alignment: expandSidebar ? .leading : .center, spacing: 0) {
                    HStack {
                        if !expandNotch || expandSidebar {
                            ZStack(alignment: .topLeading) {
                                LogoShape()
                                    .fill(.white)
                                    .scaledToFit()
                                    .frame(height: 32)

                                if unseen {
                                    Circle().fill(.red)
                                        .frame(width: 4, height: 4)
                                }
                            }
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
                                let tabId = UUID().uuidString
                                tabs[tabId] = TabItem(id: tabId)
                                focusedTabId = tabId
                            },
                            deleteAction: {},
                            image: "plus.circle.fill",
                            isDeletable: false,
                            isExpanded: expandSidebar
                        )
                        .padding(.top, expandSidebar ? 8 : 0)

                        HoverableTabButton(
                            title: "Settings",
                            isActive: showSettings,
                            action: {
                                open()
                                if focusedTabId.isEmpty {
                                    let tabId = UUID().uuidString
                                    tabs[tabId] = TabItem(id: tabId)
                                    focusedTabId = tabId
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
                                .padding(.bottom, expandSidebar ? -16 : 0)
                        }
                    }

                    Spacer()
                }
                .frame(width: expandNotch ? (expandSidebar ? 200 : 60) : 60)
            }
            .padding(.vertical, 24)

            if !toastText.isEmpty, showChatWindow {
                Toast()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            self.toastText = ""
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
                    .shadow(color: .black, radius: 4)
                    .onHover { hover in
                        windowMoveable(hover)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.horizontal, 24)
            }

        }
        .padding(.leading, shadowBuffer)
        .padding(.vertical, shadowBuffer)
        .frame(width: width, height: height)
        .onAppear {
            AnalyticsManager.shared.screenView(screenName: .NotchView)
            close(initialClose: true)
        }
        .onChange(of: showSettings) { _ in
            // Refresh when settings is closed
            if !showSettings {
                Task {
                    managedModels = await firestoreManager.getModelInfos()
                    let rc1 = await refreshLocalAgents()
                    toastText = ""
                    toastText = rc1
                    await refreshManagedAgents()
                }
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

            let rc1 = await refreshLocalAgents()
            toastText = ""
            toastText = rc1
            await refreshManagedAgents()

            automationManager.onExecute = { (automation: Automation) async in
                logger.debug("Called automation: \(automation.id)")
                var modelInput: [[String: Any]] = []
                var modelOutput: String = ""
                let tabId = UUID().uuidString
                tabs[tabId] = TabItem(id: tabId)
                var title = ""
                var history: [[String: Any]] = []

                let _ = await callModel(
                    tabId: tabId,
                    query: automation.instructions,

                    isTabRemoved: { isTabRemoved(tabId: tabId) },
                    getAppContextBase64: { return nil },
                    getSelectedText: { return "" },
                    setSelectedText: { _ in },
                    getSelectionEnabled: { return false },
                    setSelectionEnabled: { _ in },
                    getTabTitle: { return title },
                    setTabTitle: {
                        title = $0
                        await self.setTitle(id: tabId, title: title)
                    },
                    setDisplayQuery: { _ in },
                    setToolCall: { _ in },
                    getHistory: { await self.getHistory(tabId: $0) },
                    storeHistory: { history = $1 },
                    setHistory: { _ in },
                    setIsThinking: { _ in },
                    getModelInput: { return modelInput },
                    appendModelInput: { modelInput.append($0) },
                    getModelOutput: { return modelOutput },
                    setModelOutput: { modelOutput = $0 },
                    animateOutput: { (_) async in },
                    getAllClientTools: { return allClientTools },
                    getUsedTools: { return [] },
                    getModelContext: { return [] },
                    clearModelContext: {},
                    getManagedModels: { return managedModels },
                    updateHistoryList: updateHistoryList,
                    firestoreManager: firestoreManager,
                    loginManager: loginManager,
                    mcpManager: mcpManager,
                    automationManager: automationManager,
                    aiThingMcpManager: aiThingMcpManager
                )

                if !history.isEmpty {
                    await self.storeHistory(
                        tabId: tabId,
                        history: history,
                        unseen: true
                    )
                }

                await updateHistoryList()
            }
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
                .stroke(Color.gray.opacity(0.5), lineWidth: circularNotch ? 0 : 1)
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
                .shadow(color: .gray.opacity(0.5), radius: circularNotch ? 0 : 1)
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
                            : "",
                        isActive: (focusedTabId == h.id) && !showSettings && showChatWindow,
                        action: {
                            open()
                            showSettings = false
                            tabs[h.id] = TabItem(id: h.id)
                            focusedTabId = h.id
                            removeTabs()
                        },
                        deleteAction: {
                            Task {
                                let isActive = focusedTabId == h.id
                                await historyStore.delete(id: h.id)
                                tabs.removeValue(forKey: h.id)
                                setTabActive(tabId: h.id, active: false)
                                histories = await historyStore.getAll(limit: 100)
                                if isActive {
                                    if let history = histories.first {
                                        tabs[history.id] = TabItem(id: history.id)
                                        focusedTabId = history.id
                                    } else {
                                        let tabId = UUID().uuidString
                                        tabs[tabId] = TabItem(id: tabId)
                                        focusedTabId = tabId
                                    }
                                }
                                unseen = histories.contains(where: { $0.unseen == true })
                            }
                        },
                        notification: h.unseen
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
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.yellow.opacity(0.5), lineWidth: 1)
                    }
            } else {
                Text(toastText)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.yellow.opacity(0.5), lineWidth: 1)
                    }
            }
        }
    }
}

// MARK: Tab Stuff
extension NotchView {
    @ViewBuilder
    private func tabView(tab: TabItem) -> some View {
        IntelligenceView(
            vm: vm,
            tabId: tab.id,
            currentTabId: $focusedTabId,
            allClientTools: $allClientTools,
            managedModels: $managedModels,
            toastText: $toastText,
            close: { close() },
            minimize: { minimize() },
            expand: { maximize() },
            isTabShowing: { isTabShowing(tabId: tab.id) },
            isTabRemoved: { isTabRemoved(tabId: tab.id) },
            setTabActive: { setTabActive(tabId: tab.id, active: $0) },
            updateHistoryList: { await updateHistoryList() },
            getHistory: { return await getHistory(tabId: $0) },
            storeHistory: { await storeHistory(tabId: $0, history: $1) },
            setUnseen: { await setUnseen(id: $0, unseen: $1) },
            setTitle: { await setTitle(id: $0, title: $1) },
            startSelectionPoll: { self.startSelectionPoll() },
            stopSelectionPoll: { self.stopSelectionPoll() }
        )
        .opacity(showChatWindow && !showSettings && !focusedTabId.isEmpty ? 1 : 0)
        .environmentObject(mcpManager)
        .environmentObject(loginManager)
        .environmentObject(firestoreManager)
        .environmentObject(appContext)
        .environmentObject(automationManager)
        .environmentObject(screenshotMonitor)
        .id(focusedTabId)
    }

    private func printTabs() {
        logger.debug("\(tabs.keys)")
    }

    private func isTabShowing(tabId: String) -> Bool {
        return tabId == self.focusedTabId && showChatWindow && !showSettings
    }

    private func isTabRemoved(tabId: String) -> Bool {
        !tabs.keys.contains(tabId)
    }

    private func setTabActive(tabId: String, active: Bool) {
        guard var tab = tabs[tabId] else { return }

        tab.active = active
        tab.lastUpdated = Date()
        tabs[tabId] = tab

        AnalyticsManager.shared.customEvent(
            view: .NotchView,
            primary: .activateTab,
            secondary: "\(active)",
            sev: .info
        )
    }

    // Remove tabs that are inactive for longer than 30 minutes
    private func removeTabs() {
        let minutes: Double = 30
        let cutoff = Date().addingTimeInterval(-(minutes * 60))
        let countStart = tabs.count
        tabs = tabs.filter { _, tab in
            tab.lastUpdated >= cutoff || tab.id == self.focusedTabId
        }

        let countEnd = tabs.count
        AnalyticsManager.shared
            .customEvent(
                view: .NotchView,
                primary: .removeTabs,
                secondary: "\(countStart - countEnd)",
                sev: .info
            )
    }
}

// MARK: Utility
extension NotchView {
    private func updateHistoryList() async {
        histories = await historyStore.getAll(limit: 100)
        unseen = histories.contains(where: { $0.unseen == true })
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

    private func close(initialClose: Bool = false) {
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
        screenshotMonitor.updateKnownFiles()
        screenshotMonitor.close()
        stopSelectionPoll()
        if !initialClose {
            Task { await refreshManagedAgents(forceRefresh: false) }
        }
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
        screenshotMonitor.updateKnownFiles()
        screenshotMonitor.open()
        Task { await refreshManagedAgents(forceRefresh: false) }
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
        screenshotMonitor.updateKnownFiles()
        screenshotMonitor.close()
        stopSelectionPoll()
        Task { await refreshManagedAgents(forceRefresh: false) }
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
            toastText = ""
            toastText = "Can not reposition AI Thing when it is expanded."
            return
        }
        let offset: CGFloat = 16
        modifyWindowTopOffset(offset * multiplier, lastExpandedWindowSize)
    }

    private func getHistory(tabId: String) async -> History? {
        return await historyStore.get(id: tabId)
    }

    private func storeHistory(
        tabId: String,
        history: [[String: Any]],
        unseen: Bool? = nil
    ) async {
        await historyStore.store(id: tabId, history: history, unseen: unseen)
    }

    private func setUnseen(id: String, unseen: Bool) async {
        if await historyStore.setUnseen(id: id, unseen: unseen) {
            await updateHistoryList()
        }
    }

    private func setTitle(id: String, title: String) async {
        if await historyStore.setTitle(id: id, title: title) {
            await updateHistoryList()
        }
    }
}

// MARK: AI Stuff
extension NotchView {
    private func refreshLocalAgents() async -> String {
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
            return ""
        }

        agents = newAgents
        allClientTools.removeAll()
        mcpOAuthManagers.selfManagers.removeAll()

        let disconnectRc = await mcpManager.disconnect()
        if !disconnectRc.isEmpty {
            return "Failed to stop running agents: \(disconnectRc)"
        }

        var failure = ""

        for agent in agents {
            if !agent.isEnabled {
                continue
            }

            let name: String
            let primary: String
            var connectRc: String = ""

            switch agent.entry {
            case .url(let n, let url):
                name = n
                primary = url

                // URL is oauth ready if it has well known URLs
                // Skip connecting to oauth servers now, they will be connected later
                let oauth = await McpOAuthManager.hasWellKnownUrls(url: url)
                if oauth {
                    mcpOAuthManagers.selfManagers[name] = McpOAuthManager(
                        server: McpServer(
                            id: name,
                            image: nil,
                            name: name,
                            url: url,
                            version: nil,
                            enabled: true,
                            custom: false
                        )
                    )
                    mcpOAuthManagers.selfManagers[name]?.enabled = true
                    continue
                }

                connectRc = await mcpManager.connect(clientName: name, url: url, authToken: nil)

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

            logger.info("Added Agent: \(name)")

            if connectRc.isEmpty {
                let tools = await mcpManager.getTools(clientName: name, filter: [])
                allClientTools[name] = tools
            } else {
                failure += "\n\n\(name): \(connectRc)"
            }

        }

        if !failure.isEmpty {
            AnalyticsManager.shared
                .customEvent(view: .NotchView, primary: .agentLoad, secondary: failure, sev: .error)
            return "Failed to start agents\n" + failure
        }

        return ""
    }

    private func getManagedAgents() async {
        let managedAgents = await firestoreManager.getManagedAgents()
        var allServerIds: [String] = []

        for server in managedAgents {
            if server.enabled ?? true == false { continue }

            if let id = server.id {
                allServerIds.append(id)

                if server.custom ?? false {
                    mcpOAuthManagers.customManagers[id] = server
                    continue
                }

                if !mcpOAuthManagers.managers.keys.contains(id) {
                    mcpOAuthManagers.managers[id] = McpOAuthManager(server: server)
                }

                if let manager = mcpOAuthManagers.managers[id] {
                    if manager.server.version != server.version {
                        mcpOAuthManagers.managers[id] = McpOAuthManager(server: server)
                    }
                }

                // Always update image
                if let image = server.image {
                    mcpOAuthManagers.managers[id]?.server.image = image
                }
            }
        }

        // Remove mcp servers that were added before but are no longer supported
        for key in mcpOAuthManagers.managers.keys {
            if !allServerIds.contains(key) {
                mcpOAuthManagers.managers.removeValue(forKey: key)
            }
        }
        for key in mcpOAuthManagers.customManagers.keys {
            if !allServerIds.contains(key) {
                mcpOAuthManagers.customManagers.removeValue(forKey: key)
            }
        }
    }

    private func refreshManagedAgents(forceRefresh: Bool = true) async {
        await getManagedAgents()

        // Shared reconnect logic for any MCP OAuth manager.
        func handleManager(
            clientName: String,
            isEnabled: Bool,
            currentTokenAndExpiry: () -> (token: String?, expiry: Date?),
            generateToken: @escaping () async -> String?,
            url: @escaping () -> String,
            capabilities: @escaping () -> [String]
        ) async {
            guard isEnabled else {
                allClientTools.removeValue(forKey: clientName)
                return
            }

            let (accessToken, expiry) = currentTokenAndExpiry()

            var shouldRefreshToken = true
            if let expiry, !forceRefresh {
                // Token will expire in next 10 minutes
                shouldRefreshToken = Date().addingTimeInterval(10 * 60) >= expiry
            }

            var refreshedAccessToken: String? = nil

            if shouldRefreshToken, let newToken = await generateToken() {
                refreshedAccessToken = newToken
                logger.debug(
                    "\(clientName) RefreshedAccessToken \(String(describing: refreshedAccessToken))"
                )

                // If token has been refreshed OR client does not exist
                if forceRefresh || accessToken != refreshedAccessToken
                    || !mcpManager.clientExists(clientName: clientName)
                {
                    _ = await mcpManager.reconnect(
                        clientName: clientName,
                        url: url(),
                        authToken: newToken
                    )

                    let tools = await mcpManager.getTools(
                        clientName: clientName,
                        filter: capabilities()
                    )
                    allClientTools[clientName] = tools

                    logger.info("Refreshed \(clientName) with \(tools.count) tools")
                    logger.debug("\(clientName) Capabilities: \(tools)")
                }
            }
        }

        // Precompute the dynamic managers map (same as before).
        let keepingCurrent = mcpOAuthManagers.managers.merging(mcpOAuthManagers.selfManagers) {
            current,
            _ in current
        }

        await withTaskGroup(of: Void.self) { group in
            // Google
            group.addTask {
                let (token, expiry, capabilities) = await MainActor.run {
                    (
                        self.googleOAuthManager.user?.accessToken.tokenString,
                        self.googleOAuthManager.user?.accessToken.expirationDate,
                        self.googleOAuthManager.enabledCapabilities()
                    )
                }

                let clientName = "managed_aithing_google"
                guard let server = await mcpOAuthManagers.customManagers[clientName] else {
                    await MainActor.run { _ = allClientTools.removeValue(forKey: clientName) }
                    return
                }
                if server.enabled ?? false == false {
                    await MainActor.run { _ = allClientTools.removeValue(forKey: clientName) }
                    return
                }

                await handleManager(
                    clientName: clientName,
                    isEnabled: !self.googleOAuthManager.enabled.isEmpty,
                    currentTokenAndExpiry: {
                        self.logger.debug("Google AccessToken \(String(describing: token))")
                        return (token, expiry)
                    },
                    generateToken: {
                        guard let user = await self.googleOAuthManager.generateToken(refresh: true)
                        else { return nil }
                        return user.accessToken.tokenString
                    },
                    url: { server.url },
                    capabilities: { capabilities }
                )
            }

            // GitHub
            group.addTask {
                let (token, expiry, capabilities) = await MainActor.run {
                    (
                        self.githubOAuthManager.user?.accessToken,
                        self.githubOAuthManager.user?.expiresAt,
                        self.githubOAuthManager.enabledCapabilities()
                    )
                }

                let clientName = "managed_aithing_github"
                guard let server = await mcpOAuthManagers.customManagers[clientName] else {
                    await MainActor.run { _ = allClientTools.removeValue(forKey: clientName) }
                    return
                }
                if server.enabled ?? false == false {
                    await MainActor.run { _ = allClientTools.removeValue(forKey: clientName) }
                    return
                }

                await handleManager(
                    clientName: clientName,
                    isEnabled: !self.githubOAuthManager.enabled.isEmpty,
                    currentTokenAndExpiry: {
                        self.logger.debug("Github AccessToken \(String(describing: token))")
                        return (token, expiry)
                    },
                    generateToken: {
                        guard let user = await self.githubOAuthManager.generateToken(refresh: true)
                        else { return nil }
                        return user.accessToken
                    },
                    url: { server.url },
                    capabilities: { capabilities }
                )
            }

            // Other MCP OAuth managers
            for (clientName, agentOAuthManager) in keepingCurrent {
                let (token, expiry, url) = await MainActor.run {
                    (
                        agentOAuthManager.user?.accessToken,
                        agentOAuthManager.user?.expiresAt,
                        agentOAuthManager.server.url
                    )
                }

                if agentOAuthManager.enabled == false {
                    await MainActor.run { _ = allClientTools.removeValue(forKey: clientName) }
                    return
                }

                group.addTask {
                    await handleManager(
                        clientName: clientName,
                        isEnabled: agentOAuthManager.enabled,
                        currentTokenAndExpiry: {
                            self.logger.debug("AccessToken \(String(describing: token))")
                            return (token, expiry)
                        },
                        generateToken: {
                            guard let user = await agentOAuthManager.generateToken(refresh: true)
                            else {
                                return nil
                            }
                            return user.accessToken
                        },
                        url: { url },
                        capabilities: { [] }
                    )
                }
            }
        }
    }
}

extension Array {
    fileprivate subscript(safe i: Index) -> Element? { indices.contains(i) ? self[i] : nil }
}
