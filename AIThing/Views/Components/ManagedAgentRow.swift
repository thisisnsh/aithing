//
//  GoogleManagedAgentRow.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/28/25.
//

import SwiftUI
import os

struct ManagedAgentRow: View {
    @EnvironmentObject var manager: McpOAuthManager
    let icon: String?
    let title: String

    var body: some View {
        VStack {
            HStack {
                if let icon = icon {
                    AsyncImage(url: URL(string: icon)) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        Image(systemName: "circle.hexagongrid")
                            .resizable()
                            .scaledToFit()
                    }
                    .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "circle.hexagongrid")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                }
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
                                    logger.debug("\(title): Enabling")
                                    if await manager.generateToken(
                                        refresh: false
                                    ) == nil {                                    
                                        manager.enabled = false
                                    }
                                } else {
                                    manager.enabled = false
                                    logger.debug("\(title): Disabling")
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

struct GithubManagedAgentRow: View {
    @EnvironmentObject var manager: GithubOAuthManager
    @EnvironmentObject var mcpOAuthManagers: McpOAuthManagers
    let icon: String
    let title: String
    @Binding var subheading: String
    @State private var exapanded = false

    var enabled: Bool {
        if let server = mcpOAuthManagers.customManagers["managed_aithing_github"] {
            return server.enabled ?? false
        }
        return false
    }

    var body: some View {
        VStack {
            Button {
                if enabled {
                    exapanded.toggle()
                }
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
                    manager.toolScopesMap.keys.sorted(by: { $0.rawValue < $1.rawValue }),
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
                                                logger.debug("Github: Enabling \(tool.rawValue)")
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
                                                logger.debug("Github: Disabling \(tool.rawValue)")
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

struct GoogleManagedAgentRow: View {
    @EnvironmentObject var manager: GoogleOAuthManager
    @EnvironmentObject var mcpOAuthManagers: McpOAuthManagers
    let icon: String
    let title: String
    @Binding var subheading: String
    @State private var exapanded = false

    var enabled: Bool {
        if let server = mcpOAuthManagers.customManagers["managed_aithing_google"] {
            return server.enabled ?? false
        }
        return false
    }

    var body: some View {
        VStack {
            Button {
                if enabled {
                    exapanded.toggle()
                }
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
                    manager.toolScopesMap.keys.sorted(by: { $0.rawValue < $1.rawValue }),
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
                                                logger.debug("Google: Enabling \(tool.rawValue)")
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
                                                logger.debug("Google: Disabling \(tool.rawValue)")
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

struct AgentRow: View {
    let agent: AgentEntry
    let toggle: (Bool) -> Void
    let delete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center) {
            if isHovered {
                Button(action: delete) { Image(systemName: "trash.fill") }
                    .clipShape(Circle())

            }

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
                    RowSub("Command: \(command)\nArguments: [\(arguments.joined(separator: " "))]")
                }
            }

            Spacer()

            Toggle("", isOn: .init(get: { agent.isEnabled }, set: toggle))
                .toggleStyle(.switch)
                .tint(.black)
                .scaleEffect(0.7)
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

func RowTitle(_ text: String) -> some View {
    Text(text).font(.system(size: 14, weight: .medium))
}
func RowSub(_ text: String) -> some View {
    Text(text).font(.system(size: 10, weight: .medium)).opacity(0.5)
}
