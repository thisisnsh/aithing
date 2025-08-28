import SwiftUI

enum SettingsTab: String { case account, models, agents, preferences }

struct SettingsView: View {
    @EnvironmentObject var loginManager: LoginManager
    @EnvironmentObject var firestoreManager: FirestoreManager

    @EnvironmentObject var googleOAuthManager: GoogleOAuthManager
    @EnvironmentObject var gitHubOAuthManager: GitHubOAuthManager

    @Binding var isPresented: Bool
    var setPanelVisibility: () -> Void
    let setPanelPassthrough: (_ enabled: Bool) -> Void
    @Binding var managedModels: [ModelInfo]
    let onHistory: () -> Void
    @State private var selectedTab: SettingsTab = getSelectedTab()

    // Models
    @State private var apiKey: String = getAnthropicAPIKey() ?? ""
    @FocusState private var apiKeyFieldFocused: Bool
    @State private var modelSelected: String = getModel()
    @State private var byokSelected: Bool = getByokSelected()

    // Agents
    @State private var agents: [AgentEntry] = getAgentEntries()
    @State private var showAddAgent = false
    @State private var agentType = "Global"
    @State private var agentName = ""
    @State private var agentPrimary = ""
    @State private var agentSecondary = ""
    private let agentTypes: [String] = ["Global", "Local"]
    @State private var agentMaxCount = 5
    @State private var showToast = false
    @State private var toastText: String = ""

    // Preferences
    @State private var preferencesShowInScreenshot = getPreferencesShowInScreenshot()
    @State private var preferencesCaptureFullScreen = getPreferencesCaptureFullScreen()

    // Account/Credits
    @State private var creditsTotal = 0
    @State private var creditsUsed = 0

    private func updatePassthrough(inside: Bool) { setPanelPassthrough(!inside) }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case .account:
                        SettingsAccountTab(
                            authState: loginManager.authState,
                            signIn: { await signIn() },
                            signOut: { await signOut() },
                            creditsUsed: creditsUsed,
                            creditsTotal: creditsTotal,
                            onHistory: { self.onHistory() }
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
                            showAddAgent: $showAddAgent,
                            agentTypes: agentTypes,
                            agentType: $agentType,
                            agentName: $agentName,
                            agentPrimary: $agentPrimary,
                            agentSecondary: $agentSecondary,
                            agentMaxCount: $agentMaxCount,
                            showToast: $showToast,
                            toastText: $toastText,
                            addAgentEntry: addAgentEntry,
                            saveAgents: saveAgents,
                            deleteAgent: deleteAgent
                        )
                        .environmentObject(googleOAuthManager)
                        .environmentObject(gitHubOAuthManager)

                    case .preferences:
                        SettingsPreferencesTab(
                            preferencesShowInScreenshot: $preferencesShowInScreenshot,
                            preferencesCaptureFullScreen: $preferencesCaptureFullScreen,
                            setPreferencesShowInScreenshot: setPreferencesShowInScreenshot,
                            setPreferencesCaptureFullScreen: setPreferencesCaptureFullScreen,
                            setPanelVisibility: setPanelVisibility
                        )
                    }
                }
                .padding()
            }
        }
        .onDisappear {
            saveModels()
            saveAgents()
        }
        .onHover(perform: updatePassthrough)
        .task {
            await getCredits()
            AnalyticsManager.shared.screenView(
                screenName: "settings_view",
                screenClass: "settings_view"
            )
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 16)

            sidebarButton("Account", isActive: selectedTab == .account) {
                selectedTab = .account
                setSelectedTab(value: selectedTab)
                saveModels()
                saveAgents()
                AnalyticsManager.shared.screenView(
                    screenName: "account",
                    screenClass: "settings_view"
                )
            }
            sidebarButton("Models", isActive: selectedTab == .models) {
                selectedTab = .models
                setSelectedTab(value: selectedTab)
                saveModels()
                saveAgents()
                AnalyticsManager.shared.screenView(
                    screenName: "models",
                    screenClass: "settings_view"
                )
            }
            sidebarButton("Agents", isActive: selectedTab == .agents) {
                selectedTab = .agents
                setSelectedTab(value: selectedTab)
                saveModels()
                saveAgents()
                AnalyticsManager.shared.screenView(
                    screenName: "agents",
                    screenClass: "settings_view"
                )
            }
            sidebarButton("Preferences", isActive: selectedTab == .preferences) {
                selectedTab = .preferences
                setSelectedTab(value: selectedTab)
                saveModels()
                saveAgents()
                AnalyticsManager.shared.screenView(
                    screenName: "preferences",
                    screenClass: "settings_view"
                )
            }

            Spacer()

            Button(action: {
                AnalyticsManager.shared.customAppQuit()
                AppDelegate.allowQuit = true
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit")
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.black.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.plain)

            Text("Version 1.5.5")
                .font(.system(size: 10, weight: .medium))
                .padding(.top, 8)
                .padding(.horizontal, 16)

            Link(
                "Report Bug",
                destination: URL(
                    string:
                        "mailto:help@aithing.dev?subject=Bug Report \(Date())&body=Description:\nPlease describe the issue.\n\nScreenshot:\n(Optional) Attach a screenshot. Make sure 'Show in Screenshot' is enabled in Settings."
                )!
            )
            .font(.system(size: 10, weight: .medium))
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .onHover { perform in
                if perform {
                    AnalyticsManager.shared.selectItem(
                        itemID: "report_bug_hover",
                        itemName: "report_bug_hover"
                    )
                }
            }

            Color.clear.frame(height: 16)
        }
        .frame(width: 160)
        .background(Color.gray.opacity(0.1))
    }

    private func sidebarButton(_ title: String, isActive: Bool, action: @escaping () -> Void)
        -> some View
    {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(isActive ? Color.black.opacity(0.5) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
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

        await getCredits()
        AnalyticsManager.shared.login(method: "google")
    }

    func signOut() async {
        loginManager.signOut()
        creditsTotal = 0
        creditsUsed = 0
        AnalyticsManager.shared.setUserId(nil)
    }

    func getCredits() async {
        switch loginManager.authState {
        case .signedIn(let user):
            guard let profile = await firestoreManager.getProfile(user: user) else {
                creditsTotal = 0
                creditsUsed = 0
                return
            }
            creditsUsed = profile.creditsUsed

            let creditsPlans = await firestoreManager.fetchCreditsPlans(
                email: profile.email
            )
            creditsTotal = profile.creditsTotal + creditsPlans
        default:
            creditsTotal = 0
            creditsUsed = 0
        }
    }

    func saveModels() {
        setModel(value: modelSelected)
        setByokSelected(value: byokSelected)
        setAnthropicAPIKey(value: apiKey)
    }

    func addAgentEntry() -> String {
        let entry: Entry
        if agentType == "Global" {
            entry =
                agentSecondary.isEmpty
                ? .url(name: agentName, url: agentPrimary)
                : .urlWithToken(name: agentName, url: agentPrimary, token: agentSecondary)
        } else {
            entry = .command(
                name: agentName,
                command: agentPrimary,
                arguments: agentSecondary.split(separator: " ").map(String.init)
            )
        }

        let newAgent = AgentEntry(id: UUID(), entry: entry, isEnabled: true)
        agents.append(newAgent)

        AnalyticsManager.shared.customEventAgent(agent: agentName)

        agentType = "Global"
        agentName = ""
        agentPrimary = ""
        agentSecondary = ""
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
