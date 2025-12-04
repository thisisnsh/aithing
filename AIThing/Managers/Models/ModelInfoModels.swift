//
//  ModelInfoModels.swift
//  AIThing
//
//  Models for AI model information.
//

import Foundation

// MARK: - AI Provider

/// Represents the AI provider for a model.
enum AIProvider: String, Codable, CaseIterable {
    case anthropic
    case openai
    case gemini    

    /// Display name for the provider.
    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openai: return "OpenAI"
        case .gemini: return "Google"
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
