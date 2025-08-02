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
    @Binding var isPresented: Bool
    @State private var selectedTab: SettingsTab = .account
    @State private var apiKey: String =
        UserDefaults.standard.string(forKey: "AnthropicAPIKey") ?? ""
    @State private var agentJsonInput: String = ""
    @State private var agents: [AgentEntry] = getAgentEntries()
    @FocusState private var apiKeyFieldFocused: Bool
    @State private var showToast = false
    @State private var showAddAgent = false

    @State private var agentTypes: [String] = ["Global", "Local"]
    @State private var selectedAgentType = ""

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
            Divider()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if selectedTab == .account {
                        AccountTab()
                    } else if selectedTab == .agents {
                        AgentTab()
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

            Spacer()

            Button(action: {
                //TODO: Help
            }) {
                Text("Help")
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.plain)

            Button(action: {
                //TODO: Quit
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
                    label: Text("Login (Coming Soon)")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.vertical, 4)
                ) {
                    VStack(alignment: .leading) {
                        Button(action: {}) {
                            HStack {
                                Image("google")
                                    .resizable()
                                    .frame(width: 16, height: 16)
                                Text("Google")
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .frame(width: 10, height: 10)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(4)

                        Divider()

                        Button(action: {}) {
                            HStack {
                                Image("github")
                                    .resizable()
                                    .frame(width: 16, height: 16)
                                Text("GitHub")
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .frame(width: 10, height: 10)
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
                                Image(systemName: "chevron.right")
                                    .frame(width: 10, height: 10)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(4)
                    }
                    .padding(4)
                    .opacity(0.5)
                }

                GroupBox(
                    label: Text("Choose the Brain")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.vertical, 4)
                ) {
                    VStack(alignment: .leading) {
                        GroupBox(
                            label: Text("Self Managed")
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
                    Text("Need Help? http://aithing.dev/help")
                        .font(.system(size: 10, weight: .medium))
                        .padding(4)
                    Spacer()
                }
                .padding(4)
            }
            
            if showAddAgent {
                GroupBox(
                    label: Text("Add Agent")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.vertical, 4)
                ) {
                    VStack(alignment: .leading) {
                        TextEditor(text: $agentJsonInput)
                            .padding(8)
                            .frame(height: 80)
                            .background(Color.black.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(.bottom, 4)
                            .font(.system(size: 14, weight: .medium))
                            .textEditorStyle(PlainTextEditorStyle())

                        HStack {
                            Button(action: {
                                showToast = false
                                if agents.count < 3 {  // DEBUG
                                    let rc = addAgentEntry()
                                    if !rc {
                                        showToast = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                            showToast = false
                                        }
                                    }
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
                                Text("Invalid JSON: http://aithing.dev/help")
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(4)
                }
            }

            GroupBox(
                label: Text("Self Managed (Max 3)")
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
                            HStack {
                                Text(agent.entry.displayString)
                                    .font(.system(size: 14, weight: .medium))
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

                    Button(action: {
                        showAddAgent.toggle()
                    }) {
                        Text("+ Add Agents")
                            .font(.system(size: 12, weight: .medium))
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.black.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
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

    // MARK: - Agents Handling

    func saveAPIKey() {
        UserDefaults.standard.set(apiKey, forKey: "AnthropicAPIKey")
    }

    func addAgentEntry() -> Bool {
        agentJsonInput =
            agentJsonInput
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "’", with: "'")

        guard let data = agentJsonInput.data(using: .utf8),
            let parsed = try? JSONDecoder().decode(Entry.self, from: data)
        else {
            print("Invalid JSON")
            return false
        }

        let newAgent = AgentEntry(id: UUID(), entry: parsed, isEnabled: true)
        agents.append(newAgent)
        agentJsonInput = ""
        saveAgents()
        return true
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
