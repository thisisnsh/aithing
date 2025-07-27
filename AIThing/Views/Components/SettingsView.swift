//
//  SettingsView.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/27/25.
//

import SwiftUI

enum SettingsTab {
    case account, agents
}

struct AgentEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var entry: Entry
    var isEnabled: Bool
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .account
    @State private var apiKey: String =
        UserDefaults.standard.string(forKey: "AnthropicAPIKey") ?? ""
    @State private var agentJsonInput: String = ""
    @State private var agents: [AgentEntry] = getAgentEntries()

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 4) {
                Color.clear.frame(height: 16)
                Button(action: { selectedTab = .account }) {
                    Text("Account")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.leading, 16)
                        .background(
                            .account == selectedTab ? Color.black.opacity(0.5) : Color.clear
                        )
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { selectedTab = .agents }) {
                    Text("Agents")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.leading, 16)
                        .background(
                            .agents == selectedTab ? Color.black.opacity(0.5) : Color.clear
                        )
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()
            }
            .frame(width: 120)
            .background(Color.gray.opacity(0.1))

            Divider()

            // Main Settings Content
            VStack(alignment: .leading, spacing: 16) {
                if selectedTab == .account {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Button("Log in with Google") {}
                                .disabled(true)
                                .frame(height: 32)
                            Text("Coming soon").font(.caption).foregroundColor(.gray)
                        }

                        Divider()

                        Text("Anthropic API Key")
                            .font(.headline)
                        TextField("sk-ant-...", text: $apiKey, onCommit: saveAPIKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 300)
                            .fontDesign(.monospaced)
                    }
                } else if selectedTab == .agents {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add Agent JSON")
                            .padding(.top, 8)
                            .font(.headline)

                        TextEditor(text: $agentJsonInput)
                            .font(.system(size: 13, design: .monospaced))
                            .frame(height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button("Add Agent") {
                            if agents.count < 5 {
                                addAgentEntry()
                            }
                        }

                        Divider()
                            .padding(.top, 8)

                        if agents.count > 0 {
                            Text("Agents (Max 5)")
                                .font(.headline)
                                .padding(.vertical, 8)
                        }

                        ForEach(agents) { agent in
                            HStack {
                                Toggle(
                                    isOn: Binding(
                                        get: { agent.isEnabled },
                                        set: { newValue in
                                            if let index = agents.firstIndex(of: agent) {
                                                agents[index].isEnabled = newValue
                                                saveAgents()
                                            }
                                        }
                                    )
                                ) {
                                    Text(agent.entry.displayString)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()
                                Button(action: {
                                    deleteAgent(agent)
                                }) {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding()
        }
        .onDisappear {
            saveAPIKey()
            saveAgents()
        }
    }

    // MARK: - Agents Handling

    func saveAPIKey() {
        UserDefaults.standard.set(apiKey, forKey: "AnthropicAPIKey")
    }

    func addAgentEntry() {
        let sanitized =
            agentJsonInput
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "’", with: "'")

        guard let data = sanitized.data(using: .utf8),
            let parsed = try? JSONDecoder().decode(Entry.self, from: data)
        else {
            print("Invalid JSON")
            return
        }

        let newAgent = AgentEntry(id: UUID(), entry: parsed, isEnabled: true)
        agents.append(newAgent)
        agentJsonInput = ""
        saveAgents()
    }

    func saveAgents() {
        if let data = try? JSONEncoder().encode(agents) {
            UserDefaults.standard.set(data, forKey: "AgentEntries")
        }
    }

    func deleteAgent(_ agent: AgentEntry) {
        if let index = agents.firstIndex(of: agent) {
            agents.remove(at: index)
            saveAgents()
        }
    }
}
