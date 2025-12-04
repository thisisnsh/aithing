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
    var blocked: Bool
    var usageData: Usage?
}
