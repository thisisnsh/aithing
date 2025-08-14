//
//  SettingsModelTab.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/13/25.
//

import SwiftUI

struct SettingsModelTab: View {
    let managedModels: [ModelInfo]
    let byokModels: [ModelInfo]

    @Binding var modelSelected: ModelName
    @Binding var apiKey: String
    @FocusState var apiKeyFieldFocused: Bool

    let saveModels: () -> Void
    let bindingForModel: (Binding<ModelName>, ModelName) -> Binding<Bool>

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { apiKeyFieldFocused = false }

            VStack(alignment: .leading, spacing: 16) {
                GroupBox(
                    label: title(
                        "Use Managed Models",
                        note: "Using these models will deduct credits from your AI Thing account."
                    )
                ) {
                    VStack(alignment: .leading) {
                        ForEach(Array(managedModels.enumerated()), id: \.offset) { idx, info in
                            modelRow(info, showDetails: modelSelected == info.id)
                            if idx < managedModels.count - 1 { Divider() }
                        }

                        Divider()

                        HStack {
                            Image("openai").resizable().frame(width: 16, height: 16)
                            Text("OpenAI: GPT-5").font(.system(size: 14, weight: .medium))
                            Spacer()
                            Text("Coming Soon").font(.system(size: 10, weight: .medium))
                        }
                        .padding(4)
                        .opacity(0.5)
                    }
                    .padding(4)
                }

                GroupBox(
                    label: title(
                        "Use Own API Key",
                        note:
                            "You will need to purchase credits at https://console.anthropic.com/settings/billing, and those credits will be used. Using these models will not deduct credits from your AI Thing account."
                    )
                ) {
                    VStack(alignment: .leading) {
                        ForEach(Array(byokModels.enumerated()), id: \.offset) { idx, info in
                            VStack(alignment: .leading) {
                                modelRow(info, showDetails: modelSelected == info.id)
                                if modelSelected == info.id {
                                    TextField("sk-ant-...", text: $apiKey, onCommit: saveModels)
                                        .padding(.horizontal, 8)
                                        .frame(height: 32)
                                        .background(Color.black.opacity(0.2))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .font(.system(size: 14, weight: .medium))
                                        .focused($apiKeyFieldFocused)
                                        .textFieldStyle(.plain)
                                        .padding(.bottom, 4)
                                }
                                if idx < byokModels.count - 1 { Divider() }
                            }
                        }
                    }
                    .padding(4)
                }

                GroupBox(
                    label: title(
                        "Custom Models",
                        note:
                            "Using these models will not deduct any credits from your AI Thing account."
                    )
                ) {
                    HStack {
                        Text("Enterprise Plan Required").font(.system(size: 14, weight: .medium))
                            .opacity(0.5)
                        Spacer()
                        Button {
                            // todo something
                        } label: {
                            Text("Contact Us")
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
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Row

    private func modelRow(_ info: ModelInfo, showDetails: Bool) -> some View {
        HStack(spacing: 8) {
            if let icon = info.iconName {
                Image(icon).resizable().frame(width: 16, height: 16)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(info.title).font(.system(size: 14, weight: .medium))
                    if info.cost > 0 {
                        Text("Cost: \(info.cost) Credit\(info.cost > 1 ? "s" : "") / Query")
                            .font(.system(size: 10, weight: .medium))
                            .opacity(0.5)
                    }
                }
                if showDetails {
                    Text(info.description)
                        .font(.system(size: 10, weight: .medium))
                        .opacity(0.5)
                }
            }
            Spacer()
            Toggle(
                "",
                isOn: bindingForModel($modelSelected, info.id)
            )
            .toggleStyle(.switch)
            .tint(.black)
            .scaleEffect(0.7)
        }
        .padding(4)
        .contentShape(Rectangle())
        .onTapGesture { modelSelected = info.id }
    }

    private func title(_ text: String, note: String) -> some View {
        VStack(alignment: .leading) {
            Text(text).font(.system(size: 10, weight: .medium)).padding(.top, 4)
            Text(note).font(.system(size: 10, weight: .medium)).padding(.bottom, 4).opacity(0.5)
                .textSelection(.enabled)
        }
        .textSelection(.enabled)
    }
}
