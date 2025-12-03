//
//  Array+Extensions.swift
//  AIThing
//
//  Array extension utilities.
//

import Foundation

extension Array where Element: Identifiable {
    /// Merges incoming elements into the array, replacing existing elements by ID
    func mergedAppending(_ incoming: [Element]) -> [Element] where Element.ID: Hashable {
        var indexByID: [Element.ID: Int] = [:]
        indexByID.reserveCapacity(self.count)

        // Build an index for the current array
        for (i, el) in self.enumerated() { indexByID[el.id] = i }

        var result = self
        result.reserveCapacity(self.count + incoming.count)

        for el in incoming {
            if let i = indexByID[el.id] {
                // replace existing row (e.g., edited message)
                result[i] = el
            } else {
                // append new row
                indexByID[el.id] = result.endIndex
                result.append(el)
            }
        }
        return result
    }
}

extension Array {
    /// Safe subscript that returns nil if index is out of bounds
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

