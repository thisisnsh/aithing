//
//  TabModels.swift
//  AIThing
//
//  Models for tab management.
//

import Foundation

struct TabItem: Equatable {
    let id: String
    var active: Bool = false
    var lastUpdated: Date = Date()

    static func == (lhs: TabItem, rhs: TabItem) -> Bool {
        lhs.id == rhs.id
    }
}

