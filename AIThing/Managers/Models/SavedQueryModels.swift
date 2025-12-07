//
//  SavedQueryModels.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 12/5/25.
//

import Foundation

struct SavedQuery: Identifiable, Decodable, Encodable {
    let id: String
    let title: String
    let instruction: String
}

