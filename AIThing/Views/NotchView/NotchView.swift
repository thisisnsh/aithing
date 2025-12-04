//
//  NotchView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 10/31/25.
//

import Sparkle
import SwiftUI
import os

struct NotchView: View {
    // MARK: - Environment Objects
    @EnvironmentObject var appContext: AppContext

    // MARK: - State Objects
    @StateObject private var connectionManager = ConnectionManager()
    @StateObject private var loginManager = LoginManager()
    @StateObject private var firestoreManager = FirestoreManager()
    @StateObject private var automationManager = AutomationManager(onExecute: { _ in })
    @StateObject private var screenshotMonitor = ScreenshotMonitor()
    @StateObject private var googleAuthManager = GoogleAuthManager()
    @StateObject private var githubAuthManager = GithubAuthManager()
    @StateObject private var mcpAuthManagers = MCPAuthManagers()

    // MARK: - Observed Objects
    @ObservedObject var viewModel: NotchViewModel

    // MARK: - Constants & Closures
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
    let logger = Logger(subsystem: "com.thisisnsh.mac.AIThing", category: "NotchView")
    let historyStore = HistoryStore()
    let internalToolProvider = InternalToolProvider()
    let cornerRadiusLeft: CGFloat = 38
    let shadowBuffer: CGFloat = 32
    let maxTabs: Int = 25
    let alpha: CGFloat = 0.25
    let pixelStep: CGFloat = 1.0

    // MARK: - State
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
    @State private var tabOrder: [String] = []
    @State private var histories: [History] = []
    @State private var unseen: Bool = false
    @State private var showDragIcon = false
    @State private var showSettings = false
    @State private var toastText = ""
    @State private var hoverSidebar = false
    @State private var expandSidebar = false
    @State private var previousExpandSidebar = false
    @State private var showResizeX = false
    @State private var showResizeY = false
    @State private var smoothedY: CGFloat = 0
    @State private var smoothedX: CGFloat = 0
    @State private var smoothedDragY: CGFloat = 0
    @State private var lastAppliedY: CGFloat = 0
    @State private var lastAppliedX: CGFloat = 0
    @State private var lastAppliedDragY: CGFloat = 0
    @State private var resizeHoverTask: Task<Void, Never>?

    // MARK: - Computed Properties
    var showChatWindow: Bool {
        windowSize.rawValue >= WindowSize.chatIsShown.rawValue
    }

    var expandNotch: Bool {
        windowSize.rawValue >= WindowSize.sidebarIsCollapsed.rawValue
    }

    // MARK: - Body
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
                        .environmentObject(googleAuthManager)
                        .environmentObject(githubAuthManager)
                        .environmentObject(mcpAuthManagers)
                        .environmentObject(automationManager)
                        .environmentObject(screenshotMonitor)
                    }

                    TabContainer(
                        tabOrder: tabOrder,
                        tabs: tabs,
                        tabView: { tabView(tab: $0) }
                    )

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
                                addTab(TabItem(id: tabId))
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
                                    addTab(TabItem(id: tabId))
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
        .onChange(of: viewModel.refresh) { _ in
            (width, height) = updateWindowSize(lastExpandedWindowSize)
        }
        .onChange(of: viewModel.toggle) { _ in
            if windowSize == WindowSize.notchIsCollapsed {
                open()
            } else {
                minimize()
            }
        }
        .onChange(of: viewModel.move) { _ in
            circularNotch = !isTouchingRightEdge()
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
                logger.debug("Called automation: \(automation.title)")
                var modelInput: [[String: Any]] = []
                var modelOutput: String = ""
                let tabId = UUID().uuidString
                var title = ""
                var history: [[String: Any]] = []

                let context = ModelCallContext(
                    tabId: tabId,
                    query: automation.instructions,
                    tabHandlers: TabHandlers(
                        isTabRemoved: { false },
                        getTabTitle: { title },
                        setTabTitle: { newTitle in
                            title = newTitle
                            await self.setTitle(id: tabId, title: title)
                        }
                    ),
                    selectionHandlers: SelectionHandlers(
                        getSelectedText: { "" },
                        setSelectedText: { _ in },
                        getSelectionEnabled: { false },
                        setSelectionEnabled: { _ in }
                    ),
                    modelHandlers: ModelHandlers(
                        getModelInput: { modelInput },
                        setModelInput: { modelInput = $0 },
                        getModelOutput: { modelOutput },
                        setModelOutput: { modelOutput = $0 },
                        getModelContext: { [] },
                        clearModelContext: {},
                        getManagedModels: { managedModels }
                    ),
                    historyHandlers: HistoryHandlers(
                        getHistory: { await self.getHistory(tabId: $0) },
                        storeHistory: { _, hist in history = hist },
                        setHistory: { _ in },
                        updateHistoryList: { await updateHistoryList() }
                    ),
                    uiHandlers: UIHandlers(
                        setDisplayQuery: { _ in },
                        setToolCall: { _ in },
                        setIsThinking: { _ in },
                        animateOutput: { _ in }
                    ),
                    toolHandlers: ToolHandlers(
                        getAllClientTools: { allClientTools },
                        getUsedTools: { [] },
                        getAppContextBase64: { nil }
                    ),
                    services: ModelCallServices(
                        firestoreManager: firestoreManager,
                        loginManager: loginManager,
                        connectionManager: connectionManager,
                        automationManager: automationManager,
                        internalToolProvider: internalToolProvider
                    )
                )

                let _ = await callModel(context: context)

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
}

