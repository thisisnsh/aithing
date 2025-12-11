//
//  StreamAccumulator.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 12/5/25.
//

import Foundation

// MARK: - Stream Accumulator

/// Thread-safe accumulator for streaming API responses.
///
/// Accumulates text chunks from streaming responses and provides throttling
/// for UI updates to prevent overwhelming the main thread.
actor StreamAccumulator {
    private var response: String = ""
    private var toolInput: String = ""
    private var lastUpdateTime: Date = .distantPast

    /// Appends text to the response buffer.
    ///
    /// - Parameter text: The text chunk to append
    func appendResponse(_ text: String) { response += text }
    
    /// Returns the current accumulated response.
    ///
    /// - Returns: The full response string
    func snapshotResponse() -> String { response }

    /// Appends partial input to the tool input buffer.
    ///
    /// - Parameter partial: The partial tool input to append
    func appendToolInput(_ partial: String) { toolInput += partial }
    
    /// Returns the current accumulated tool input.
    ///
    /// - Returns: The full tool input string
    func snapshotToolInput() -> String { toolInput }

    /// Determines if enough time has passed since the last update.
    ///
    /// Used to throttle UI updates during streaming to prevent overwhelming
    /// the main thread with too many state changes.
    ///
    /// - Parameters:
    ///   - now: The current timestamp
    ///   - interval: The minimum interval between updates
    /// - Returns: `true` if the interval has elapsed and throttle should allow update
    func shouldThrottle(now: Date, interval: TimeInterval) -> Bool {
        if now.timeIntervalSince(lastUpdateTime) >= interval {
            lastUpdateTime = now
            return true
        }
        return false
    }
}

