//
//  TabModels.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 12/4/25.
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

