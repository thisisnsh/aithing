//
//  NotchView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 10/31/25.
//

import SwiftUI
import os

struct NotchView: View {
    @StateObject var mcpManager = MCPManager()
    @StateObject var loginManager = LoginManager()
    @StateObject var firestoreManager = FirestoreManager()

    let logger = Logger(subsystem: "com.thisisnsh.mac.AIThing", category: "NotchView")

    let updateWindowSize: (WindowSize) -> (CGFloat, CGFloat)

    @State private var width: CGFloat = 0
    @State private var height: CGFloat = 0
    @State private var windowSize = WindowSize.alpha
    @State private var hoverTask: Task<Void, Never>?

    @State private var managedModels: [ModelInfo] = []
    @State private var agents: [AgentEntry] = []
    @State private var allClientTools: [String: [[String: Any]]] = [:]

    @State private var focusedIndex: Int = -1
    @State private var histories: [History] = []
    @State private var index = 0
    @StateObject private var chatController = ChatController()

    @State private var showSettings = false
    @State private var showToast = false
    @State private var toastText = ""
    @State private var toastColor: Color = .yellow
    @State private var hoverSidebar = false
    @State private var resizeSidebar = false

    // Managed Agents
    // StateObjects not persisted after application quit
    // This is due to the nature of these servers that require token refresh
    // Best way is to disable then and enable to fetch new token
    @StateObject private var googleOAuthManager = GoogleOAuthManager()
    @StateObject private var githubOAuthManager = GithubOAuthManager()
    @StateObject private var mcpOAuthManagers = McpOAuthManagers()

    var body: some View {
        ZStack {
            NotchShape(width: width, height: height, cornerRadius: 16)
                .fill(.black)

            HStack(spacing: 0) {
                if windowSize.rawValue >= WindowSize.gamma.rawValue {
                    if showSettings {
                        Settings()
                    } else {
                        IntelligenceView(
                            isFocused: Binding(
                                get: { focusedIndex == index },
                                set: { if $0 { focusedIndex = index } }
                            ),
                            allClientTools: $allClientTools,
                            managedModels: $managedModels,
                            controller: chatController,
                            resizeAlpha: resizeAlpha,
                            resizeBeta: resizeBeta,
                            resizeGamma: resizeGamma,
                            resizeDelta: resizeDelta,
                            toggleGammaDelta: toggleGammaDelta,
                            reconnectManagedAgents: reconnectManagedAgents,
                        )
                        .environmentObject(mcpManager)
                        .environmentObject(loginManager)
                        .environmentObject(firestoreManager)
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        LogoShape()
                            .fill(.white)
                            .scaledToFit()
                            .frame(height: 32)

                        if windowSize.rawValue >= WindowSize.beta.rawValue {
                            Spacer()

                            Image(systemName: "sidebar.right")
                                .resizable()
                                .frame(width: 14, height: 14)
                                .padding(8)
                                .background(hoverSidebar ? Color.white.opacity(0.1) : .clear)
                                .cornerRadius(8)
                                .onHover { hoverSidebar = $0 }
                                .onTapGesture { resizeSidebar.toggle() }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, windowSize.rawValue >= WindowSize.beta.rawValue ? 16 : 0)

                    if windowSize.rawValue >= WindowSize.beta.rawValue {
                        Divider().opacity(0)

                        HoverableTabButton(
                            title: "New Chat",
                            isActive: false,
                            action: resizeGamma,
                            deleteAction: {},
                            image: "plus.circle.fill",
                            isDeletable: false,
                        )
                        .padding(.top, 8)

                        HoverableTabButton(
                            title: "Settings",
                            isActive: false,
                            action: { showSettings.toggle() },
                            deleteAction: {},
                            image: "gearshape.fill",
                            isDeletable: false,
                        )

                        if histories.count > 0 {
                            Divider().opacity(0).padding(.vertical, 8)
                        }

                        Sidebar()
                    }

                    Spacer()
                }
                .frame(width: windowSize.rawValue >= WindowSize.beta.rawValue ? 200 : 60)
            }
            .padding(.vertical, 24)
        }
        .frame(width: width, height: height)
        .task {
            switch loginManager.authState {
            case .signedIn(let user):
                AnalyticsManager.shared.setUserId(user.uid)
            default:
                AnalyticsManager.shared.setUserId(nil)
            }
            managedModels = await firestoreManager.getModelInfos()
            await loadAllClientTools()
            await reconnectManagedAgents()
        }
        .onAppear {
            resizeAlpha()
            Task {
                histories = await HistoryStore.shared.getAll(limit: 100)
                if let first = histories.first {
                    chatController.setHistory(first)
                }
            }
        }
        .onHover { hovering in
            hoverTask?.cancel()  // cancel any pending hover change
            hoverTask = Task { @MainActor in
                // delay a bit before applying the hover state
                try? await Task.sleep(nanoseconds: 150_000_000)  // 150ms

                guard !Task.isCancelled else { return }

                if windowSize != WindowSize.gamma {
                    if hovering {
                        if windowSize == WindowSize.alpha {
                            resizeBeta()
                        }
                    } else {
                        if windowSize == WindowSize.beta {
                            resizeAlpha()
                        }
                    }
                }
            }
        }
    }

    private func Sidebar() -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(histories.enumerated()), id: \.offset) { (i, h) in
                    HoverableTabButton(
                        title: h.title
                            ?? createTitle(for: h.history, fallback: "Session #\(i + 1)"),
                        isActive: (i == index),
                        action: {
                            resizeGamma()
                            index = i
                            chatController.setHistory(h)
                            AnalyticsManager.shared.customEvent(
                                type: .action,
                                primary: "history_read"
                            )
                        },
                        deleteAction: {
                            Task {
                                let isActive = i == index
                                await HistoryStore.shared.delete(id: h.id)
                                histories = await HistoryStore.shared.getAll(limit: 100)
                                if isActive {
                                    if index >= histories.count {
                                        index = max(0, histories.count - 1)
                                    }
                                    let history = histories[safe: index]
                                    chatController.setHistory(history)
                                }
                            }
                            resizeGamma()
                            AnalyticsManager.shared.customEvent(
                                type: .action,
                                primary: "history_remove"
                            )
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
        .frame(width: 200)
    }

    private func Settings() -> some View {
        Text("")
    }

    private func Toast() -> some View {
        MarkdownText(text: toastText)
    }

    // MARK: AI Stuff

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
            AnalyticsManager.shared.customEvent(
                type: .agent,
                primary: "disconnect_agents",
                secondary: .status_failure_high
            )
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
                type: .agent,
                primary: primary,
                secondary: .status_success
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
            AnalyticsManager.shared.customEvent(
                type: .agent,
                primary: "connect_agents",
                secondary: .status_failure_med
            )
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

            AnalyticsManager.shared.customEvent(
                type: .agent,
                primary: clientName,
                secondary: .reconnect_attempt
            )

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
                    AnalyticsManager.shared.customEvent(
                        type: .agent,
                        primary: clientName,
                        secondary: .reconnect_success
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

            AnalyticsManager.shared.customEvent(
                type: .agent,
                primary: clientName,
                secondary: .reconnect_attempt
            )

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
                    AnalyticsManager.shared.customEvent(
                        type: .agent,
                        primary: clientName,
                        secondary: .reconnect_success
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

                AnalyticsManager.shared.customEvent(
                    type: .agent,
                    primary: clientName,
                    secondary: .reconnect_attempt
                )

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
                        AnalyticsManager.shared.customEvent(
                            type: .agent,
                            primary: clientName,
                            secondary: .reconnect_success
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

    // MARK: Utility

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

    private func resizeAlpha() {
        windowSize = WindowSize.alpha
        (width, height) = updateWindowSize(windowSize)
    }

    private func resizeBeta() {
        windowSize = WindowSize.beta
        (width, height) = updateWindowSize(windowSize)
    }

    private func resizeGamma() {
        windowSize = WindowSize.gamma
        (width, height) = updateWindowSize(windowSize)
    }

    private func resizeDelta() {
        windowSize = WindowSize.delta
        (width, height) = updateWindowSize(windowSize)
    }

    private func toggleGammaDelta() {
        if windowSize == WindowSize.delta {
            resizeGamma()
        } else {
            resizeDelta()
        }
    }
}

extension Array {
    fileprivate subscript(safe i: Index) -> Element? { indices.contains(i) ? self[i] : nil }
}
