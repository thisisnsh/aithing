//
//  SettingsAgentsTab.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/13/25.
//

import SwiftUI
import os

struct AgentEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var entry: Entry
    var isEnabled: Bool
}

struct SettingsAgentsTab: View {
    @EnvironmentObject var googleOAuthManager: GoogleOAuthManager
    @EnvironmentObject var gitHubOAuthManager: GithubOAuthManager
    @EnvironmentObject var notionOAuthManager: NotionOAuthManager
    @EnvironmentObject var asanaOAuthManager: AsanaOAuthManager
    @EnvironmentObject var atlassianOAuthManager: AtlassianOAuthManager

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
    @State private var notionAgentAccount: String = ""

    let logger = Logger(subsystem: "com.thisisnsh.mac.AIThing", category: "SettingsAgentsTab")

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox(
                label: Text("Managed Agents")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.bottom, 4)
            ) {
                VStack(alignment: .leading) {
                    Text(
                        """
                        Learn what you can do with [Managed Agents](https://aithing.dev/features/multiple-agents#managed-agents).
                        """
                    )
                    .font(.system(size: 10, weight: .medium))
                    .padding(.vertical, 4)
                    .foregroundStyle(.secondary)
                    Divider()
                    GoogleManagedAgentRow(
                        icon: "google",
                        title: "Google Workspace",
                        subheading: $googleAgentAccount,
                    )
                    .environmentObject(googleOAuthManager)
                    Divider()
                    GithubManagedAgentRow(
                        icon: "github",
                        title: "GitHub",
                        subheading: $githubAgentAccount,
                    )
                    .environmentObject(gitHubOAuthManager)
                    Divider()
                    NotionManagedAgentRow(
                        icon: "notion",
                        title: "Notion",
                        subheading: $notionAgentAccount,
                    )
                    .environmentObject(notionOAuthManager)
                    Divider()
                    ManagedAgentRow(
                        icon: "slack",
                        title: "Slack",
                    )
                    Divider()
                    Text(
                        """
                        Need help? Visit the [Troubleshooting](https://aithing.dev/errors/agent-troubleshooting) page.
                        Request more Managed Agents via help@aithing.dev.
                        """
                    )
                    .font(.system(size: 10, weight: .medium))
                    .padding(.vertical, 4)
                    .foregroundStyle(.secondary)
                }
                .padding(4)
            }
            .onAppear {
                Task {
                    if googleOAuthManager.enabled.count > 0 {
                        if let user = googleOAuthManager.user {
                            googleAgentAccount = user.profile?.name ?? ""
                        }
                    }
                    if gitHubOAuthManager.enabled.count > 0 {
                        if let user = gitHubOAuthManager.user {
                            githubAgentAccount = user.name ?? ""
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
                    Text(
                        """
                        Learn more about adding your [own agents](https://aithing.dev/features/multiple-agents#add-your-own-agents).
                        """
                    )
                    .font(.system(size: 10, weight: .medium))
                    .padding(4)
                    .padding(.top, 4)
                    .foregroundStyle(.secondary)

                    Divider()

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
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.black.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
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
