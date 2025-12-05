//
//  Array+Extensions.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 12/5/25.
//

import Foundation

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
