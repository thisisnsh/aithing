//
//  AgentsTab.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/13/25.
//

import SwiftUI
import os

struct AgentsTab: View {
    // MARK: - Environment Objects
    @EnvironmentObject var googleAuthManager: GoogleAuthManager
    @EnvironmentObject var githubAuthManager: GithubAuthManager
    @EnvironmentObject var mcpAuthManagers: MCPAuthManagers

    // MARK: - Bindings
    @Binding var agents: [AgentEntry]

    // MARK: - Constants & Closures
    let addAgentEntry: (_ type: String, _ name: String, _ primary: String, _ secondary: String) -> String
    let saveAgents: () -> Void
    let deleteAgent: (AgentEntry) -> Void

    // MARK: - State
    @State var agentMaxCount: Int = 10
    @State var agentType: String = "global"
    @State var agentName: String = ""
    @State var agentPrimary: String = ""
    @State var agentSecondary: String = ""
    @State var showToast: Bool = false
    @State var toastText: String = ""
    @State var googleAgentAccount: String = ""
    @State var githubAgentAccount: String = ""

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if FirebaseConfiguration.shared.isConfigured {
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

                        GroupBox {
                            GoogleManagedAgentRow(
                                subheading: $googleAgentAccount,
                                title: "Google Workspace"
                            )
                            .environmentObject(googleAuthManager)
                            .environmentObject(mcpAuthManagers)
                            Divider()
                            GithubManagedAgentRow(
                                subheading: $githubAgentAccount,
                                title: "GitHub"
                            )
                            .environmentObject(githubAuthManager)
                            .environmentObject(mcpAuthManagers)
                        }

                        GroupBox {
                            VStack(alignment: .leading) {
                                ForEach(
                                    mcpAuthManagers.managers.keys.sorted { lhs, rhs in
                                        let lhsEnabled =
                                            mcpAuthManagers.managers[lhs]?.enabled ?? false
                                        let rhsEnabled =
                                            mcpAuthManagers.managers[rhs]?.enabled ?? false
                                        if lhsEnabled != rhsEnabled {
                                            // enabled managers come first
                                            return lhsEnabled && !rhsEnabled
                                        } else {
                                            // if both are enabled or both disabled, sort by key
                                            return lhs < rhs
                                        }
                                    },
                                    id: \.self
                                ) { manager in
                                    if let agent = mcpAuthManagers.managers[manager],
                                        !(agent.server.custom ?? false)
                                    {
                                        ManagedAgentRow(
                                            title: agent.server.name
                                        )
                                        .environmentObject(agent)
                                        Divider()
                                    }
                                }

                                Text(
                                    "Request more managed agents via help@aithing.dev."
                                )
                                .font(.system(size: 10, weight: .medium))
                                .padding(4)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(4)

                .onAppear {
                    Task {
                        if googleAuthManager.enabled.count > 0 {
                            if let user = googleAuthManager.user {
                                googleAgentAccount = user.profile?.name ?? ""
                            }
                        }
                        if githubAuthManager.enabled.count > 0 {
                            if let user = githubAuthManager.user {
                                githubAgentAccount = user.name ?? ""
                            }
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
                    GroupBox {
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

                        Text(
                            """
                            Learn more about adding your [own agents](https://aithing.dev/features/multiple-agents#add-your-own-agents).
                            """
                        )
                        .font(.system(size: 10, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.secondary)
                        .padding(4)
                    }

                    if agents.count < agentMaxCount {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 0) {
                                AddAgentForm(
                                    agentType: $agentType,
                                    agentName: $agentName,
                                    agentPrimary: $agentPrimary,
                                    agentSecondary: $agentSecondary
                                )

                                Button {
                                    showToast = false
                                    if agents.count < agentMaxCount {
                                        let error = addAgentEntry(
                                            agentType,
                                            agentName,
                                            agentPrimary,
                                            agentSecondary
                                        )
                                        if !error.isEmpty {
                                            toastText = error
                                            showToast = true
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                                showToast = false
                                                toastText = ""
                                            }
                                        } else {
                                            agentType = ""
                                            agentName = ""
                                            agentPrimary = ""
                                            agentSecondary = ""
                                        }
                                    } else {
                                        toastText =
                                            "Maximum of \(agentMaxCount) agents allowed."
                                        showToast = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                            showToast = false
                                            toastText = ""
                                        }
                                    }
                                } label: {
                                    Text("+ Add Agent")
                                        .font(.system(size: 12, weight: .medium))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 32)
                                        .background(Color.black.opacity(0.2))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .padding(4)

                                if showToast {
                                    Text(toastText)
                                        .foregroundStyle(.red)
                                        .font(.system(size: 10, weight: .medium))
                                        .padding(4)
                                }
                            }
                        }

                    }
                }
                .padding(4)
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AddAgentForm: View {
    // MARK: - Bindings
    @Binding var agentType: String
    @Binding var agentName: String
    @Binding var agentPrimary: String
    @Binding var agentSecondary: String

    // MARK: - Body
    var body: some View {

        VStack(alignment: .leading) {
            HStack(spacing: 0) {
                Button {
                    agentType = "global"
                } label: {
                    Text("Remote Server")
                        .font(.system(size: 12, weight: .medium))
                        .frame(height: 32)
                        .frame(maxWidth: .infinity)
                        .background(
                            agentType == "global"
                                ? Color.black
                                    .opacity(0.4)
                                : Color.black
                                    .opacity(0.2)
                        )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                Divider()

                Button {
                    agentType = "local"
                } label: {
                    Text("Stdio Server")
                        .font(.system(size: 12, weight: .medium))
                        .frame(height: 32)
                        .frame(maxWidth: .infinity)
                        .background(
                            agentType == "local"
                                ? Color.black
                                    .opacity(0.4)
                                : Color.black
                                    .opacity(0.2)
                        )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
            .background(Color.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.bottom, 8)

            HStack {
                Text("Name")
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 100, alignment: .leading)
                TextField("Agent Name", text: $agentName)
                    .padding(.horizontal, 8)
                    .frame(height: 32)
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .font(.system(size: 12, weight: .medium))
                    .textFieldStyle(.plain)
            }
            .padding(.bottom, 8)

            HStack {
                Text(agentType == "local" ? "Command" : "URL")
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 100, alignment: .leading)
                TextField(
                    agentType == "local"
                        ? "/full/path/to/your/command" : "https://example.com/mcp",
                    text: $agentPrimary
                )
                .padding(.horizontal, 8)
                .frame(height: 32)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .font(.system(size: 12, weight: .medium))
                .textFieldStyle(.plain)
            }
            .padding(.bottom, 8)

            if agentType == "local" {
                HStack {
                    Text("Arguments (Optional)")
                        .font(.system(size: 10, weight: .medium))
                        .frame(width: 100, alignment: .leading)
                    TextField(
                        "some --arguments \"go here\"",
                        text: $agentSecondary
                    )
                    .padding(.horizontal, 8)
                    .frame(height: 32)
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .font(.system(size: 12, weight: .medium))
                    .textFieldStyle(.plain)
                }
                .padding(.bottom, 8)
            } else {
                HStack {
                    Text("Auth Token (Optional)")
                        .font(.system(size: 10, weight: .medium))
                        .frame(width: 100, alignment: .leading)
                    TextField(
                        "ghp_xYz....",
                        text: $agentSecondary
                    )
                    .padding(.horizontal, 8)
                    .frame(height: 32)
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .font(.system(size: 12, weight: .medium))
                    .textFieldStyle(.plain)
                }
                .padding(.bottom, 8)
            }

        }
        .padding(4)
    }
}
