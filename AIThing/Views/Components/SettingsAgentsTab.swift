//
//  SettingsAgentsTab.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/13/25.
//

import SwiftUI

struct AgentEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var entry: Entry
    var isEnabled: Bool
}

struct SettingsAgentsTab: View {
    @EnvironmentObject var googleOAuthManager: GoogleOAuthManager
    @EnvironmentObject var gitHubOAuthManager: GitHubOAuthManager

    @Binding var agents: [AgentEntry]
    @Binding var showAddAgent: Bool

    let agentTypes: [String]
    @Binding var agentType: String
    @Binding var agentName: String
    @Binding var agentPrimary: String
    @Binding var agentSecondary: String
    @Binding var agentMaxCount: Int

    @Binding var showToast: Bool
    @Binding var toastText: String

    let addAgentEntry: () -> String
    let saveAgents: () -> Void
    let deleteAgent: (AgentEntry) -> Void

    // Managed Agents
    @State private var googleAgentAccount: String = ""
    @State private var githubAgentAccount: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox {
                HStack {
                    Text(
                        """
                        Learn more about [Managed Agents](https://aithing.dev/features/multiple-agents#managed-agents) and what they can do. 
                        Need help? Visit [Troubleshooting](https://aithing.dev/errors/agent-troubleshooting).
                        """
                    )
                    .font(.system(size: 10, weight: .medium))
                    .padding(4)
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            GroupBox(
                label: Text("Managed Agents")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.bottom, 4)
            ) {
                VStack(alignment: .leading) {
                    GoogleManagedAgentRow(
                        icon: "google",
                        title: "Google Workspace",
                        subheading: $googleAgentAccount,
                    )
                    .environmentObject(googleOAuthManager)
                    Divider()
                    ManagedAgentRow(
                        icon: "github",
                        title: "GitHub",
                    )
                    Divider()
                    ManagedAgentRow(
                        icon: "notion",
                        title: "Notion",
                    )
                    Divider()
                    ManagedAgentRow(
                        icon: "slack",
                        title: "Slack",
                    )
                    Divider()
                    Text("More Agents Coming Soon.\nRequest specifc agents via help@aithing.dev.")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.vertical, 4)
                        .opacity(0.5)
                }
                .padding(4)
            }
            .onAppear {
                Task {
                    if googleOAuthManager.enabled.count > 0 {
                        if let user = googleOAuthManager.user {
                            googleAgentAccount = user.profile?.name ?? "Error"
                        }
                    }
                }
            }

            GroupBox(
                label: Text("Own Agents (Max \(agentMaxCount))")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.bottom, 4)
            ) {

                VStack(alignment: .leading) {
                    if agents.isEmpty {
                        HStack {
                            Text("No Agents Available").font(.system(size: 14, weight: .medium))
                            Spacer()
                        }
                        .padding(4)
                        .opacity(0.5)
                    } else {
                        ForEach(agents) { agent in
                            AgentRow(
                                agent: agent,
                                toggle: { newValue in
                                    if let idx = agents.firstIndex(of: agent) {
                                        agents[idx].isEnabled = newValue
                                        saveAgents()
                                    }
                                },
                                delete: { deleteAgent(agent) }
                            )
                            Divider()
                        }
                    }

                    if showAddAgent {
                        AddAgentForm(
                            agentType: $agentType,
                            agentTypes: agentTypes,
                            agentName: $agentName,
                            agentPrimary: $agentPrimary,
                            agentSecondary: $agentSecondary
                        )
                        .padding(4)
                    }

                    HStack {
                        Button {
                            if showAddAgent {
                                showToast = false
                                if agents.count < agentMaxCount {
                                    let error = addAgentEntry()
                                    if !error.isEmpty {
                                        toastText = error
                                        showToast = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
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
                        } label: {
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
                    .padding(4)
                }
            }

            GroupBox(
                label: Text("Enterprise Agents")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.bottom, 4)
            ) {
                HStack {
                    Text("Enterprise Plan Required").font(.system(size: 14, weight: .medium))
                        .opacity(0.5)
                    Spacer()
                    Link(
                        "Join Waitlist",
                        destination: URL(string: "https://get.aithing.dev/join")!
                    )
                    .foregroundStyle(.white)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .onHover { perform in
                        if perform {
                            AnalyticsManager.shared.selectItem(
                                itemID: "join_waitlist_agent_hover",
                                itemName: "join_waitlist_agent_hover"
                            )
                        }
                    }
                }
                .padding(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GoogleManagedAgentRow: View {
    @EnvironmentObject var google: GoogleOAuthManager
    let icon: String
    let title: String
    @Binding var subheading: String
    @State private var exapanded = false

    var body: some View {
        VStack {
            Button {
                exapanded.toggle()
            } label: {
                HStack {
                    Image(icon).resizable().frame(width: 16, height: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        RowTitle(title)
                        if !subheading.isEmpty {
                            RowSub(subheading)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .frame(width: 10, height: 10)
                }
            }
            .buttonStyle(.plain)

            if exapanded {
                ForEach(
                    google.toolScopesMap.keys.sorted(by: { $0.rawValue < $1.rawValue }),
                    id: \.self
                ) { tool in

                    VStack {
                        Divider()
                        HStack {
                            Text(tool.rawValue).font(.system(size: 12, weight: .medium))
                            Spacer()
                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { google.enabled.contains(tool) },
                                    set: { newValue in
                                        Task {
                                            if newValue {
                                                google.enabled.insert(tool)
                                                if let user = await google.generateToken(
                                                    refresh: false
                                                ) {
                                                    subheading = user.profile?.name ?? "Error"
                                                } else {
                                                    google.enabled.remove(tool)
                                                }
                                            } else {
                                                google.enabled.remove(tool)
                                                if google.enabled.count == 0 {
                                                    google.resetToken()
                                                }
                                            }
                                        }
                                    }
                                )
                            )
                            .toggleStyle(.switch).tint(.black).scaleEffect(0.7)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }

        }
        .padding(4)
    }
}

private struct ManagedAgentRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack {
            Image(icon).resizable().frame(width: 16, height: 16)
            RowTitle(title)
            Spacer()
            RowSub("Coming Soon")
        }
        .padding(4)
        .opacity(0.5)
    }
}

private struct AgentRow: View {
    let agent: AgentEntry
    let toggle: (Bool) -> Void
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                switch agent.entry {
                case let .url(name, url):
                    RowTitle(name)
                    RowSub("URL: \(url)")
                case let .urlWithToken(name, url, token):
                    RowTitle(name)
                    RowSub("URL: \(url)\nToken: \(token.prefix(4))...\(token.suffix(4))")
                case let .command(name, command, arguments):
                    RowTitle(name)
                    RowSub("Command: \(command)\nArguments: [\(arguments.joined(separator: " "))]")
                }
            }

            Spacer()

            Toggle("", isOn: .init(get: { agent.isEnabled }, set: toggle))
                .toggleStyle(.switch)
                .tint(.black)
                .scaleEffect(0.7)

            Button(action: delete) { Image(systemName: "trash") }
                .buttonStyle(.borderless)
        }
        .padding(4)
    }
}

private func RowTitle(_ text: String) -> some View {
    Text(text).font(.system(size: 14, weight: .medium))
}
private func RowSub(_ text: String) -> some View {
    Text(text).font(.system(size: 10, weight: .medium)).opacity(0.5)
}

private struct AddAgentForm: View {
    @Binding var agentType: String
    let agentTypes: [String]
    @Binding var agentName: String
    @Binding var agentPrimary: String
    @Binding var agentSecondary: String

    var body: some View {
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
                        .textFieldStyle(.plain)

                    Picker("", selection: $agentType) {
                        ForEach(agentTypes, id: \.self) { at in Text(at).tag(at) }
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
                            ? "https://api.githubcopilot.com/mcp/" : "/opt/homebrew/bin/docker",
                        text: $agentPrimary
                    )
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .font(.system(size: 14, weight: .medium))
                    .textFieldStyle(.plain)
                }
                .padding(.bottom, 4)

                Text(agentType == "Global" ? "Auth Token (Optional)" : "Arguments (Optional)")
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
                .textFieldStyle(.plain)
                .padding(.bottom, 4)
            }
            .padding(4)
        }
    }
}
