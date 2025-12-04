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
    // MARK: - Environment Objects
    @EnvironmentObject var connectionManager: ConnectionManager
    @EnvironmentObject var loginManager: LoginManager
    @EnvironmentObject var firestoreManager: FirestoreManager
    @EnvironmentObject var appContext: AppContext
    @EnvironmentObject var automationManager: AutomationManager
    @EnvironmentObject var screenshotMonitor: ScreenshotMonitor

    // MARK: - Observed Objects
    @ObservedObject var viewModel: NotchViewModel

    // MARK: - Bindings
    @Binding var currentTabId: String
    @Binding var allClientTools: [String: [[String: Any]]]
    @Binding var managedModels: [ModelInfo]
    @Binding var toastText: String

    // MARK: - Constants & Closures
    let tabId: String
    let close: () -> Void
    let minimize: () -> Void
    let expand: () -> Void
    let isTabShowing: () -> Bool
    let isTabRemoved: () -> Bool
    let updateHistoryList: () async -> Void
    let getHistory: (String) async -> History?
    let storeHistory: (String, [[String: Any]]) async -> Void
    let setUnseen: (String, Bool) async -> Void
    let setTitle: (String, String) async -> Void
    let startSelectionPoll: () -> Void
    let stopSelectionPoll: () -> Void
    let logger = Logger(subsystem: "com.thisisnsh.mac.AIThing", category: "IntelligenceView")
    let cornerRadius: CGFloat = 24
    let internalToolProvider = InternalToolProvider()
    let baseHeight: CGFloat = 24

    // MARK: - State
    @State private var refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    @State private var tabTitle: String = ""
    @State private var inputHeight: CGFloat = 24
    @State private var textSize: CGFloat = 14
    @State private var isThinking: Bool = false
    @State private var isThinkingText: LocalizedStringKey = "Responding..."
    @State private var history: History?
    @State private var modelInput: [[String: Any]] = []
    @State private var modelOutput: String = ""
    @State private var modelContext: [DroppedContent] = []
    @State private var toolCall: String = ""
    @State private var showRefreshButton = false
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
    @State private var showGetStarted: Bool = false
    @State private var getStarted: LocalizedStringKey = ""
    @State private var appContextEnabled: Bool = false
    @State private var hoverAppContextEnabled: Bool = false
    @State private var selectedAppIcon: NSImage? = nil
    @State private var selectedAppName = ""
    @State private var selectedWindowName = ""
    @State private var toast = ""
    @State private var hoverRed: Bool = false
    @State private var hoverYellow: Bool = false
    @State private var hoverGreen: Bool = false

    // MARK: - Focus State
    @FocusState private var isFocused: Bool

    // MARK: - Computed Properties
    var appContextText: String {
        if appContextEnabled {
            "\(selectedAppName)\(selectedWindowName.count > 0 ? ": " : "")\(selectedWindowName)"
        } else if !appContext.appName.isEmpty {
            "\(appContext.appName)\(appContext.windowName.count > 0 ? ": " : "")\(appContext.windowName)"
        } else {
            ""
        }
    }

    var appContextWidth: CGFloat {
        if appContextText.isEmpty {
            return 0
        }
        let font = NSFont.systemFont(ofSize: 10, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = (appContextText as NSString).size(withAttributes: attributes)
        let paddingAndIcon: CGFloat = 8 + 16 + 12 + 8
        return min(size.width + paddingAndIcon, 200)
    }

    // MARK: - Body
    var body: some View {
        Group {
            if isTabShowing() {
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

                            ZStack {
                                ChatView(
                                    history: $history,
                                    query: $displayQuery,
                                    modelOutput: $modelOutput,
                                    toolCall: $toolCall,
                                    showRefreshButton: $showRefreshButton,
                                    isThinking: $isThinking
                                )
                                .padding(.vertical, -8)
                                .padding(.bottom, -24)
                                .frame(
                                    maxWidth: .infinity,
                                    maxHeight: .infinity,
                                    alignment: .topLeading
                                )

                                if !isThinking, !showMcpTools, showSavedQueries {
                                    SaveQueryView()
                                        .frame(
                                            maxWidth: .infinity,
                                            maxHeight: .infinity,
                                            alignment: .bottomLeading
                                        )
                                        .padding(.leading, -8)
                                }

                                if modelOutput.isEmpty, showRefreshButton {
                                    HoverableTabButton(
                                        title: "Refresh",
                                        isActive: true,
                                        action: {
                                            // Left empty intentionally. Users can click this for their satisfaction.
                                        },
                                        deleteAction: {},
                                        image: "arrow.clockwise",
                                        isDeletable: false,
                                        isExpanded: true,
                                        fixedSize: true,
                                        cornerRadius: 16
                                    )
                                    .frame(
                                        maxWidth: .infinity,
                                        maxHeight: .infinity,
                                        alignment: .bottom
                                    )
                                    .onAppear {
                                        if modelOutput.isEmpty {
                                            isThinking = true
                                            isThinkingText = "Responding in Background..."
                                        }
                                    }
                                    .onDisappear {
                                        isThinking = false
                                        isThinkingText = "Responding..."
                                    }
                                }
                            }
                            .padding(.bottom, showMcpTools ? -200 : 0)

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
                    .padding(8)
                    .onAppear {
                        selectionEnabled = viewModel.selectionPolling

                        let apiKey = getAnthropicAPIKey() ?? ""
                        
                        // Skip login check if Firebase isn't configured
                        let isFirebaseConfigured = FirebaseConfiguration.shared.isConfigured
                        var loggedIn = !isFirebaseConfigured // Treat as logged in if Firebase is disabled
                        
                        if isFirebaseConfigured {
                            switch loginManager.authState {
                            case .signedIn(let user):
                                loggedIn = true
                                AnalyticsManager.shared.setUserId(user.uid)
                            default:
                                loggedIn = false
                                AnalyticsManager.shared.setUserId(nil)
                            }
                        }

                        if !loggedIn && apiKey.isEmpty {
                            getStarted =
                                "Get started by following the instructions [here](https://aithing.dev/getstarted)."
                            showGetStarted = true
                        } else if apiKey.isEmpty {
                            getStarted =
                                "Please add the API key to continue. [How?](https://aithing.dev/getstarted)"
                            showGetStarted = true
                        } else if !loggedIn {
                            getStarted =
                                "Please log in to continue. [How?](https://aithing.dev/getstarted)"
                            showGetStarted = true
                        } else {
                            getStarted = ""
                            showGetStarted = false
                        }
                    }
                    .task {
                        await setUnseen(tabId, false)

                        history = await getHistory(tabId)
                        if let history = history {
                            modelInput = history.history
                            tabTitle = history.title ?? "New Chat"
                        } else {
                            tabTitle = "New Chat"
                            let greeting = await firestoreManager.getGreeting() ?? ""
                            if !greeting.isEmpty { modelOutput = greeting }
                        }

                        let notification = await firestoreManager.getNotification() ?? ""
                        if !notification.isEmpty { modelOutput = notification }

                        if modelInput.isEmpty { showSavedQueries = true }
                    }
                    .onChange(of: viewModel.selectedText) { text in
                        if isTabShowing() {
                            selectedText = text
                        }
                    }
                    .onChange(of: selectionEnabled) { _ in
                        if selectionEnabled {
                            startSelectionPoll()
                        } else {
                            stopSelectionPoll()
                        }
                    }
                    .onReceive(refreshTimer) { _ in
                        if isTabShowing() {
                            Task {
                                let newHistory = await getHistory(tabId)

                                // Exit on no change
                                if newHistory?.history.count ?? 0 == history?.history.count ?? 0 {
                                    return
                                }

                                history = newHistory

                                if let history = history {
                                    modelInput = history.history
                                    tabTitle = history.title ?? "New Chat"
                                }

                                await setUnseen(tabId, false)
                                logger.debug("Auto 5-Second Refresh Window \(tabId)")
                            }
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
                                    screenshotMonitor.updateKnownFiles()
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

                        // You can't know yet, so just return true to accept the drop.
                        return true
                    } isTargeted: {
                        if isTabShowing() {
                            isDropping = $0
                        }
                    }
                }
            } else {
                Color.clear.frame(width: 0, height: 0)
            }
        }
        .onAppear {
            logger.debug("OnAppear \(tabId)")
            AnalyticsManager.shared.screenView(screenName: .IntelligenceView)
        }
    }
}

