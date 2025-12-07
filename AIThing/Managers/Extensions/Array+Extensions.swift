//
//  Array+Extensions.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 12/5/25.
//

import Foundation

// MARK: - Array Extensions

extension Array {
    /// Safely accesses an array element at the given index.
    ///
    /// Returns the element if the index is valid, or nil if out of bounds.
    ///
    /// - Parameter index: The array index to access
    /// - Returns: The element at the index, or nil if out of bounds
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
