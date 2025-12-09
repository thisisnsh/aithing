//
//  SettingsView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/13/25.
//

import Sparkle
import SwiftUI

struct SettingsView: View {
    // MARK: - Environment Objects
    @EnvironmentObject var loginManager: LoginManager
    @EnvironmentObject var firestoreManager: FirestoreManager
    @EnvironmentObject var googleAuthManager: GoogleAuthManager
    @EnvironmentObject var githubAuthManager: GithubAuthManager
    @EnvironmentObject var mcpAuthManagers: MCPAuthManagers
    @EnvironmentObject var automationManager: AutomationManager
    @EnvironmentObject var screenshotMonitor: ScreenshotMonitor

    // MARK: - Bindings
    @Binding var isPresented: Bool
    @Binding var allModels: [ModelInfo]
    @Binding var selectedTab: SettingsTab

    // MARK: - Constants & Closures
    let close: () -> Void
    let setPanelVisibility: () -> Void
    let getManagedAgents: () async -> Void
    let updater: SPUUpdater
    let cornerRadius: CGFloat = 24

    // MARK: - State
    @State var hoverRed: Bool = false
    @State var hoverYellow: Bool = false
    @State var hoverGreen: Bool = false
    @State var apiKeys: APIKeys = getAPIKeys()
    @State var modelSelected: String = getModel() ?? ""
    @State var agents: [AgentEntry] = getAgentEntries()
    @State var usageData: Usage = Usage()

    // MARK: - Focus State
    @FocusState private var apiKeyFieldFocused: Bool

    // MARK: - Body
    var body: some View {
        if isPresented {
            ZStack {
                GlassBackgroundShape(cornerRadius: cornerRadius, tintBlack: true)

                VStack {
                    TitleView()
                        .padding(8)

                    Divider()
                        .padding(.horizontal, -8)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack {
                            switch selectedTab {
                            case .account:
                                AccountTab(
                                    authState: loginManager.authState,
                                    signIn: { await signIn() },
                                    signOut: { await signOut() },
                                    usageData: usageData,
                                    onHistory: {}
                                )

                            case .models:
                                ModelTab(
                                    modelSelected: $modelSelected,
                                    apiKeys: $apiKeys,
                                    allModels: allModels,
                                    saveModels: saveModels,
                                    bindingForModel: bindingForModel
                                )

                            case .agents:
                                AgentsTab(
                                    agents: $agents,
                                    addAgentEntry: addAgentEntry,
                                    saveAgents: saveAgents,
                                    deleteAgent: deleteAgent
                                )
                                .environmentObject(googleAuthManager)
                                .environmentObject(githubAuthManager)
                                .environmentObject(mcpAuthManagers)

                            case .preferences:
                                PreferencesTab(setPanelVisibility: setPanelVisibility)
                                    .environmentObject(screenshotMonitor)

                            case .automations:
                                AutomationTab()
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
                .onChange(of: selectedTab) { _ in
                    setSelectedTab(value: selectedTab)
                    saveModels()
                    saveAgents()
                }
                .task {
                    await getManagedAgents()
                    await getUsageData()
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

            Text("Settings")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.leading, 8)

            Spacer()

            CheckForUpdatesButton(updater: updater)
        }
        .frame(height: 16)
    }

    func bindingForModel(_ binding: Binding<String>, _ target: String) -> Binding<Bool> {
        Binding<Bool>(
            get: { binding.wrappedValue == target },
            set: { newValue in if newValue { binding.wrappedValue = target } }
        )
    }

    func signIn() async {
        await loginManager.signInWithGoogle()
        await getUsageData()
    }

    func signOut() async {
        loginManager.signOut()
        usageData = Usage()
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
        setAPIKeys(value: apiKeys)
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
