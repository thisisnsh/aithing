import SwiftUI

// MARK: - Core Types shared by tabs

enum SettingsTab: String { case account, models, agents, preferences }

struct AgentEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var entry: Entry
    var isEnabled: Bool
}

enum ModelName: String, Hashable, Equatable {
    case byok_claude_opus_4_1 = "byok-claude-opus-4-1-20250805"
    case byok_claude_sonnet_4 = "byok-claude-sonnet-4-20250514"
    case byok_claude_haiku_3_5 = "byok-claude-3-5-haiku-20241022"
    case managed_claude_opus_4_1 = "managed-claude-opus-4-1-20250805"
    case managed_claude_sonnet_4 = "managed-claude-sonnet-4-20250514"
    case managed_claude_haiku_3_5 = "managed-claude-3-5-haiku-20241022"
}

struct Ratings {
    let understanding: Int
    let speed: Int
    let creativity: Int

    private func stars(for rating: Int) -> String {
        let filled = String(repeating: "★", count: rating)
        let empty = String(repeating: "", count: max(0, 5 - rating))
        return filled + empty
    }

    var shortText: String {
        "Understanding: \(understanding)/5 Speed: \(speed)/5 Creativity: \(creativity)/5"
    }
}

struct ModelInfo: Identifiable {
    let id: ModelName
    let provider: String
    let title: String
    let ratings: Ratings
    let description: String
    let iconName: String?
    let cost: Int
}

private let MANAGED_MODELS: [ModelInfo] = [
    .init(
        id: .managed_claude_haiku_3_5,
        provider: "Anthropic",
        title: "Claude Haiku 3.5",
        ratings: .init(understanding: 3, speed: 5, creativity: 3),
        description: "Fastest, most cost-effective model",
        iconName: "anthropic",
        cost: 1,
    ),
    .init(
        id: .managed_claude_sonnet_4,
        provider: "Anthropic",
        title: "Claude Sonnet 4",
        ratings: .init(understanding: 4, speed: 4, creativity: 4),
        description: "Optimal balance of intelligence, cost, and speed",
        iconName: "anthropic",
        cost: 2,
    ),
    .init(
        id: .managed_claude_opus_4_1,
        provider: "Anthropic",
        title: "Claude Opus 4.1",
        ratings: .init(understanding: 5, speed: 3, creativity: 4),
        description: "Most intelligent, but most expensive and slower",
        iconName: "anthropic",
        cost: 5,
    ),
]

private let BYOK_MODELS: [ModelInfo] = [
    .init(
        id: .byok_claude_haiku_3_5,
        provider: "Anthropic",
        title: "Claude Haiku 3.5",
        ratings: .init(understanding: 3, speed: 5, creativity: 3),
        description: "Fastest, most cost-effective model",
        iconName: "anthropic",
        cost: 0,
    ),
    .init(
        id: .byok_claude_sonnet_4,
        provider: "Anthropic",
        title: "Claude Sonnet 4",
        ratings: .init(understanding: 4, speed: 4, creativity: 4),
        description: "Optimal balance of intelligence, cost, and speed",
        iconName: "anthropic",
        cost: 0,
    ),
    .init(
        id: .byok_claude_opus_4_1,
        provider: "Anthropic",
        title: "Claude Opus 4.1",
        ratings: .init(understanding: 5, speed: 3, creativity: 4),
        description: "Most intelligent, but most expensive and slower",
        iconName: "anthropic",
        cost: 0,
    ),
]

// MARK: - Main View with all state

struct SettingsView: View {
    @EnvironmentObject var loginManager: LoginManager
    @EnvironmentObject var firestoreManager: FirestoreManager

    @Binding var isPresented: Bool
    var setPanelVisibility: () -> Void
    let setPanelPassthrough: (_ enabled: Bool) -> Void

    @State private var selectedTab: SettingsTab = getSelectedTab() ?? .account

    // Models
    @State private var apiKey: String = getAnthropicAPIKey() ?? ""
    @FocusState private var apiKeyFieldFocused: Bool
    @State private var modelSelected: ModelName = getModel() ?? .managed_claude_sonnet_4

    // Agents
    @State private var agents: [AgentEntry] = getAgentEntries()
    @State private var showAddAgent = false
    @State private var agentType = "Global"
    @State private var agentName = ""
    @State private var agentPrimary = ""
    @State private var agentSecondary = ""
    private let agentTypes: [String] = ["Global", "Local"]
    @State private var agentMaxCount = 3
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
                            creditsTotal: creditsTotal
                        )

                    case .models:
                        SettingsModelTab(
                            managedModels: MANAGED_MODELS,
                            byokModels: BYOK_MODELS,
                            modelSelected: $modelSelected,
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
        .overlay(alignment: .topLeading) {
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .frame(width: 12, height: 12)
                    .padding(20)
            }.buttonStyle(.plain)
        }
        .onHover(perform: updatePassthrough)
        .task { await getCredits() }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 64)

            sidebarButton("Account", isActive: selectedTab == .account) {
                selectedTab = .account
                setSelectedTab(value: selectedTab)
                saveModels()
                saveAgents()
            }
            sidebarButton("Models", isActive: selectedTab == .models) {
                selectedTab = .models
                setSelectedTab(value: selectedTab)
                saveModels()
                saveAgents()
            }
            sidebarButton("Agents", isActive: selectedTab == .agents) {
                selectedTab = .agents
                setSelectedTab(value: selectedTab)
                saveModels()
                saveAgents()
            }
            sidebarButton("Preferences", isActive: selectedTab == .preferences) {
                selectedTab = .preferences
                setSelectedTab(value: selectedTab)
                saveModels()
                saveAgents()
            }

            Spacer()

            Button(action: {
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

            Text("Version 1.4\nExpires: 2025-08-25")
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

            Color.clear.frame(height: 32)
        }
        .frame(width: 150)
        .background(Color.gray.opacity(0.1))
    }

    private func sidebarButton(_ title: String, isActive: Bool, action: @escaping () -> Void)
        -> some View
    {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(isActive ? Color.black.opacity(0.5) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shared helpers (kept here; passed down as closures/bindings)

    func bindingForModel(_ binding: Binding<ModelName>, _ target: ModelName) -> Binding<Bool> {
        Binding<Bool>(
            get: { binding.wrappedValue == target },
            set: { newValue in if newValue { binding.wrappedValue = target } }
        )
    }

    func boxTitle(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .medium)).padding(.vertical, 4)
    }

    // MARK: - Auth / Credits

    func signIn() async {
        await loginManager.signInWithGoogle()
        await getCredits()
    }

    func signOut() async {
        loginManager.signOut()
        await getCredits()
    }

    func getCredits() async {
        switch loginManager.authState {
        case .signedIn(let user):
            guard let profile = await firestoreManager.getProfile(user: user) else { return }
            creditsTotal = profile.creditsTotal
            creditsUsed = profile.creditsUsed
        default:
            creditsTotal = 0
            creditsUsed = 0
        }
    }

    // MARK: - Persistence (Models/Agents)

    func saveModels() {
        setModel(value: modelSelected)
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
