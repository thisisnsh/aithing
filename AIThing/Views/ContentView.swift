//
//  ContentView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/19/25.
//

import Firebase
import SwiftUI

struct TabItem: Identifiable, Equatable {
    let id: UUID
    let history: History?

    init(id: UUID = UUID(), history: History? = nil) {
        self.id = id
        self.history = history
    }
}

struct TabWidthsKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct ContentView: View {
    @EnvironmentObject var mcp: MCPManager
    @StateObject private var loginManager = LoginManager()
    @EnvironmentObject var screenshotManager: ScreenshotManager
    @StateObject private var firestoreManager = FirestoreManager()

    var onClose: () -> Void
    var updatePanelSizeFromDefault: (CGFloat) -> Void
    var updatePanelSizeFromCurrent: (CGFloat) -> Void
    var getExtraSize: () -> CGFloat
    var setPanelVisibility: () -> Void
    let setPanelPassthrough: (_ enabled: Bool) -> Void

    @State private var managedModels: [ModelInfo] = []

    @State private var agents: [AgentEntry] = []
    @State private var allClientTools: [String: [[String: Any]]] = [:]

    @State private var focusedIndex: Int = 0
    @State private var lastFocusedIndex: Int = 0

    @State private var tabs: [TabItem] = []
    @State private var maxTabs: Int = 3

    @State private var zStackWidth: CGFloat? = nil
    @State private var measuredTabWidths: [UUID: CGFloat] = [:]
    private let horizontalPad: CGFloat = 72
    private let hSpacing: CGFloat = 8
    @State private var leftPadding: CGFloat? = nil
    @State private var rightPadding: CGFloat? = nil

    @State private var showSettings = false
    @State private var showHistory = false

    @State private var showToast = false
    @State private var toastText: String = ""
    @State private var toastColor: Color = .white

    @State private var showHelp = false
    private var helpText: String {
        return """
            ## Help

            | Command | Description |   | Command | Description | 
            | ------- | ----------- | - | ------- | ----------- | 
            | ` Control (⌃) + Space ` | Show/Hide AI Thing | | ` Control (⌃) + ? ` | Show/Hide Help    | 
            | ` Control (⌃) + N `     | New Tab            | | ` Control (⌃) + W ` | Close Tab         |
            | ` Control (⌃) + S `     | Show/Hide Settings | | ` Control (⌃) + H ` | Show/Hide History |
            | ` Control (⌃) + > `     | Move to Right Tab  | | ` Control (⌃) + < ` | Move to Left Tab  |

            Still Stuck? Check http://aithing.dev 
            """
    }

    var body: some View {
        ZStack(alignment: .top) {
            HStack(alignment: .top, spacing: hSpacing) {
                Color.clear.frame(width: horizontalPad)
                ForEach(Array(tabs.enumerated()), id: \.element.id) {
                    index,
                    tab in
                    tabView(at: index, tab: tab)
                        .fixedSize(horizontal: true, vertical: false)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: TabWidthsKey.self,
                                    value: [
                                        tab.id: proxy.size.width
                                    ]
                                )
                            }
                        )
                }
                Color.clear.frame(width: horizontalPad)
            }
            .onPreferenceChange(TabWidthsKey.self) { dict in
                measuredTabWidths = dict
                recalcZStackWidth()
                edgePadding(for: focusedIndex)
            }

            if showSettings {
                Settings()
            }
            if showHistory {
                History()
            }
            if showHelp {
                Help()
            }
            if showToast {
                Toast()
            }
        }
        .frame(width: zStackWidth)
        .onAppear {
            recalcZStackWidth()
            edgePadding(for: focusedIndex)
        }
        .onChange(of: tabs) { _ in
            withAnimation(.easeInOut) {
                recalcZStackWidth()
            }
            edgePadding(for: focusedIndex)
        }
        .background(Color.clear)
        .onAppear {
            addTab()

            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.control) {
                    switch event.keyCode {
                    case 1:  // S key
                        onSetting()
                        return nil
                    case 4:  // H key
                        onHistory()
                        return nil
                    case 45:  // N key
                        if !showSettings && !showHistory {
                            addTab()
                        }
                        return nil
                    case 13:  // W key
                        if !showSettings && !showHistory {
                            closeTab()
                        }
                        return nil
                    case 43:  // Left angular arrow
                        if !showSettings && !showHistory {
                            moveFocus(-1)
                        }
                        return nil
                    case 47:  // Right angular bracket
                        if !showSettings && !showHistory {
                            moveFocus(1)
                        }
                        return nil
                    case 44:  // ?
                        onHelp()
                        return nil
                    default:
                        break
                    }
                }
                return event
            }
        }
        .onChange(of: showSettings) { newValue in
            updatePanelSizeFromCurrent(showSettings ? 500 : -500)
            Task {
                managedModels = await firestoreManager.getModelInfos()
                await loadAllClientTools()
            }
        }
        .task {
            switch loginManager.authState {
            case .signedIn(let user):
                AnalyticsManager.shared.setUserId(user.uid)
            default:
                AnalyticsManager.shared.setUserId(nil)
            }

            managedModels = await firestoreManager.getModelInfos()
            await loadAllClientTools()
        }
    }

    func Settings() -> some View {
        SettingsView(
            isPresented: $showSettings,
            setPanelVisibility: { self.setPanelVisibility() },
            setPanelPassthrough: { self.setPanelPassthrough($0) },
            managedModels: $managedModels
        )
        .background(.ultraThinMaterial)
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white, lineWidth: 1.5)
        }
        .cornerRadius(24)
        .zIndex(1)
        .frame(width: 600, height: 500)
        .padding(.leading, leftPadding)
        .padding(.trailing, rightPadding)
        .padding(.top, 96)
        .environmentObject(loginManager)
        .environmentObject(firestoreManager)
    }

    func History() -> some View {
        HistoryView(
            isPresented: $showHistory,
            setPanelPassthrough: { self.setPanelPassthrough($0) },
            continueConversation: { self.continueConversation($0) }
        )
        .background(.ultraThinMaterial)
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white, lineWidth: 1.5)
        }
        .cornerRadius(24)
        .zIndex(1)
        .frame(width: 600, height: 500)
        .padding(.leading, leftPadding)
        .padding(.trailing, rightPadding)
        .padding(.top, 96)
        .environmentObject(loginManager)
        .environmentObject(firestoreManager)
    }

    private func Help() -> some View {
        MarkdownText(text: helpText)
            .padding()
            .background(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white, lineWidth: 1.5)
            }
            .cornerRadius(24)
            .zIndex(2)
            .frame(minWidth: 600, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.leading, leftPadding)
            .padding(.trailing, rightPadding)
            .padding(.top, 96)
    }

    private func Toast() -> some View {
        MarkdownText(text: toastText)
            .padding()
            .background(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white, lineWidth: 1.5)
            }
            .cornerRadius(24)
            .zIndex(3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.leading, leftPadding)
            .padding(.trailing, rightPadding)
            .padding(.top, 96)
    }

    private func onSetting() {
        if !showSettings && !showHistory {
            addTab(bypass: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showSettings.toggle()
            showHelp = false
            showHistory = false
            if !showSettings && !showHistory {
                closeTab()
            }
        }
    }

    private func onHistory() {
        if !showSettings && !showHistory {
            addTab(bypass: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showHistory.toggle()
            showHelp = false
            showSettings = false
            if !showSettings && !showHistory {
                closeTab()
            }
        }
    }

    private func onHelp() {
        showHelp.toggle()
    }

    private func continueConversation(_ history: History) {
        screenshotManager.cancelScreenshot()

        // check if tab is already open
        if let id = UUID(uuidString: history.id) {
            if let index = tabs.firstIndex(where: { $0.id == id }) {
                showHistory = false
                closeTab()
                focusedIndex = index
                return
            }
        }

        if tabs.count >= maxTabs + 1 {
            toastColor = .red
            toastText = "Maximum of \(maxTabs) tabs reached"
            showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showToast = false
                toastColor = .white
            }
            AnalyticsManager.shared.customEventTab(action: "tab_capacity_reached")
            return
        }

        showHistory = false
        closeTab()

        let uuid = UUID(uuidString: history.id) ?? UUID()
        tabs.append(TabItem(id: uuid, history: history))
        focusedIndex = tabs.count - 1

        AnalyticsManager.shared.customEventTab(action: "tab_continue_conversation")
    }

    private func addTab(bypass: Bool = false) {
        screenshotManager.cancelScreenshot()

        let count = tabs.count
        if !bypass, count >= maxTabs {
            toastColor = .red
            toastText = "Maximum of \(maxTabs) tabs reached"
            showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showToast = false
                toastColor = .white
            }
            AnalyticsManager.shared.customEventTab(action: "tab_capacity_reached")
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            tabs.append(TabItem())
            if count > 1 {
                updatePanelSizeFromDefault(1000)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            focusedIndex = tabs.count - 1
        }

        AnalyticsManager.shared.customEventTab(action: "tab_add")
    }

    private func addTabWithoutAnimation() {
        screenshotManager.cancelScreenshot()

        let count = tabs.count
        if count >= maxTabs {
            toastColor = .red
            toastText = "Maximum of \(maxTabs) tabs reached"
            showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showToast = false
                toastColor = .white
            }
            return
        }

        tabs.append(TabItem())
        focusedIndex = tabs.count - 1

        AnalyticsManager.shared.customEventTab(action: "tab_add_without_animation")
    }

    private func closeTab() {
        screenshotManager.cancelScreenshot()

        let indexToRemove = focusedIndex

        if tabs.count == 1 { addTabWithoutAnimation() }  // Don't remove the last tab

        tabs.remove(at: indexToRemove)

        // Adjust focus index safely
        if focusedIndex >= tabs.count {
            focusedIndex = tabs.count - 1
        }

        AnalyticsManager.shared.customEventTab(action: "tab_close")
    }

    private func onClick(tabId: UUID) {
        if let newIndex = tabs.firstIndex(where: { $0.id == tabId }) {
            screenshotManager.cancelScreenshot()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Increase height to max while switching
                // It will be resized when tab in focus
                if tabs.count > 1 {
                    updatePanelSizeFromDefault(1000)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                focusedIndex = newIndex
            }
        }

        AnalyticsManager.shared.customEventTab(action: "tab_click")
    }

    private func moveFocus(_ direction: Int) {
        screenshotManager.cancelScreenshot()

        let count = tabs.count
        guard count > 0 else { return }

        let newIndex = (focusedIndex + direction + count) % count
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Increase height to max while switching
            // It will be resized when tab in focus
            if count > 1 {
                updatePanelSizeFromDefault(1000)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            focusedIndex = newIndex
        }

        AnalyticsManager.shared.customEventTab(action: "tab_move")
    }

    private func recalcZStackWidth() {
        // items in HStack: left spacer + N tabs + right spacer → gaps = items - 1 = (N + 2) - 1 = N + 1
        let gaps = CGFloat(tabs.count + 1)
        let sumTabs = tabs.reduce(0) { acc, tab in acc + (measuredTabWidths[tab.id] ?? 0) }
        let total = horizontalPad * 2 + gaps * hSpacing + sumTabs
        // If we haven't measured yet, keep width nil so layout can occur and measurements can arrive.
        if sumTabs > 0 || tabs.isEmpty {
            withAnimation(.easeInOut) {
                zStackWidth = max(total, 0)
            }
        } else {
            zStackWidth = nil
        }
    }

    private func edgePadding(for index: Int) {
        guard index >= 0, index < tabs.count else {
            leftPadding = nil
            rightPadding = nil
            return
        }

        // Left: left spacer + spacing + widths of all tabs before this one + inter-tab spacings
        let leftTabs = tabs.prefix(index)
        let leftWidth =
            horizontalPad  // left spacer
            + CGFloat(index + 1) * hSpacing  // gaps before this tab
            + leftTabs.reduce(0) { $0 + (measuredTabWidths[$1.id] ?? 0) }

        // Right: right spacer + spacing + widths of all tabs after this one + inter-tab spacings
        let rightTabs = tabs.suffix(tabs.count - index - 1)
        let rightWidth =
            horizontalPad  // right spacer
            + CGFloat(rightTabs.count + 1) * hSpacing  // gaps after this tab
            + rightTabs.reduce(0) { $0 + (measuredTabWidths[$1.id] ?? 0) }

        leftPadding = leftWidth
        rightPadding = rightWidth
    }

    @ViewBuilder
    private func tabView(at index: Int, tab: TabItem) -> some View {
        let isFocusedBinding = Binding(
            get: { focusedIndex == index },
            set: { if $0 { focusedIndex = index } }
        )
        TabView(
            isFocused: isFocusedBinding,
            tabId: tab.id,
            tabHistory: tab.history,
            allTabs: $tabs,
            allClientTools: $allClientTools,
            managedModels: $managedModels,
            showSettings: $showSettings,
            showHistory: $showHistory,
            onClick: { tabId in onClick(tabId: tabId) },
            onSetting: { self.onSetting() },
            onHelp: { self.onHelp() },
            updatePanelSizeFromDefault: { extraHeight in
                updatePanelSizeFromDefault(extraHeight)
            },
            updatePanelSizeFromCurrent: { height in
                updatePanelSizeFromCurrent(height)
            },
            setPanelPassthrough: { self.setPanelPassthrough($0) }
        )
        .environmentObject(mcp)
        .environmentObject(loginManager)
        .environmentObject(screenshotManager)
        .environmentObject(firestoreManager)
        .animation(.easeInOut(duration: 0.25), value: focusedIndex)
    }

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

        let disconnectRc = await mcp.disconnect()
        if !disconnectRc.isEmpty {
            toastColor = .red
            toastText = "Failed to wake up agents: \(disconnectRc)"
            AnalyticsManager.shared.customError(
                type: "failure_disconnect_agents",
                severity: "low",
                location: "content_view"
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showToast = false
                toastColor = .white
            }
            return
        }

        allClientTools.removeAll()

        for agent in agents {
            if !agent.isEnabled {
                continue
            }

            let name: String
            let connectRc: String

            switch agent.entry {
            case let .url(n, url):
                name = n
                connectRc = await mcp.connect(clientName: name, url: url, authToken: nil)

            case let .urlWithToken(n, url, token):
                name = n
                connectRc = await mcp.connect(clientName: name, url: url, authToken: token)

            case let .command(n, command, arguments):
                name = n
                connectRc = await mcp.connect(clientName: name, command: command, args: arguments)
            }

            if connectRc.isEmpty {
                let tools = await mcp.getTools(clientName: name)
                allClientTools[name] = tools
            } else {
                failure += "\n\n\(name): \(connectRc)"
            }
        }

        if !failure.isEmpty {
            toastColor = .red
            toastText = "Failed to wake up agents\n" + failure
            AnalyticsManager.shared.customError(
                type: "failure_connect_agents",
                severity: "warning",
                location: "content_view"
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (failure.isEmpty ? 2 : 5)) {
            showToast = false
            toastColor = .white
        }
    }

    private func createModels() async {
        await firestoreManager.createModel(
            model: .init(
                id: "claude-3-5-haiku-20241022",
                provider: "Anthropic",
                title: "Claude Haiku 3.5",
                ratings: Ratings(intelligence: 3, speed: 5, context: 3).shortText,
                description: "Fast and cost-effective answers",
                iconName: "anthropic",
                cost: 1,
                costImage: 1,
                order: 1,
            )
        )
        await firestoreManager.createModel(
            model: .init(
                id: "claude-sonnet-4-20250514",
                provider: "Anthropic",
                title: "Claude Sonnet 4",
                ratings: Ratings(intelligence: 4, speed: 4, context: 4).shortText,
                description: "Balanced performance and versatility",
                iconName: "anthropic",
                cost: 2,
                costImage: 2,
                order: 2,
            )
        )
        await firestoreManager.createModel(
            model: .init(
                id: "claude-opus-4-1-20250805",
                provider: "Anthropic",
                title: "Claude Opus 4.1",
                ratings: Ratings(intelligence: 5, speed: 3, context: 4).shortText,
                description: "Best for complex, high-intelligence tasks",
                iconName: "anthropic",
                cost: 5,
                costImage: 3,
                order: 3,
            )
        )
    }
}
