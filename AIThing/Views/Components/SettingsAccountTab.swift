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
    let creditsUsed: Int
    let creditsTotal: Int
    let onHistory: () -> Void

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
                    dimmedRow(
                        systemIcon: "key.fill",
                        text: "Custom SSO",
                        trailing: "Enterprise Plan Required"
                    )
                }
                .padding(4)
            }

            GroupBox(label: title("Usage")) {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Credits").font(.system(size: 14, weight: .medium))
                        Text("used / total")
                            .font(.system(size: 10, weight: .medium))
                            .opacity(0.5)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                        Spacer()
                        Text("\(creditsUsed) / \(creditsTotal)")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(4)

                    Link(
                        "Get More Credits",
                        destination: URL(string: "https://get.aithing.dev")!
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
                                itemID: "get_more_credits_hover",
                                itemName: "get_more_credits_hover"
                            )
                        }
                    }
                }
                .padding(4)
            }

            GroupBox {
                Button {
                    onHistory()
                } label: {
                    HStack {
                        Text("Per-Conversation Usage").font(.system(size: 14, weight: .medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .frame(width: 10, height: 10)
                    }
                }
                .buttonStyle(.plain)
                .padding(4)
            }
            .padding(.top, -8)

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
                Image(systemName: systemIcon).resizable().aspectRatio(contentMode: .fit).frame(
                    width: 16,
                    height: 16
                )
            }
            Text(text).font(.system(size: 14, weight: .medium))
            Spacer()
            Text(trailing).font(.system(size: 10, weight: .medium))
        }
        .padding(4)
        .opacity(0.5)
    }
}
