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
    @Binding var allClientTools: [String: [Tool]]
    @Binding var allModels: [ModelInfo]
    @Binding var toastText: String

    // MARK: - Constants & Closures
    let tabId: String
    let close: () -> Void
    let isTabShowing: () -> Bool
    let isTabRemoved: () -> Bool
    let updateHistoryList: () async -> Void
    let getHistory: (String) async -> History?
    let storeHistory: (String, [ChatItem]) async -> Void
    let setUnseen: (String, Bool) async -> Void
    let setTitle: (String, String) async -> Void
    let startSelectionPoll: () -> Void
    let stopSelectionPoll: () -> Void
    let cornerRadius: CGFloat = 24
    let internalToolProvider = InternalToolProvider()
    let baseHeight: CGFloat = 24

    // MARK: - State
    @State var refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    @State var tabTitle: String = ""
    @State var inputHeight: CGFloat = 24
    @State var textSize: CGFloat = 14
    @State var isThinking: Bool = false
    @State var isThinkingText: LocalizedStringKey = "Responding..."
    @State var history: History?
    @State var modelInput: [ChatItem] = []
    @State var modelOutput: String = ""
    @State var modelContext: [DroppedContent] = []
    @State var toolCall: String = ""
    @State var showRefreshButton = false
    @State var query: String = ""
    @State var displayQuery: String = ""
    @State var selectedText: String = ""
    @State var savedQueries = getSavedQueries()
    @State var showSavedQueries: Bool = false
    @State var isDropping: Bool = false
    @State var showMcpTools: Bool = false
    @State var hoverMcpTools: Bool = false
    @State var selectionEnabled: Bool = false
    @State var hoverSelectionEnabled: Bool = false
    @State var showGetStarted: Bool = false
    @State var getStarted: LocalizedStringKey = ""
    @State var appContextEnabled: Bool = false
    @State var hoverAppContextEnabled: Bool = false
    @State var selectedAppIcon: NSImage? = nil
    @State var selectedAppName = ""
    @State var selectedWindowName = ""
    @State var toast = ""
    @State var hoverRed: Bool = false
    @State var hoverYellow: Bool = false
    @State var hoverGreen: Bool = false
    @State var displayName = "Human"

    // MARK: - Focus State
    @FocusState var isFocused: Bool

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
                    GlassBackgroundShape(cornerRadius: cornerRadius, tintBlack: true)

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
                                            }
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

                            InputView()
                                .glassBackground(
                                    cornerRadius: cornerRadius - 4,
                                    style: .regularInteractive
                                )

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

                        // Check API key for the selected model's provider
                        var apiKey = ""
                        if let selectedModel = getModel() {
                            if let provider = getModelProvider(selectedModel, all: allModels) {
                                apiKey = getAPIKey(for: provider) ?? ""
                            }
                        }

                        // Skip login check if Firebase isn't configured
                        let isFirebaseConfigured = FirebaseConfiguration.shared.isConfigured
                        var loggedIn = !isFirebaseConfigured  // Treat as logged in if Firebase is disabled

                        if isFirebaseConfigured {
                            switch loginManager.authState {
                            case .signedIn(let user):
                                loggedIn = true
                                if let name = user.displayName, !name.isEmpty {
                                    displayName = name
                                }
                            default:
                                loggedIn = false
                            }
                        }

                        if !loggedIn && apiKey.isEmpty {
                            getStarted =
                                "Get started by following the instructions [here](https://aithing.dev/getstarted)."
                            showGetStarted = true
                        } else if apiKey.isEmpty {
                            getStarted =
                                "Please add the API key to continue. [How?](https://aithing.dev/faq#3-how-to-get-api-keys)"
                            showGetStarted = true
                        } else if !loggedIn {
                            getStarted = "Please log in from Settings to continue."
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
                            await animateOutput("# \(timeBasedGreeting()), \(displayName)!\n\(timeBasedSubheading())", delay: 50)
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
                    .onReceive(screenshotMonitor.$latestScreenshot) { ss in
                        if isTabShowing() {
                            if let ss = ss {
                                Task {
                                    let results = await DragFileManager.processPaths([ss.url])
                                    for r in results {
                                        modelContext.insert(r, at: 0)
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
    }
}
