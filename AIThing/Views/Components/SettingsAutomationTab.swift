//
//  SettingsAutomationTab.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 11/9/25.
//

import SwiftUI

struct SettingsAutomationTab: View {
    @EnvironmentObject var automationManager: AutomationManager

    var body: some View {
//        VStack(alignment: .leading, spacing: 16) {
//            GroupBox(
//                label: Text("Recurring Automations")
//                    .font(.system(size: 10, weight: .medium))
//                    .padding(.bottom, 4)
//            ) {
//                VStack(alignment: .leading) {
//                    Text(
//                        """
//                        Learn what you can do with [Managed Agents](https://aithing.dev/features/multiple-agents#managed-agents).
//                        """
//                    )
//                    .font(.system(size: 10, weight: .medium))
//                    .padding(.vertical, 4)
//                    .foregroundStyle(.secondary)
//
//                    GroupBox {
//                        GoogleManagedAgentRow(
//                            icon: "google",
//                            title: "Google Workspace",
//                            subheading: $googleAgentAccount,
//                        )
//                        .environmentObject(googleOAuthManager)
//                        Divider()
//                        GithubManagedAgentRow(
//                            icon: "github",
//                            title: "GitHub",
//                            subheading: $githubAgentAccount,
//                        )
//                        .environmentObject(gitHubOAuthManager)
//                    }
//
//                    GroupBox {
//                        VStack(alignment: .leading) {
//                            ForEach(
//                                mcpOAuthManagers.managers.keys.sorted { lhs, rhs in
//                                    let lhsEnabled =
//                                        mcpOAuthManagers.managers[lhs]?.enabled ?? false
//                                    let rhsEnabled =
//                                        mcpOAuthManagers.managers[rhs]?.enabled ?? false
//                                    if lhsEnabled != rhsEnabled {
//                                        // enabled managers come first
//                                        return lhsEnabled && !rhsEnabled
//                                    } else {
//                                        // if both are enabled or both disabled, sort by key
//                                        return lhs < rhs
//                                    }
//                                },
//                                id: \.self
//                            ) { manager in
//                                if let agent = mcpOAuthManagers.managers[manager] {
//                                    ManagedAgentRow(
//                                        icon: agent.server.image,
//                                        title: agent.server.name
//                                    )
//                                    .environmentObject(agent)
//                                    Divider()
//                                }
//                            }
//
//                            Text(
//                                "Request more managed agents via help@aithing.dev."
//                            )
//                            .font(.system(size: 10, weight: .medium))
//                            .padding(4)
//                            .foregroundStyle(.secondary)
//                        }
//                    }
//
//                    Text(
//                        """
//                        Need help? Visit the [Troubleshooting](https://aithing.dev/errors/agent-troubleshooting) page.
//                        Request more Managed Agents via help@aithing.dev.
//                        """
//                    )
//                    .font(.system(size: 10, weight: .medium))
//                    .padding(.vertical, 4)
//                    .foregroundStyle(.secondary)
//                }
//                .padding(4)
//            }
//
//            .onAppear {
//                Task {
//                    if googleOAuthManager.enabled.count > 0 {
//                        if let user = googleOAuthManager.user {
//                            googleAgentAccount = user.profile?.name ?? ""
//                        }
//                    }
//                    if gitHubOAuthManager.enabled.count > 0 {
//                        if let user = gitHubOAuthManager.user {
//                            githubAgentAccount = user.name ?? ""
//                        }
//                    }
//                }
//            }
//
//            GroupBox(
//                label: Text("Own Agents (Max \(agentMaxCount))")
//                    .font(.system(size: 10, weight: .medium))
//                    .padding(.bottom, 4)
//            ) {
//                VStack(alignment: .leading) {
//                    GroupBox {
//                        ForEach(agents) { agent in
//                            AgentRow(
//                                agent: agent,
//                                toggle: { newValue in
//                                    if let idx = agents.firstIndex(of: agent) {
//                                        agents[idx].isEnabled = newValue
//                                        saveAgents()
//                                    }
//                                },
//                                delete: { deleteAgent(agent) }
//                            )
//                            Divider()
//                        }
//
//                        Text(
//                            """
//                            Learn more about adding your [own agents](https://aithing.dev/features/multiple-agents#add-your-own-agents).
//                            """
//                        )
//                        .font(.system(size: 10, weight: .medium))
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                        .foregroundStyle(.secondary)
//                        .padding(4)
//                    }
//
//                    if agents.count < agentMaxCount {
//                        GroupBox {
//                            VStack(alignment: .leading, spacing: 0) {
//                                AddAgentForm(
//                                    agentType: $agentType,
//                                    agentName: $agentName,
//                                    agentPrimary: $agentPrimary,
//                                    agentSecondary: $agentSecondary
//                                )
//
//                                Button {
//                                    showToast = false
//                                    if agents.count < agentMaxCount {
//                                        let error = addAgentEntry(
//                                            agentType,
//                                            agentName,
//                                            agentPrimary,
//                                            agentSecondary
//                                        )
//                                        if !error.isEmpty {
//                                            toastText = error
//                                            showToast = true
//                                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
//                                                showToast = false
//                                                toastText = ""
//                                            }
//                                        }
//                                    } else {
//                                        toastText =
//                                            "Maximum of \(agentMaxCount) agents allowed."
//                                        showToast = true
//                                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
//                                            showToast = false
//                                            toastText = ""
//                                        }
//                                    }
//                                } label: {
//                                    Text("+ Add Agent")
//                                        .font(.system(size: 12, weight: .medium))
//                                        .frame(maxWidth: .infinity)
//                                        .frame(height: 24)
//                                        .padding(.horizontal, 12)
//                                        .background(Color.black.opacity(0.2))
//                                        .clipShape(RoundedRectangle(cornerRadius: 4))
//                                }
//                                .buttonStyle(.plain)
//                                .padding(4)
//
//                                if showToast {
//                                    Text(toastText)
//                                        .foregroundStyle(.red)
//                                        .font(.system(size: 10, weight: .medium))
//                                        .padding(4)
//                                }
//                            }
//                        }
//
//                    }
//                }
//                .padding(4)
//            }
//
//        }
//        .frame(maxWidth: .infinity, alignment: .leading)
//
        VStack {
            ForEach(automationManager.listAutomations()) { automation in
                VStack(alignment: .leading, spacing: 4) {
                    Text(automation.title)
                        .font(.headline)
                    Text(automation.instructions)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Text("Executes: \(automation.executeTime, style: .time)")
                        if !automation.recurrence.isOneOff {
                            Text("• Recurs every: \(recurrenceString(automation.recurrence))")
                        } else {
                            Text("• One-time")
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(.blue)
                }
                .padding(.vertical, 4)
                .onTapGesture {
                    //                    for index in indexSet {
                    //                        let automation = automationManager.listAutomations()[index]
                    //                        automationManager.removeAutomation(id: automation.id)
                    //                    }
                }
            }
            //                .onDelete { indexSet in
            //                    for index in indexSet {
            //                        let automation = automationManager.listAutomations()[index]
            //                        automationManager.removeAutomation(id: automation.id)
            //                    }
            //                }
            Button("Add Sample") {
                addSampleAutomation()
            }
        }
    }

    private func addSampleAutomation() {
        let id = UUID().uuidString
        let executeTime = Date().addingTimeInterval(5)  // 5 seconds from now

        automationManager.createAutomation(
            id: id,
            title: "Sample Task",
            instructions: "This is a test automation for id \(id)",
            executeTime: executeTime,
            recurrence: .init(minutes: 1, hours: 0, days: 0),  // Daily
            enabled: true
        )
    }

    private func recurrenceString(_ recurrence: Automation.Recurrence) -> String {
        var parts: [String] = []
        if recurrence.days > 0 {
            parts.append("\(recurrence.days) day\(recurrence.days == 1 ? "" : "s")")
        }
        if recurrence.hours > 0 {
            parts.append("\(recurrence.hours) hour\(recurrence.hours == 1 ? "" : "s")")
        }
        if recurrence.minutes > 0 {
            parts.append("\(recurrence.minutes) min\(recurrence.minutes == 1 ? "" : "s")")
        }
        return parts.joined(separator: ", ")
    }

    //    var body: some View {
    //        VStack(alignment: .leading, spacing: 16) {
    //            GroupBox(label: title("Recurring Automations")) {
    //                VStack(alignment: .leading, spacing: 8) {
    //                    Text("Create tasks that run automatically at regular intervals.")
    //                        .font(.system(size: 14, weight: .medium))
    //                    Text(
    //                        "Coming Soon. Stay tuned!"
    //                    )
    //                    .font(.system(size: 10, weight: .medium))
    //                    .foregroundStyle(.secondary)
    //                }
    //                .padding(4)
    //            }
    //            .fixedSize(horizontal: false, vertical: false)
    //
    //            GroupBox(label: title("One-off Automations")) {
    //                VStack(alignment: .leading, spacing: 8) {
    //                    Text("Create tasks that automate your workflows once, either at a specific time or on demand.")
    //                        .font(.system(size: 14, weight: .medium))
    //                    Text(
    //                        "Coming Soon. Stay tuned!"
    //                    )
    //                    .font(.system(size: 10, weight: .medium))
    //                    .foregroundStyle(.secondary)
    //                }
    //                .padding(4)
    //            }
    //            .fixedSize(horizontal: false, vertical: false)
    //
    //        }
    //        .frame(maxWidth: .infinity, alignment: .leading)
    //    }
    //
    //    private func title(_ text: String) -> some View {
    //        Text(text).font(.system(size: 10, weight: .medium)).padding(.bottom, 4)
    //    }
}

private struct AddAgentForm: View {
    @Binding var agentType: String
    @Binding var agentName: String
    @Binding var agentPrimary: String
    @Binding var agentSecondary: String

    var body: some View {

        VStack(alignment: .leading) {
            HStack(spacing: 0) {
                Button {
                    agentType = "global"
                } label: {
                    Text("Global")
                        .font(.system(size: 12, weight: .medium))
                        .frame(height: 24)
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
                    Text("Local")
                        .font(.system(size: 12, weight: .medium))
                        .frame(height: 24)
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
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .padding(.bottom, 8)

            HStack {
                Text("Name")
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 100, alignment: .leading)
                TextField("Agent Name", text: $agentName)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
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
                .frame(height: 24)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 4))
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
                    .frame(height: 24)
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
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
                    .frame(height: 24)
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .font(.system(size: 12, weight: .medium))
                    .textFieldStyle(.plain)
                }
                .padding(.bottom, 8)
            }

        }
        .padding(4)
    }
}
