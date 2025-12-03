//
//  StreamAccumulator.swift
//  AIThing
//
//  Actor for accumulating streaming response data.
//

import Foundation

actor StreamAccumulator {
    private var response: String = ""
    private var toolInput: String = ""
    private var lastUpdateTime: Date = .distantPast

    func appendResponse(_ text: String) { response += text }
    func snapshotResponse() -> String { response }

    func appendToolInput(_ partial: String) { toolInput += partial }
    func snapshotToolInput() -> String { toolInput }

    func shouldThrottle(now: Date, interval: TimeInterval) -> Bool {
        if now.timeIntervalSince(lastUpdateTime) >= interval {
            lastUpdateTime = now
            return true
        }
        return false
    }
}

