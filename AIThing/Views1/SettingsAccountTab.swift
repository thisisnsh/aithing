//
//  SettingsAccountTab.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/13/25.
//

import SwiftUI

struct SettingsAccountTab: View {
    let authState: AuthState
    let signIn: () async -> Void
    let signOut: () async -> Void
    let usageData: Usage
    let onHistory: () -> Void

    private let help: [(String, String)] = [
        ("Show / Hide AI Thing", "Control (⌃) + Space"),
        ("Show / Hide Settings", "Control (⌃) + S"),
        ("Show / Hide History", "Control (⌃) + H"),
        ("Open New Tab", "Control (⌃) + N"),
        ("Close Current Tab", "Control (⌃) + W"),
        ("Move to Right Tab", "Control (⌃) + (Right Angular Bracket) >"),
        ("Move to Left Tab", "Control (⌃) + (Left Angular Bracket) <"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox(label: title("Login")) {
                VStack(alignment: .leading) {
                    Button {
                        Task { await signIn() }
                    } label: {
                        HStack {
                            Image("google").resizable().frame(width: 16, height: 16)

                            switch authState {
                            case .signedIn(let user):
                                Text(user.displayName ?? "Logged In")
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                                Button {
                                    Task { await signOut() }
                                } label: {
                                    Text("Log Out").font(.system(size: 10, weight: .medium))
                                }
                                .buttonStyle(.plain)

                            default:
                                Text("Google").font(.system(size: 14, weight: .medium))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .frame(width: 10, height: 10)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(4)

                    Divider()
                    dimmedRow(icon: "apple", text: "Apple", trailing: "Coming Soon")
                    Divider()
                    dimmedRow(icon: "github", text: "GitHub", trailing: "Coming Soon")

                }
                .padding(4)
            }

            GroupBox(label: title("Usage")) {
                HStack(alignment: .bottom) {
                    HStack(alignment: .bottom) {
                        Text("\(usageData.query)")
                            .font(.system(size: 14, weight: .medium))
                        Text(usageData.query > 1 ? "Queries" : "Query")
                            .font(.system(size: 10, weight: .medium))
                            .opacity(0.5)
                    }
                    .padding(4)
                    Spacer()
                    Divider()
                    HStack(alignment: .bottom) {
                        Text("\(usageData.agentUse)")
                            .font(.system(size: 14, weight: .medium))
                        Text(usageData.agentUse > 1 ? "Agent Uses" : "Agent Use")
                            .font(.system(size: 10, weight: .medium))
                            .opacity(0.5)
                    }
                    .padding(4)
                    Spacer()
                    Divider()
                    HStack(alignment: .bottom) {
                        Text("\(usageData.filesAttached)")
                            .font(.system(size: 14, weight: .medium))
                        Text(usageData.filesAttached > 1 ? "Attached Files" : "Attached File")
                            .font(.system(size: 10, weight: .medium))
                            .opacity(0.5)
                    }
                    .padding(4)
                    Spacer()
                }
                .padding(4)
            }

            GroupBox {
                Button {
                    onHistory()
                } label: {
                    HStack {
                        Text("See Conversations").font(.system(size: 14, weight: .medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .frame(width: 10, height: 10)
                    }
                }
                .buttonStyle(.plain)
                .padding(4)
            }
            .padding(.top, -8)

            GroupBox(label: title("Help")) {
                VStack(alignment: .leading) {
                    ForEach(help, id: \.0) { h in
                        HStack {
                            Text(h.0)
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Text(h.1)
                                .font(.system(size: 10, weight: .medium))
                                .opacity(0.5)
                        }
                        .padding(4)
                        Divider()
                    }
                    Text("Still Stuck? Check https://aithing.dev")
                        .font(.system(size: 10, weight: .medium))
                        .padding(4)
                }
                .padding(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // helpers (local to this file)
    private func title(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .medium)).padding(.bottom, 4)
    }

    private func dimmedRow(
        icon: String? = nil,
        systemIcon: String? = nil,
        text: String,
        trailing: String
    ) -> some View {
        HStack {
            if let icon { Image(icon).resizable().frame(width: 16, height: 16) }
            if let systemIcon {
                Image(systemName: systemIcon).resizable().aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
            }
            Text(text).font(.system(size: 14, weight: .medium))
            Spacer()
            Text(trailing).font(.system(size: 10, weight: .medium))
        }
        .padding(4)
        .opacity(0.5)
    }
}
