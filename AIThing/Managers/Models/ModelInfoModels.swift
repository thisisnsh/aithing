//
//  ModelInfoModels.swift
//  AIThing
//
//  Models for AI model information.
//

import Foundation

struct ModelInfo: Codable, Identifiable, Equatable {
    let id: String
    
    let provider: String
    let title: String

    let ratings: String

    let description: String
    let iconName: String

    let cost: Int
    let costImage: Int

    let order: Int
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

