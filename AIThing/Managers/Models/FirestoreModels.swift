//
//  FirestoreModels.swift
//  AIThing
//
//  Models for Firestore data.
//

import Foundation

struct Usage: Codable {
    var query: Int = 0
    var agentUse: Int = 0
    var filesAttached: Int = 0
}

struct Profile: Codable {
    var id: String
    var name: String?
    var email: String
    var creditsTotal: Int
    var creditsUsed: Int
    var blocked: Bool
    var apiKeyAnthropic: String
    var apiKeyOpenAI: String
    var usageData: Usage?
}

struct PlanDetail: Codable {
    var credits: Int
}

struct PlanOrder: Codable {
    var id: String
    var planId: String
    var endDate: Date
}

