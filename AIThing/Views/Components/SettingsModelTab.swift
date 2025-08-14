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
                GroupBox(label: title("Use Managed Models")) {
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

                GroupBox(label: title("Use Own API Key")) {
                    VStack(alignment: .leading) {
                        ForEach(Array(byokModels.enumerated()), id: \.offset) { idx, info in
                            VStack(alignment: .leading, spacing: 4) {
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
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(4)
                }

                GroupBox(label: title("Custom Models")) {
                    HStack {
                        Text("Enterprise Plan Required").font(.system(size: 14, weight: .medium))
                        Spacer()
                    }
                    .padding(4)
                    .opacity(0.5)
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
                if showDetails {
                    Text(info.provider)
                        .font(.system(size: 10, weight: .medium))
                        .opacity(0.5)
                }
                Text(info.title)
                    .font(.system(size: 14, weight: .medium))
                if showDetails {
                    Text(info.ratings.shortText)
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

    private func title(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .medium)).padding(.vertical, 4)
    }
}
