//
//  SavedQueryModels.swift
//  AIThing
//
//  Models for saved queries.
//

import Foundation

struct SavedQuery: Identifiable, Decodable, Encodable {
    let id: String
    let title: String
    let instruction: String
}

