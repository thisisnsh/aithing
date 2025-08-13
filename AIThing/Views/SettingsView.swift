//
//  SettingsView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/27/25.
//

import SwiftUI

enum SettingsTab {
    case account, agents, preferences
}

struct AgentEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var entry: Entry
    var isEnabled: Bool
}

struct SettingsView: View {
    @EnvironmentObject var loginManager: LoginManager

    @Binding var isPresented: Bool
    var setPanelVisibility: () -> Void
    let setPanelPassthrough: (_ enabled: Bool) -> Void

    private func updatePassthrough(inside: Bool) {
        setPanelPassthrough(!inside)
    }

    @State private var selectedTab: SettingsTab = .account

    @State private var apiKey: String = getAnthropicAPIKey() ?? ""
    @FocusState private var apiKeyFieldFocused: Bool

    @State private var showToast = false
    @State private var toastText: String = ""

    @State private var agents: [AgentEntry] = getAgentEntries()

    @State private var showAddAgent = false
    @State private var agentTypes: [String] = ["Global", "Local"]
    @State private var agentType = "Global"
    @State private var agentName = ""
    @State private var agentPrimary = ""
    @State private var agentSecondary = ""
    @State private var agentMaxCount = 3

    @State private var preferencesShowInScreenshot = getPreferencesShowInScreenshot()
    @State private var preferencesCaptureFullScreen = getPreferencesCaptureFullScreen()

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
            Divider()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case .account:
                        AccountTab()
                    case .agents:
                        AgentTab()
                    case .preferences:
                        PreferencesTab()
                    }
                }
                .padding()
            }
        }
        .onDisappear {
            saveAPIKey()
            saveAgents()
        }
        .overlay(alignment: .topLeading) {
            Button(action: {
                isPresented = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .frame(width: 12, height: 12)
                    .padding(20)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .onHover { inside in
            updatePassthrough(inside: inside)
        }
    }

    // MARK: - Subviews

    func Sidebar() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 64)

            Button(action: { selectedTab = .account }) {
                Text("Account")
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(
                        .account == selectedTab ? Color.black.opacity(0.5) : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.plain)

            Button(action: { selectedTab = .agents }) {
                Text("Agents")
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(
                        .agents == selectedTab ? Color.black.opacity(0.5) : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.plain)

            Button(action: { selectedTab = .preferences }) {
                Text("Preferences")
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(
                        .preferences == selectedTab ? Color.black.opacity(0.5) : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.plain)

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

    func AccountTab() -> some View {
        ZStack(alignment: .top) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    apiKeyFieldFocused = false
                }

            VStack(alignment: .leading, spacing: 16) {
                GroupBox(
                    label: Text("Login")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.vertical, 4)
                ) {
                    VStack(alignment: .leading) {
                        Button(action: {
                            Task {
                                await loginManager.signInWithGoogle()
                            }
                        }) {
                            HStack {
                                Image("google")
                                    .resizable()
                                    .frame(width: 16, height: 16)

                                switch loginManager.authState {
                                case .signedIn(let user):
                                    Text(user.displayName ?? user.displayName ?? "Logged In")
                                        .font(.system(size: 14, weight: .medium))
                                    Spacer()
                                    Button(action: {
                                        loginManager.signOut()
                                    }) {
                                        Text("Log Out")
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                    .buttonStyle(.plain)
                                default:
                                    Text("Google")
                                        .font(.system(size: 14, weight: .medium))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .frame(width: 10, height: 10)
                                }

                            }
                        }
                        .buttonStyle(.plain)
                        .padding(4)

                        Divider()

                        Button(action: {}) {
                            HStack {
                                Image("apple")
                                    .resizable()
                                    .frame(width: 16, height: 16)
                                Text("Apple")
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                                Text("Coming Soon")
                                    .font(.system(size: 10, weight: .medium))
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(4)
                        .opacity(0.5)

                        Divider()

                        Button(action: {}) {
                            HStack {
                                Text("Custom SSO")
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                                Text("Enterprise Plan Required")
                                    .font(.system(size: 10, weight: .medium))
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(4)
                        .opacity(0.5)
                    }
                    .padding(4)
                }

                GroupBox(
                    label: Text("Choose the Brain")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.vertical, 4)
                ) {
                    VStack(alignment: .leading) {
                        GroupBox(
                            label: Text("Self Managed API Key")
                                .font(.system(size: 10, weight: .medium))
                                .padding(.vertical, 4)
                        ) {
                            VStack(alignment: .leading) {

                                HStack {
                                    Image("anthropic")
                                        .resizable()
                                        .frame(width: 16, height: 16)
                                    Text("Anthropic: Claude Sonnet 4")
                                        .font(.system(size: 14, weight: .medium))
                                    Spacer()
                                    Toggle("", isOn: .constant(true))
                                        .toggleStyle(.switch)
                                        .tint(.black)
                                        .scaleEffect(0.7)
                                }
                                .padding(4)

                                TextField("sk-ant-...", text: $apiKey, onCommit: saveAPIKey)
                                    .padding(.horizontal, 8)
                                    .frame(height: 32)
                                    .background(Color.black.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .padding(.bottom, 4)
                                    .font(.system(size: 14, weight: .medium))
                                    .focused($apiKeyFieldFocused)
                                    .textFieldStyle(PlainTextFieldStyle())
                            }
                            .padding(4)
                        }

                        GroupBox(
                            label: Text("Managed by AI Thing (Individual Plan Required)")
                                .font(.system(size: 10, weight: .medium))
                                .padding(.vertical, 4)
                        ) {
                            VStack(alignment: .leading) {

                                Button(action: {}) {
                                    HStack {
                                        Image("anthropic")
                                            .resizable()
                                            .frame(width: 16, height: 16)
                                        Text("Anthropic: Claude Sonnet 4")
                                            .font(.system(size: 14, weight: .medium))
                                        Spacer()
                                        Toggle("", isOn: .constant(false))
                                            .toggleStyle(.switch)
                                            .tint(.black)
                                            .scaleEffect(0.7)
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(4)

                                Divider()

                                Button(action: {}) {
                                    HStack {
                                        Image("openai")
                                            .resizable()
                                            .frame(width: 16, height: 16)
                                        Text("OpenAI: GPT-4.1")
                                            .font(.system(size: 14, weight: .medium))
                                        Spacer()
                                        Toggle("", isOn: .constant(false))
                                            .toggleStyle(.switch)
                                            .tint(.black)
                                            .scaleEffect(0.7)
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(4)
                            }
                            .padding(4)
                            .opacity(0.5)
                        }

                        GroupBox(
                            label: Text("Managed by Organization (Enterprise Plan Required)")
                                .font(.system(size: 10, weight: .medium))
                                .padding(.vertical, 4)
                        ) {
                            VStack(alignment: .leading) {
                                Button(action: {}) {
                                    HStack {
                                        Text("No Brains Available")
                                            .font(.system(size: 14, weight: .medium))
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(4)
                            }
                            .padding(4)
                            .opacity(0.5)
                        }
                    }
                    .padding(4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func AgentTab() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox {
                HStack {
                    Text("Need Help? Check http://aithing.dev")
                        .font(.system(size: 10, weight: .medium))
                        .padding(4)
                    Spacer()
                }
                .padding(4)
            }

            GroupBox(
                label: Text("Self Managed (Max \(agentMaxCount) with current plan)")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.vertical, 4)
            ) {
                VStack(alignment: .leading) {
                    if agents.isEmpty {
                        Button(action: {}) {
                            HStack {
                                Text("No Agents Available")
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(4)
                        .opacity(0.5)
                    } else {
                        ForEach(agents) { agent in
                            let entry = agent.entry
                            HStack {
                                VStack(alignment: .leading, spacing: 0) {
                                    switch entry {
                                    case let .url(name, url):
                                        Text(name)
                                            .font(.system(size: 14, weight: .medium))
                                        Text("URL: \(url)")
                                            .font(.system(size: 10, weight: .medium))
                                            .opacity(0.5)
                                    case let .urlWithToken(name, url, token):
                                        Text(name)
                                            .font(.system(size: 14, weight: .medium))
                                        Text(
                                            "URL: \(url)\nToken: \(token.prefix(4))...\(token.suffix(4))"
                                        )
                                        .font(.system(size: 10, weight: .medium))
                                        .opacity(0.5)
                                    case let .command(name, command, arguments):
                                        Text(name)
                                            .font(.system(size: 14, weight: .medium))
                                        Text(
                                            "Command: \(command)\nArguments: [\(arguments.joined(separator: " "))]"
                                        )
                                        .font(.system(size: 10, weight: .medium))
                                        .opacity(0.5)
                                    }

                                }

                                Spacer()

                                Toggle(
                                    "",
                                    isOn: Binding(
                                        get: { agent.isEnabled },
                                        set: { newValue in
                                            if let index = agents.firstIndex(of: agent) {
                                                agents[index].isEnabled = newValue
                                                saveAgents()
                                            }
                                        }
                                    )
                                )
                                .toggleStyle(.switch)
                                .tint(.black)
                                .scaleEffect(0.7)

                                Button(action: {
                                    deleteAgent(agent)
                                }) {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                            .padding(4)

                            Divider()
                        }
                    }

                    if showAddAgent {
                        GroupBox {
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("Name")
                                        .font(.system(size: 10, weight: .medium))
                                        .frame(width: 50, alignment: .leading)
                                    TextField("GitHub", text: $agentName)
                                        .padding(.horizontal, 8)
                                        .frame(height: 24)
                                        .background(Color.black.opacity(0.2))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .font(.system(size: 14, weight: .medium))
                                        .textFieldStyle(PlainTextFieldStyle())
                                    Picker("", selection: $agentType) {
                                        ForEach(agentTypes, id: \.self) { at in
                                            Text(at).tag(at)
                                        }
                                    }
                                    .pickerStyle(.radioGroup)
                                    .horizontalRadioGroupLayout()
                                    .font(.system(size: 10, weight: .medium))
                                    .buttonStyle(.borderless)
                                }
                                .padding(.bottom, 4)

                                HStack {
                                    Text(agentType == "Global" ? "URL" : "Command")
                                        .font(.system(size: 10, weight: .medium))
                                        .frame(width: 50, alignment: .leading)
                                    TextField(
                                        agentType == "Global"
                                            ? "https://api.githubcopilot.com/mcp/"
                                            : "/opt/homebrew/bin/docker",
                                        text: $agentPrimary
                                    )
                                    .padding(.horizontal, 8)
                                    .frame(height: 24)
                                    .background(Color.black.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .font(.system(size: 14, weight: .medium))
                                    .textFieldStyle(PlainTextFieldStyle())
                                }
                                .padding(.bottom, 4)

                                Text(
                                    agentType == "Global"
                                        ? "Auth Token (Optional)"
                                        : "Arguments (Optional)"
                                )
                                .font(.system(size: 10, weight: .medium))
                                TextField(
                                    agentType == "Global"
                                        ? "ghp_xYz...."
                                        : "run -i --rm -e ghp_xYz.... ghcr.io/github/github-mcp-server",
                                    text: $agentSecondary
                                )
                                .padding(.horizontal, 8)
                                .frame(height: 24)
                                .background(Color.black.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .font(.system(size: 14, weight: .medium))
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(.bottom, 4)
                            }
                            .padding(4)
                        }
                    }

                    HStack {
                        Button(action: {
                            if showAddAgent {
                                showToast = false
                                if agents.count < agentMaxCount {
                                    let error = addAgentEntry()
                                    if !error.isEmpty {
                                        toastText = error
                                        showToast = true
                                        DispatchQueue.main.asyncAfter(
                                            deadline: .now() + 5
                                        ) {
                                            showToast = false
                                            toastText = ""
                                        }
                                    } else {
                                        showAddAgent = false
                                    }
                                } else {
                                    toastText = "Maximum of \(agentMaxCount) agents allowed."
                                    showToast = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                        showToast = false
                                        toastText = ""
                                    }
                                }
                            } else {
                                showAddAgent = true
                            }
                        }) {
                            Text("+ Add Agent")
                                .font(.system(size: 12, weight: .medium))
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.black.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)

                        if showToast {
                            Text(toastText)
                                .font(.system(size: 10, weight: .medium))
                                .padding(.vertical, 4)
                        }

                        Spacer()
                    }
                }
                .padding(4)
            }

            GroupBox(
                label: Text("Managed by AI Thing (Individual Plan Required)")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.vertical, 4)
            ) {
                VStack(alignment: .leading) {
                    Button(action: {}) {
                        HStack {
                            Image("github")
                                .resizable()
                                .frame(width: 16, height: 16)
                            Text("GitHub")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Toggle("", isOn: .constant(false))
                                .toggleStyle(.switch)
                                .tint(.black)
                                .scaleEffect(0.7)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(4)

                    Divider()

                    Button(action: {}) {
                        HStack {
                            Image("google")
                                .resizable()
                                .frame(width: 16, height: 16)
                            Text("Google Workspace")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Toggle("", isOn: .constant(false))
                                .toggleStyle(.switch)
                                .tint(.black)
                                .scaleEffect(0.7)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(4)

                    Divider()

                    Text("More Agents Coming Soon...")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.vertical, 4)
                }
                .padding(4)
                .opacity(0.5)
            }

            GroupBox(
                label: Text("Managed by Organization (Enterprise Plan Required)")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.vertical, 4)
            ) {
                VStack(alignment: .leading) {
                    Button(action: {}) {
                        HStack {
                            Text("No Agents Available")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                }
                .padding(4)
                .opacity(0.5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func PreferencesTab() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox(
                label: Text("Look & Feel")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.vertical, 4)
            ) {
                VStack(alignment: .leading) {
                    Button(action: {}) {
                        HStack {
                            Image(
                                systemName: preferencesShowInScreenshot
                                    ? "eye.fill" : "eye.slash.fill"
                            )
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            Text("Show in Screenshot")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Toggle("", isOn: $preferencesShowInScreenshot)
                                .toggleStyle(.switch)
                                .tint(.black)
                                .scaleEffect(0.7)
                                .onChange(of: preferencesShowInScreenshot) { newValue in
                                    preferencesShowInScreenshot.toggle()
                                    setPreferencesShowInScreenshot(
                                        value: preferencesShowInScreenshot
                                    )
                                    setPanelVisibility()
                                }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(4)

                    Divider()

                    Button(action: {}) {
                        HStack {
                            Image(
                                systemName: preferencesCaptureFullScreen
                                    ? "camera.metering.matrix" : "camera.metering.spot"
                            )
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            Text("Capture Entire Screen on @this")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Toggle("", isOn: $preferencesCaptureFullScreen)
                                .toggleStyle(.switch)
                                .tint(.black)
                                .scaleEffect(0.7)
                                .onChange(of: preferencesCaptureFullScreen) { newValue in
                                    preferencesCaptureFullScreen.toggle()
                                    setPreferencesCaptureFullScreen(
                                        value: preferencesCaptureFullScreen
                                    )
                                }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(4)

                    Divider()

                    Button(action: {}) {
                        HStack {
                            Image(systemName: "paintpalette.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                            Text("Theme")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Text("Dark Translucent")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                    .opacity(0.5)
                }
                .padding(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Agents Handling

    func saveAPIKey() {
        setAnthropicAPIKey(value: apiKey)
    }

    func addAgentEntry() -> String {
        var entry: Entry
        if agentType == "Global" {
            if agentSecondary.isEmpty {
                entry = .url(name: agentName, url: agentPrimary)
            } else {
                entry = .urlWithToken(name: agentName, url: agentPrimary, token: agentSecondary)
            }
        } else {
            entry = .command(
                name: agentName,
                command: agentPrimary,
                arguments: agentSecondary.components(separatedBy: " ")
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

    func saveAgents() {
        setAgentEntries(value: agents)
    }

    func deleteAgent(_ agent: AgentEntry) {
        if let index = agents.firstIndex(of: agent) {
            agents.remove(at: index)
            saveAgents()
        }
    }
}
