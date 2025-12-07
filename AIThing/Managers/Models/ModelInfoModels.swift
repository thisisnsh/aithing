//
//  ModelInfoModels.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 12/5/25.
//

import Foundation

// MARK: - AI Provider

/// Represents the AI provider for a model.
enum AIProvider: String, Codable, CaseIterable {
    case anthropic
    case openai
    case google    

    /// Display name for the provider.
    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openai: return "OpenAI"
        case .google: return "Google"
        }
    }
}

// MARK: - Model Info

/// Represents an AI model's configuration.
struct ModelInfo: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let provider: AIProvider
}

// MARK: - Helper Functions

/// Gets the provider for a model.
func getModelProvider(_ modelId: String, all allModels: [ModelInfo]) -> AIProvider? {
    allModels.first(where: { $0.id == modelId })?.provider
}
