//
//  AgentRows.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/28/25.
//

import SwiftUI
import os

// MARK: - MCP Agent Row

struct ManagedAgentRow: View {
    // MARK: - Environment Objects
    @EnvironmentObject var manager: MCPAuthManager

    // MARK: - Constants
    let title: String

    // MARK: - Body
    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    RowTitle(title)
                }
                Spacer()
                Toggle(
                    "",
                    isOn: Binding(
                        get: { manager.enabled },
                        set: { newValue in
                            Task {
                                if newValue {
                                    manager.enabled = true
                                    logger.info("Enabling: \(title)")
                                    if await manager.generateToken(
                                        refresh: false
                                    ) == nil {
                                        manager.enabled = false
                                        logger.debug("Disabling: \(title)")
                                    }
                                } else {
                                    manager.enabled = false
                                    logger.debug("Disabling: \(title)")
                                    manager.resetToken()
                                }
                                setMcpEnabled(
                                    value: manager.enabled,
                                    clientName: manager.server.id ?? ""
                                )
                            }
                        }
                    )
                )
                .toggleStyle(.switch)
                .tint(.black)
                .scaleEffect(0.7)
            }
        }
        .padding(4)
    }
}

// MARK: - GitHub Agent Row

struct GithubManagedAgentRow: View {
    // MARK: - Environment Objects
    @EnvironmentObject var manager: GithubAuthManager
    @EnvironmentObject var mcpAuthManagers: MCPAuthManagers

    // MARK: - Bindings
    @Binding var subheading: String

    // MARK: - Constants
    let title: String

    // MARK: - State
    @State var exapanded = false

    // MARK: - Computed Properties
    var enabled: Bool {
        if let server = mcpAuthManagers.customManagers["managed_aithing_github"] {
            return server.enabled ?? false
        }
        return false
    }

    // MARK: - Body
    var body: some View {
        VStack {
            Button {
                if enabled {
                    exapanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        RowTitle(title)
                        if !subheading.isEmpty {
                            RowSub(subheading)
                        }
                    }
                    Spacer()
                    if enabled {
                        Image(systemName: "chevron.right")
                            .frame(width: 10, height: 10)
                    } else {
                        RowSub("Disabled")
                    }
                }
            }
            .buttonStyle(.plain)

            if exapanded {
                ForEach(
                    GithubToolModels.toolScopesMap.keys.sorted(by: { $0.rawValue < $1.rawValue }),
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
                                    get: { manager.enabled.contains(tool) },
                                    set: { newValue in
                                        Task {
                                            if newValue {
                                                manager.enabled.insert(tool)
                                                logger.info("Github: Enabling \(tool.rawValue)")
                                                logger.debug("Github: Tools: \(manager.enabled)")
                                                if let user = await manager.generateToken(
                                                    refresh: false
                                                ) {
                                                    subheading = user.name ?? ""
                                                } else {
                                                    manager.enabled.remove(tool)
                                                }
                                            } else {
                                                manager.enabled.remove(tool)
                                                logger.info("Github: Disabling \(tool.rawValue)")
                                                logger.debug("Github: Tools: \(manager.enabled)")
                                                if manager.enabled.count == 0 {
                                                    logger.debug("Github: Resetting token")
                                                    manager.resetToken()
                                                }
                                            }
                                            setGithubTools(value: manager.enabled)
                                        }
                                    }
                                )
                            )
                            .toggleStyle(.switch)
                            .tint(.black)
                            .scaleEffect(0.7)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
        .padding(4)
    }
}

// MARK: - Google Agent Row

struct GoogleManagedAgentRow: View {
    // MARK: - Environment Objects
    @EnvironmentObject var manager: GoogleAuthManager
    @EnvironmentObject var mcpAuthManagers: MCPAuthManagers

    // MARK: - Bindings
    @Binding var subheading: String

    // MARK: - Constants
    let title: String

    // MARK: - State
    @State var exapanded = false

    // MARK: - Computed Properties
    var enabled: Bool {
        if let server = mcpAuthManagers.customManagers["managed_aithing_google"] {
            return server.enabled ?? false
        }
        return false
    }

    // MARK: - Body
    var body: some View {
        VStack {
            Button {
                if enabled {
                    exapanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        RowTitle(title)
                        if !subheading.isEmpty {
                            RowSub(subheading)
                        }
                    }
                    Spacer()
                    if enabled {
                        Image(systemName: "chevron.right")
                            .frame(width: 10, height: 10)
                    } else {
                        RowSub("Disabled")
                    }
                }
            }
            .buttonStyle(.plain)

            if exapanded {
                ForEach(
                    GoogleToolModels.toolScopesMap.keys.sorted(by: { $0.rawValue < $1.rawValue }),
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
                                    get: { manager.enabled.contains(tool) },
                                    set: { newValue in
                                        Task {
                                            if newValue {
                                                manager.enabled.insert(tool)
                                                logger.info("Google: Enabling \(tool.rawValue)")
                                                logger.debug("Google: Tools: \(manager.enabled)")
                                                if let user = await manager.generateToken(
                                                    refresh: false
                                                ) {
                                                    subheading = user.profile?.name ?? ""
                                                } else {
                                                    manager.enabled.remove(tool)
                                                }
                                            } else {
                                                manager.enabled.remove(tool)
                                                logger.info("Google: Disabling \(tool.rawValue)")
                                                logger.debug("Google: Tools: \(manager.enabled)")
                                                if manager.enabled.count == 0 {
                                                    logger.debug("Google: Resetting token")
                                                    manager.resetToken()
                                                }
                                            }
                                            setGoogleTools(value: manager.enabled)
                                        }
                                    }
                                )
                            )
                            .toggleStyle(.switch)
                            .tint(.black)
                            .scaleEffect(0.7)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
        .padding(4)
    }
}

// MARK: - Custom Agent Row

struct AgentRow: View {
    // MARK: - Constants & Closures
    let agent: AgentEntry
    let toggle: (Bool) -> Void
    let delete: () -> Void

    // MARK: - State
    @State var isHovered = false

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    switch agent.entry {
                    case .url(let name, let url):
                        RowTitle(name)
                        RowSub("URL: \(url)")
                    case .urlWithToken(let name, let url, let token):
                        RowTitle(name)
                        RowSub("URL: \(url)\nToken: \(token.prefix(4))...\(token.suffix(4))")
                    case .command(let name, let command, let arguments):
                        RowTitle(name)
                        RowSub(
                            "Command: \(command)\nArguments: [\(arguments.joined(separator: " "))]"
                        )
                    }
                }

                Spacer()

                Toggle("", isOn: .init(get: { agent.isEnabled }, set: toggle))
                    .toggleStyle(.switch)
                    .tint(.black)
                    .scaleEffect(0.7)
            }

            if isHovered {
                Button(action: delete) {
                    Text("Remove")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(4)
        .contentShape(Rectangle())
        .onHover { hover in
            withAnimation {
                isHovered = hover
            }
        }
    }
}

// MARK: - Helper Functions

func RowTitle(_ text: String) -> some View {
    Text(text).font(.system(size: 14, weight: .medium))
}

func RowSub(_ text: String) -> some View {
    Text(text).font(.system(size: 10, weight: .medium)).opacity(0.5)
}

