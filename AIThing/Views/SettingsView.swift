import Sparkle
import SwiftUI

enum SettingsTab: String { case account = "Account", models = "Models", agents = "Agents", preferences = "Preferences", automations = "Automations" }

struct SettingsView: View {
    @EnvironmentObject var loginManager: LoginManager
    @EnvironmentObject var firestoreManager: FirestoreManager
    @EnvironmentObject var googleOAuthManager: GoogleOAuthManager
    @EnvironmentObject var gitHubOAuthManager: GithubOAuthManager
    @EnvironmentObject var mcpOAuthManagers: McpOAuthManagers
    @EnvironmentObject var automationManager: AutomationManager
    @EnvironmentObject var screenshotMonitor: ScreenshotMonitor

    @Binding var isPresented: Bool
    @Binding var managedModels: [ModelInfo]
    let close: () -> Void
    let minimize: () -> Void
    let expand: () -> Void
    let setPanelVisibility: () -> Void
    let getManagedAgents: () async -> Void
    let updater: SPUUpdater
    let cornerRadius: CGFloat = 24

    @State private var selectedTab: SettingsTab = getSelectedTab()
    @State private var hoverRed: Bool = false
    @State private var hoverYellow: Bool = false
    @State private var hoverGreen: Bool = false

    // Models
    @State private var apiKey: String = getAnthropicAPIKey() ?? ""
    @FocusState private var apiKeyFieldFocused: Bool
    @State private var modelSelected: String = getModel()
    @State private var byokSelected: Bool = true  // Always true. Previously: getByokSelected()

    // Agents
    @State private var agents: [AgentEntry] = getAgentEntries()

    // Preferences
    @State private var preferencesShowInScreenshot = getPreferencesShowInScreenshot()
    @State private var preferencesCaptureFullScreen = getPreferencesCaptureFullScreen()

    // Usage
    @State private var usageData: Usage = Usage()

    var body: some View {
        if isPresented {
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

                VStack {
                    TitleView()
                        .padding(8)

                    Divider()
                        .padding(.horizontal, -8)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack {
                            switch selectedTab {
                            case .account:
                                SettingsAccountTab(
                                    authState: loginManager.authState,
                                    signIn: { await signIn() },
                                    signOut: { await signOut() },
                                    usageData: usageData,
                                    onHistory: {}
                                )

                            case .models:
                                SettingsModelTab(
                                    managedModels: managedModels,
                                    modelSelected: $modelSelected,
                                    byokSelected: $byokSelected,
                                    apiKey: $apiKey,
                                    apiKeyFieldFocused: _apiKeyFieldFocused,
                                    saveModels: saveModels,
                                    bindingForModel: bindingForModel
                                )

                            case .agents:
                                SettingsAgentsTab(
                                    agents: $agents,
                                    addAgentEntry: addAgentEntry,
                                    saveAgents: saveAgents,
                                    deleteAgent: deleteAgent
                                )
                                .environmentObject(googleOAuthManager)
                                .environmentObject(gitHubOAuthManager)
                                .environmentObject(mcpOAuthManagers)

                            case .preferences:
                                SettingsPreferencesTab(
                                    preferencesShowInScreenshot: $preferencesShowInScreenshot,
                                    preferencesCaptureFullScreen: $preferencesCaptureFullScreen,
                                    setPreferencesShowInScreenshot: setPreferencesShowInScreenshot,
                                    setPreferencesCaptureFullScreen:
                                        setPreferencesCaptureFullScreen,
                                    setPanelVisibility: setPanelVisibility,
                                )
                                .environmentObject(screenshotMonitor)

                            case .automations:
                                SettingsAutomationTab()
                                    .environmentObject(automationManager)
                            }
                        }
                        .padding(.vertical, 16)
                    }.padding(.vertical, -8)

                }
                .padding(8)
                .onDisappear {
                    saveModels()
                    saveAgents()
                }
                .task {
                    await getManagedAgents()
                    await getUsageData()
                    AnalyticsManager.shared.screenView(screenName: .SettingsView)
                }
            }
        } else {
            Color.clear.frame(width: 0, height: 0)
        }
    }

    private func TitleView() -> some View {
        HStack {
            Circle()
                .frame(width: 12, height: 12)
                .foregroundStyle(hoverRed ? .red.opacity(0.5) : .red)
                .onTapGesture { isPresented = false }
                .onHover { hoverRed = $0 }

            Circle()
                .frame(width: 12, height: 12)
                .foregroundStyle(hoverYellow ? .yellow.opacity(0.5) : .yellow)
                .onTapGesture { minimize() }
                .onHover { hoverYellow = $0 }

            Text(selectedTab.rawValue)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.leading, 8)

            Spacer()

            CheckForUpdatesView(updater: updater)

            ControlGroup {
                Button(action: {
                    selectedTab = .account
                    setSelectedTab(value: selectedTab)
                    saveModels()
                    saveAgents()
                    AnalyticsManager.shared.screenView(screenName: .SettingsAccountsTab)
                }) {
                    Label("Account", systemImage: "person.fill")
                        .labelStyle(.iconOnly)
                }
                .padding(.leading, 8)

                Button(action: {
                    selectedTab = .models
                    setSelectedTab(value: selectedTab)
                    saveModels()
                    saveAgents()
                    AnalyticsManager.shared.screenView(screenName: .SettingsModelTab)
                }) {
                    Label("Models", systemImage: "sparkles.2")
                        .labelStyle(.iconOnly)
                }
                Button(action: {
                    selectedTab = .agents
                    setSelectedTab(value: selectedTab)
                    saveModels()
                    saveAgents()
                    AnalyticsManager.shared.screenView(screenName: .SettingsAgentsTab)
                }) {
                    Label("Agents", systemImage: "pointer.arrow.ipad")
                        .labelStyle(.iconOnly)
                }
                Button(action: {
                    selectedTab = .preferences
                    setSelectedTab(value: selectedTab)
                    saveModels()
                    saveAgents()
                    AnalyticsManager.shared.screenView(screenName: .SettingsPreferencesTab)
                }) {
                    Label("Preferences", systemImage: "keyboard.fill")
                        .labelStyle(.iconOnly)
                }
                Button(action: {
                    selectedTab = .automations
                    setSelectedTab(value: selectedTab)
                    saveModels()
                    saveAgents()
                    AnalyticsManager.shared.screenView(screenName: .SettingsAutomationsTab)
                }) {
                    Label("Automations", systemImage: "clock.fill")
                        .labelStyle(.iconOnly)
                }
                .padding(.trailing, 8)
            }
            .cornerRadius(16)
        }
        .frame(height: 16)
    }

    func bindingForModel(_ binding: Binding<String>, _ target: String) -> Binding<Bool> {
        Binding<Bool>(
            get: { binding.wrappedValue == target },
            set: { newValue in if newValue { binding.wrappedValue = target } }
        )
    }

    func boxTitle(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .medium)).padding(.vertical, 4)
    }

    func signIn() async {
        await loginManager.signInWithGoogle()

        switch loginManager.authState {
        case .signedIn(let user):
            AnalyticsManager.shared.setUserId(user.uid)
        default:
            AnalyticsManager.shared.setUserId(nil)
        }

        await getUsageData()
        AnalyticsManager.shared.login(method: .google)
    }

    func signOut() async {
        loginManager.signOut()
        usageData = Usage()
        AnalyticsManager.shared.setUserId(nil)
    }

    func getUsageData() async {
        switch loginManager.authState {
        case .signedIn(let user):
            guard let profile = await firestoreManager.getProfile(user: user) else {
                usageData = Usage()
                return
            }
            usageData = profile.usageData ?? Usage()
        default:
            usageData = Usage()
        }
    }

    func saveModels() {
        setModel(value: modelSelected)
        setByokSelected(value: byokSelected)
        setAnthropicAPIKey(value: apiKey)
    }

    func addAgentEntry(
        _ type: String,
        _ name: String,
        _ primary: String,
        _ secondary: String
    ) -> String {
        let entry: Entry

        if type.isEmpty {
            return "Agent type can not be empty"
        }
        if name.isEmpty {
            return "Agent name can not be empty"
        }

        let allAgents = getAgentEntries()
        for agent in allAgents {
            switch agent.entry {
            case .url(let n, _):
                if n == name {
                    return "Agent name \(name) should be unique"
                }
            case .urlWithToken(let n, _, _):
                if n == name {
                    return "Agent name \(name) should be unique"
                }
            case .command(let n, _, _):
                if n == name {
                    return "Agent name \(name) should be unique"
                }
            }
        }

        if type == "global" {
            if primary.isEmpty {
                return "Agent URL can not be empty"
            }
            entry =
                secondary.isEmpty
                ? .url(name: name, url: primary)
                : .urlWithToken(name: name, url: primary, token: secondary)
        } else {
            if primary.isEmpty {
                return "Agent command can not be empty"
            }
            entry = .command(
                name: name,
                command: primary,
                arguments: secondary.split(separator: " ").map(String.init)
            )
        }

        let newAgent = AgentEntry(id: UUID(), entry: entry, isEnabled: true)
        agents.append(newAgent)

        AnalyticsManager.shared.customEvent(
            view: .SettingsView,
            primary: .agentAdd,
            secondary: "\(name) \(primary)",
            sev: .info
        )
        saveAgents()
        return ""
    }

    func saveAgents() { setAgentEntries(value: agents) }

    func deleteAgent(_ agent: AgentEntry) {
        if let index = agents.firstIndex(of: agent) {
            agents.remove(at: index)
            saveAgents()
        }
    }
}
