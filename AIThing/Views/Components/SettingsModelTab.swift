//
//  SettingsModelTab.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/13/25.
//

import SwiftUI

struct ModelInfo: Codable, Identifiable, Equatable {
    let id: String
    // case claude_opus_4_1 = "claude-opus-4-1-20250805"
    // case claude_sonnet_4 = "claude-sonnet-4-20250514"
    // case claude_haiku_3_5 = "claude-3-5-haiku-20241022"

    let provider: String
    let title: String

    let ratings: String
    // let ratings: Ratings

    let description: String
    let iconName: String

    let cost: Int
    let costImage: Int

    let order: Int
}

func getModelTitle(_ model: String, all allModels: [ModelInfo]) -> String {
    allModels.first(where: { $0.id == model })?.title ?? model
}

func getModelCost(_ model: String, all allModels: [ModelInfo]) -> Int {
    allModels.first(where: { $0.id == model })?.cost ?? 1
}

func getModelCostImage(_ model: String, all allModels: [ModelInfo]) -> Int {
    allModels.first(where: { $0.id == model })?.costImage ?? 1
}

func getModelRating(_ model: String, all allModels: [ModelInfo]) -> String {
    allModels.first(where: { $0.id == model })?.ratings ?? "No Ratings"
}

func getModelIcon(_ model: String, all allModels: [ModelInfo]) -> String {
    allModels.first(where: { $0.id == model })?.iconName ?? ""
}

func getCheapestModel(in models: [ModelInfo]) -> ModelInfo? {
    let result = models.min {
        $0.cost == $1.cost
            ? ($0.order == $1.order
                ? $0.title.localizedCompare($1.title) == .orderedAscending
                : $0.order < $1.order)
            : $0.cost < $1.cost
    }
    return result
}

struct Ratings {
    let intelligence: Int
    let speed: Int
    let context: Int

    private func stars(for rating: Int) -> String {
        let filled = String(repeating: "★", count: rating)
        let empty = String(repeating: "", count: max(0, 5 - rating))
        return filled + empty
    }

    var shortText: String {
        "Intelligence: \(stars(for: intelligence))\nOutput Speed: \(stars(for: speed))\nContext Window: \(stars(for: context))"
    }
}

struct SettingsModelTab: View {
    let managedModels: [ModelInfo]

    @Binding var modelSelected: String
    @Binding var byokSelected: Bool
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
                            Image(icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title)
                                    .font(.system(size: 14, weight: .medium))
                                Text(rating)
                                    .font(.system(size: 10, weight: .medium))
                                    .opacity(0.5)
                            }
                            Spacer()
                            if !byokSelected {
                                Text(
                                    """
                                    Cost:
                                    \(cost) Credit\(cost > 1 ? "s" : "") per Query
                                    \(costImage) Credit\(costImage > 1 ? "s" : "") per Image                              
                                    """
                                )
                                .font(.system(size: 10, weight: .medium))
                                .multilineTextAlignment(.trailing)
                            }
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

                GroupBox {
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "key.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                            Text("Use Your Own Key").font(.system(size: 14, weight: .medium))
                            Spacer()
                            Toggle("", isOn: $byokSelected)
                                .toggleStyle(.switch)
                                .tint(.black)
                                .scaleEffect(0.7)

                        }
                        .padding(4)
                        .contentShape(Rectangle())

                        if byokSelected {
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

                        Text(
                            "You will need to purchase credits at https://console.anthropic.com/settings/billing. Using own key will not deduct credits from your AI Thing account."
                        )
                        .font(.system(size: 10, weight: .medium))
                        .padding(4)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(byokSelected ? 1 : 0.5)
                    }
                    .padding(4)
                }

                GroupBox(
                    label: title("Enterprise Models")
                ) {
                    HStack {
                        Text("Enterprise Plan Required").font(.system(size: 14, weight: .medium))
                            .opacity(0.5)
                        Spacer()
                        Link(
                            "Join Waitlist",
                            destination: URL(string: "https://get.aithing.dev/join")!
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
                                    itemID: "join_waitlist_model_hover",
                                    itemName: "join_waitlist_model_hover"
                                )
                            }
                        }
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
