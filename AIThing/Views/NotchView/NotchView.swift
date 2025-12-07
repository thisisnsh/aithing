//
//  NotchView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 10/31/25.
//

import MCP
import Sparkle
import SwiftUI
import os

struct NotchView: View {
    // MARK: - Environment Objects
    @EnvironmentObject var appContext: AppContext

    // MARK: - State Objects
    @StateObject var connectionManager = ConnectionManager()
    @StateObject var loginManager = LoginManager()
    @StateObject var firestoreManager = FirestoreManager()
    @StateObject var automationManager = AutomationManager(onExecute: { _ in })
    @StateObject var screenshotMonitor = ScreenshotMonitor()
    @StateObject var googleAuthManager = GoogleAuthManager()
    @StateObject var githubAuthManager = GithubAuthManager()
    @StateObject var mcpAuthManagers = MCPAuthManagers()

    // MARK: - Observed Objects
    @ObservedObject var viewModel: NotchViewModel

    // MARK: - Constants & Closures
    let updater: SPUUpdater
    let updateWindowSize: (WindowSize) -> (CGFloat, CGFloat)
    let modifyWindowSize: (CGSize, WindowSize) -> (CGFloat, CGFloat)
    let ignoresMouseEvents: (Bool) -> Void
    let gainFocus: () -> Void
    let isTouchingRightEdge: () -> Bool
    let windowMoveable: (Bool) -> Void
    let startSelectionPoll: () -> Void
    let stopSelectionPoll: () -> Void
    let setPanelVisibility: () -> Void
    let historyStore = HistoryStore()
    let internalToolProvider = InternalToolProvider()
    let cornerRadiusLeft: CGFloat = 38
    let shadowBuffer: CGFloat = 32
    let maxTabs: Int = 25
    let alpha: CGFloat = 0.25
    let pixelStep: CGFloat = 1.0

    // MARK: - State
    @State var width: CGFloat = 0
    @State var height: CGFloat = 0
    @State var windowSize = WindowSize.collapsed
    @State var hoverTask: Task<Void, Never>?
    @State var circularNotch = false
    @State var allModels: [ModelInfo] = []
    @State var agents: [AgentEntry] = []
    @State var allClientTools: [String: [Tool]] = [:]
    @State var focusedTabId: String = ""
    @State var tabs: [String: TabItem] = [:]
    @State var tabOrder: [String] = []
    @State var histories: [History] = []
    @State var unseen: Bool = false
    @State var showDragIcon = false
    @State var showSettings = false
    @State var toastText = ""
    @State var hoverSidebar = false
    @State var expandSidebar = false
    @State var previousExpandSidebar = false
    @State var showResizeX = false
    @State var showResizeY = false
    @State var smoothedY: CGFloat = 0
    @State var smoothedX: CGFloat = 0
    @State var smoothedDragY: CGFloat = 0
    @State var lastAppliedY: CGFloat = 0
    @State var lastAppliedX: CGFloat = 0
    @State var lastAppliedDragY: CGFloat = 0
    @State var resizeHoverTask: Task<Void, Never>?

    // MARK: - Computed Properties
    var isExpanded: Bool { windowSize == .expanded }

    // MARK: - Body
    var body: some View {
        ZStack {
            Color.clear.frame(height: shadowBuffer + 16)
                .frame(maxHeight: .infinity, alignment: .top)
                .onHover { hover in
                    ignoresMouseEvents(hover)
                }
            Color.clear.frame(height: shadowBuffer + 16)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .onHover { hover in
                    ignoresMouseEvents(hover)
                }
            Color.clear.frame(width: shadowBuffer)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onHover { hover in
                    ignoresMouseEvents(hover)
                }

            ZStack {
                NotchShapeExt()

                HStack(spacing: 0) {
                    if isExpanded {
                        ResizeViewX()
                    }

                    VStack(spacing: 0) {
                        if isExpanded && showSettings {
                            SettingsView(
                                isPresented: $showSettings,
                                allModels: $allModels,
                                close: {
                                    showSettings = false
                                    close()
                                },
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

                        if isExpanded {
                            ResizeViewY()
                        }
                    }

                    VStack(alignment: expandSidebar ? .leading : .center, spacing: 0) {
                        HStack {
                            if !isExpanded || expandSidebar {
                                ZStack(alignment: .topLeading) {
                                    LogoShape()
                                        .fill(.white)
                                        .scaledToFit()
                                        .frame(height: 32)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            if !isExpanded {
                                                open()
                                            }
                                        }

                                    if unseen {
                                        Circle().fill(.red)
                                            .frame(width: 4, height: 4)
                                    }
                                }
                            }

                            if isExpanded, expandSidebar {
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
                        .padding(.horizontal, isExpanded && expandSidebar ? 16 : 0)

                        if isExpanded {
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
                    .frame(width: isExpanded ? (expandSidebar ? 200 : 60) : 60)
                }
                .padding(.vertical, 24)

                if !toastText.isEmpty, isExpanded {
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
                            ignoresMouseEvents(!hover)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.leading, shadowBuffer)
            .padding(.vertical, shadowBuffer)
        }
        .frame(width: width, height: height)
        .onAppear {
            // Reset the view and start with closed notch
            close(initialClose: true)
            showSettings = false
            let tabId = UUID().uuidString
            addTab(TabItem(id: tabId))
            focusedTabId = tabId
        }
        .onChange(of: showSettings) { _ in
            // Refresh when settings is closed
            if !showSettings {
                Task {
                    allModels = await firestoreManager.getModelInfos()
                    let rc1 = await refreshLocalAgents()
                    toastText = ""
                    toastText = rc1
                    await refreshManagedAgents()
                }
            }
        }
        .onChange(of: viewModel.openClose) { _ in
            if windowSize == WindowSize.collapsed {
                open()
            } else {
                close()
            }
        }
        .onChange(of: viewModel.move) { _ in
            // Set curve on right edge if not touching it
            circularNotch = !isTouchingRightEdge()
        }
        .task {
            histories = await historyStore.getAll(limit: 100)
            allModels = await firestoreManager.getModelInfos()

            let rc1 = await refreshLocalAgents()
            toastText = ""
            toastText = rc1
            await refreshManagedAgents()

            automationManager.onExecute = { (automation: Automation) async in
                logger.info("Called automation: \(automation.title)")
                let modelInput: [ChatItem] = []
                var modelOutput: String = ""
                let tabId = UUID().uuidString
                var history: [ChatItem] = []

                let context = ModelCallContext(
                    tabId: tabId,
                    query: automation.instructions,
                    tabHandlers: TabHandlers(
                        isTabRemoved: { false },
                        getTabTitle: { "" },
                        setTabTitle: { await self.setTitle(id: tabId, title: $0) }
                    ),
                    selectionHandlers: SelectionHandlers(
                        getSelectedText: { "" },
                        setSelectedText: { _ in },
                        getSelectionEnabled: { false },
                        setSelectionEnabled: { _ in }
                    ),
                    modelHandlers: ModelHandlers(
                        getModelInput: { modelInput },
                        setModelInput: { _ in },
                        getModelOutput: { modelOutput },
                        setModelOutput: { modelOutput = $0 },
                        getModelContext: { [] },
                        clearModelContext: {},
                        getAllModels: { allModels }
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
                showNotification(title: "Automation Complete", body: automation.title)
            }
        }
    }
}
