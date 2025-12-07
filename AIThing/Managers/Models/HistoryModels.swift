//
//  HistoryModels.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/14/25.
//

import CoreData
import Foundation

struct History: Identifiable, Equatable {
    let id: String
    let lastUpdated: String  // epoch seconds as String
    let title: String?
    let history: [ChatItem]
    let unseen: Bool

    static func == (lhs: History, rhs: History) -> Bool {
        lhs.id == rhs.id && lhs.lastUpdated == rhs.lastUpdated && lhs.title == rhs.title
            && lhs.history.count == rhs.history.count && lhs.unseen == rhs.unseen
    }
}

@objc(HistoryDocMO)
final class HistoryDocMO: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var lastUpdated: Double  // epoch seconds
    @NSManaged var title: String?
    @NSManaged var json: Data  // JSON for [[String: Any]]
    @NSManaged var unseen: Bool  // (defaults to false via model)
}

