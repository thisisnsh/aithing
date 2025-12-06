//
//  ModelTab.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/13/25.
//

import SwiftUI

struct ModelTab: View {
    // MARK: - Bindings
    @Binding var modelSelected: String
    @Binding var apiKeys: APIKeys

    // MARK: - Constants & Closures
    let allModels: [ModelInfo]
    let saveModels: () -> Void
    let bindingForModel: (Binding<String>, String) -> Binding<Bool>

    // MARK: - Focus State
    @FocusState private var anthropicFieldFocused: Bool
    @FocusState private var openAIFieldFocused: Bool
    @FocusState private var googleFieldFocused: Bool

    // MARK: - Computed Properties

    /// Groups models by provider for organized display.
    private var modelsByProvider: [(provider: AIProvider, models: [ModelInfo])] {
        let grouped = Dictionary(grouping: allModels) { $0.provider }
        return AIProvider.allCases.compactMap { provider in
            guard let models = grouped[provider], !models.isEmpty else { return nil }
            return (provider: provider, models: models)
        }
    }

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { clearFocus() }

            VStack(alignment: .leading, spacing: 16) {
                ForEach(modelsByProvider, id: \.provider) { group in
                    GroupBox(
                        label: title(group.provider.displayName)
                    ) {
                        VStack(alignment: .leading) {
                            // Models for this provider
                            ForEach(Array(group.models.enumerated()), id: \.offset) { idx, info in
                                modelRow(info)
                                Divider().padding(.leading, 4)
                            }

                            // API Key
                            apiKeySection(
                                provider: group.provider,
                                apiKey: apiKeyBinding(for: group.provider),
                                isFocused: apiKeyFieldFocused(for: group.provider)
                            )
                        }
                        .padding(4)
                    }
                }

                Text("AI can make mistakes. Perform irreversible tasks carefully.")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 12)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Subviews

    private func apiKeySection(
        provider: AIProvider,
        apiKey: Binding<String>,
        isFocused: FocusState<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("API Key")
                .font(.system(size: 10, weight: .medium))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            TextField(apiKeyPlaceholder(for: provider), text: apiKey, onCommit: saveModels)
                .padding(.horizontal, 8)
                .frame(height: 28)
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .font(.system(size: 14, weight: .medium))
                .focused(isFocused.projectedValue)
                .textFieldStyle(.plain)
                .padding(.horizontal, -8)

            Text(keyInstructions(for: provider))
                .font(.system(size: 10, weight: .medium))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.gray)
        }
        .padding(4)
    }

    private func modelRow(_ info: ModelInfo) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(info.name).font(.system(size: 14, weight: .medium))
                Text(info.id).font(.system(size: 10, weight: .medium)).opacity(0.5)
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
        HStack(alignment: .center) {
            Text(text)
                .font(.system(size: 10, weight: .medium))
        }
        .textSelection(.enabled)
        .padding(.bottom, 4)
    }

    // MARK: - Helpers

    private func apiKeyBinding(for provider: AIProvider) -> Binding<String> {
        Binding(
            get: { apiKeys.key(for: provider) },
            set: { apiKeys = apiKeys.with(key: $0, for: provider) }
        )
    }

    private func apiKeyFieldFocused(for provider: AIProvider) -> FocusState<Bool> {
        switch provider {
        case .anthropic: return _anthropicFieldFocused
        case .openai: return _openAIFieldFocused
        case .google: return _googleFieldFocused
        }
    }

    private func clearFocus() {
        anthropicFieldFocused = false
        openAIFieldFocused = false
        googleFieldFocused = false
    }

    private func billingLink(for provider: AIProvider) -> AttributedString {
        let urlString: String
        switch provider {
        case .anthropic:
            urlString = "https://console.anthropic.com/settings/billing"
        case .openai:
            urlString = "https://platform.openai.com/account/billing"
        case .google:
            urlString = "https://aistudio.google.com/app/billing"
        }
        return try! AttributedString(markdown: "Billed by [\(provider.displayName)](\(urlString))")
    }

    private func apiKeyPlaceholder(for provider: AIProvider) -> String {
        switch provider {
        case .anthropic: return "sk-ant-..."
        case .openai: return "sk-..."
        case .google: return "AIza..."
        }
    }

    func keyInstructions(for provider: AIProvider) -> AttributedString {
        let urlString: String
        switch provider {
        case .anthropic:
            urlString = "https://console.anthropic.com/settings/billing"
        case .openai:
            urlString = "https://platform.openai.com/account/billing"
        case .google:
            urlString = "https://aistudio.google.com/app/billing"
        }
        return try! AttributedString(markdown: "Get your API key at [\(provider.displayName)](\(urlString))")
    }
}
