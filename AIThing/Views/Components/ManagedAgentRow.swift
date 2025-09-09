//
//  GoogleManagedAgentRow.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/28/25.
//

import SwiftUI
import os

struct NotionManagedAgentRow: View {
    @EnvironmentObject var manager: NotionOAuthManager
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
                                                print("Notion: Enabling \(tool)")
                                                print("Notion: Tools: \(manager.enabled)")
                                                if let user = await manager.generateToken(
                                                    refresh: false
                                                ) {
                                                    subheading = user.name ?? ""
                                                } else {
                                                    manager.enabled.remove(tool)
                                                }
                                            } else {
                                                manager.enabled.remove(tool)
                                                print("Notion: Disabling \(tool)")
                                                print("Notion: Tools: \(manager.enabled)")
                                                if manager.enabled.count == 0 {
                                                    print("Notion: Resetting token")
                                                    manager.resetToken()
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

struct GithubManagedAgentRow: View {
    @EnvironmentObject var manager: GithubOAuthManager
    let icon: String
    let title: String
    @Binding var subheading: String
    @State private var exapanded = false

    // private static let logger = Logger(subsystem: "com.thisisnsh.mac.AIThing", category: "GoogleManagedAgentRow")

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
                                                print("Github: Enabling \(tool)")
                                                print("Github: Tools: \(manager.enabled)")
                                                if let user = await manager.generateToken(
                                                    refresh: false
                                                ) {
                                                    subheading = user.name ?? ""
                                                } else {
                                                    manager.enabled.remove(tool)
                                                }
                                            } else {
                                                manager.enabled.remove(tool)
                                                print("Github: Disabling \(tool)")
                                                print("Github: Tools: \(manager.enabled)")
                                                if manager.enabled.count == 0 {
                                                    print("Github: Resetting token")
                                                    manager.resetToken()
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

struct GoogleManagedAgentRow: View {
    @EnvironmentObject var manager: GoogleOAuthManager
    let icon: String
    let title: String
    @Binding var subheading: String
    @State private var exapanded = false

    // private static let logger = Logger(subsystem: "com.thisisnsh.mac.AIThing", category: "GoogleManagedAgentRow")

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
                                                print("Google: Enabling \(tool)")
                                                print("Google: Tools: \(manager.enabled)")
                                                if let user = await manager.generateToken(
                                                    refresh: false
                                                ) {
                                                    subheading = user.profile?.name ?? ""
                                                } else {
                                                    manager.enabled.remove(tool)
                                                }
                                            } else {
                                                manager.enabled.remove(tool)
                                                print("Google: Disabling \(tool)")
                                                print("Google: Tools: \(manager.enabled)")
                                                if manager.enabled.count == 0 {
                                                    print("Google: Resetting token")
                                                    manager.resetToken()
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

struct ManagedAgentRow: View {
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

struct AgentRow: View {
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

func RowTitle(_ text: String) -> some View {
    Text(text).font(.system(size: 14, weight: .medium))
}
func RowSub(_ text: String) -> some View {
    Text(text).font(.system(size: 10, weight: .medium)).opacity(0.5)
}
