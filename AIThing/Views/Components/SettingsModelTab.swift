//
//  SettingsModelTab.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/13/25.
//

import SwiftUI

struct SettingsModelTab: View {
    let managedModels: [ModelInfo]

    @Binding var modelSelected: String
    @Binding var apiKey: String
    @FocusState var apiKeyFieldFocused: Bool

    let saveModels: () -> Void
    let bindingForModel: (Binding<String>, String) -> Binding<Bool>

    private var icon: String {
        getModelIcon(modelSelected, all: managedModels)
    }
    private var title: String {
        getModelTitle(modelSelected, all: managedModels)
    }
    private var rating: String {
        getModelRating(modelSelected, all: managedModels)
    }
    private var cost: Int {
        getModelCost(modelSelected, all: managedModels)
    }
    private var costImage: Int {
        getModelCostImage(modelSelected, all: managedModels)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { apiKeyFieldFocused = false }

            VStack(alignment: .leading, spacing: 16) {
                GroupBox(
                    label: title("Chosen Model")
                ) {
                    VStack(alignment: .leading) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Image(icon)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 16, height: 16)

                                    Text(title)
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .padding(.bottom, 4)

                                Text(rating)
                                    .font(.system(size: 10, weight: .medium))
                                    .opacity(0.5)
                            }
                            Spacer()

                            Text(
                                """
                                Billed by [Anthropic](https://console.anthropic.com/settings/billing) 
                                """
                            )
                            .font(.system(size: 10, weight: .medium))
                            .multilineTextAlignment(.trailing)
                        }
                        .padding(4)
                    }
                    .padding(4)
                }

                GroupBox(
                    label: title("Managed Models")
                ) {
                    VStack(alignment: .leading) {
                        ForEach(Array(managedModels.enumerated()), id: \.offset) { idx, info in
                            modelRow(info, showDetails: modelSelected == info.id)
                            if idx < managedModels.count - 1 { Divider() }
                        }
                    }
                    .padding(4)
                }

                Text("AI can make mistakes. Perform irreversible tasks carefully.")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 12)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                GroupBox {
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "key.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                            Text("API Key").font(.system(size: 14, weight: .medium))
                            Spacer()
                        }
                        .padding(4)
                        .contentShape(Rectangle())

                        TextField("sk-ant-...", text: $apiKey, onCommit: saveModels)
                            .padding(.horizontal, 8)
                            .frame(height: 32)
                            .background(Color.black.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .font(.system(size: 14, weight: .medium))
                            .focused($apiKeyFieldFocused)
                            .textFieldStyle(.plain)
                            .padding(.bottom, 4)

                        Text(
                            "You will need to purchase credits at [Anthropic](https://console.anthropic.com/settings/billing)."
                            // Using own key will not deduct credits from your AI Thing account.
                        )
                        .font(.system(size: 10, weight: .medium))
                        .padding(4)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(4)
                }

            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func modelRow(_ info: ModelInfo, showDetails: Bool) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(info.description).font(.system(size: 14, weight: .medium))
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
        VStack(alignment: .leading) {
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .padding(.bottom, 4)
        }
        .textSelection(.enabled)
    }
}
