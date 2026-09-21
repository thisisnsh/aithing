//
//  Utility.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import AppKit
import Foundation
import MCP
import UserNotifications
import os

/// Global logger instance for the application.
let logger = Logger(subsystem: "com.thisisnsh.mac.AIThing", category: "AIThing")

// MARK: - Image Parsing

/// Converts an NSImage to a base64-encoded PNG string.
///
/// - Parameter image: The image to convert
/// - Returns: Base64-encoded PNG string, or nil if conversion fails
func nsImageToBase64(_ image: NSImage) -> String? {
    guard let tiffData = image.tiffRepresentation,
        let bitmapImage = NSBitmapImageRep(data: tiffData),
        let pngData = bitmapImage.representation(using: .png, properties: [:])
    else {
        return nil
    }
    return pngData.base64EncodedString()
}

/// Converts a base64-encoded string to an NSImage.
///
/// - Parameter base64String: The base64-encoded image data
/// - Returns: The decoded NSImage, or nil if decoding fails
func base64ToNSImage(_ base64String: String) -> NSImage? {
    guard let data = Data(base64Encoded: base64String) else { return nil }
    return NSImage(data: data)
}

// MARK: - JSON Parsing

/// Parses a JSON string into an MCP Value object.
///
/// Handles empty strings gracefully by returning an empty object.
///
/// - Parameter json: The JSON string to parse
/// - Returns: The parsed Value object
/// - Throws: Error if JSON parsing fails
func parseJSONStringToValueObject(_ json: String) throws -> Value {
    if json.isEmpty {
        return [:]
    }

    let data = Data(json.utf8)
    let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
    return Value(fromDecoded: jsonObject)
}

/// Parses a JSON string into a dictionary.
///
/// Handles empty strings and invalid JSON gracefully by returning an empty dictionary.
/// Logs errors for debugging purposes.
///
/// - Parameter json: The JSON string to parse
/// - Returns: Dictionary representation of the JSON, or empty dictionary on failure
func parseJSONStringToDictObject(_ json: String) -> [String: Any] {
    do {
        if json.isEmpty {
            return [:]
        }

        let data = Data(json.utf8)
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])

        let value = Value(fromDecoded: jsonObject)

        guard case .object(let dict) = value else {
            logger.error("JSON root is not an object.")
            return [:]
        }

        let jsonSafeDict = dict.mapValues { $0.toJSONSafeObject() }

        return jsonSafeDict.compactMapValues { $0 }  // removes nils safely
    } catch {
        logger.error("Failed to parse JSON: \(error)")
        return [:]
    }
}

/// Converts a dictionary to a pretty-printed JSON string.
///
/// Handles MCP Value types and removes nil values before serialization.
///
/// - Parameter dict: The dictionary to convert
/// - Returns: Pretty-printed JSON string, or empty string on failure
func dictObjectToJSONString(_ dict: [String: Any]) -> String {
    // Step 1: Convert dictionary into JSON-safe values
    let jsonSafe = dict.mapValues { Value(fromDecoded: $0).toJSONSafeObject() }

    // Step 2: Remove nils (because JSONSerialization cannot serialize nil)
    let cleaned = jsonSafe.compactMapValues { $0 }

    // Step 3: Validate before serialization
    guard JSONSerialization.isValidJSONObject(cleaned) else {
        logger.error("Invalid JSON object in dictObjectToJSONString.")
        return ""
    }

    do {
        let data = try JSONSerialization.data(
            withJSONObject: cleaned,
            options: [.prettyPrinted]
        )
        return String(data: data, encoding: .utf8) ?? ""
    } catch {
        logger.error("Failed to serialize JSON: \(error)")
        return ""
    }
}

/// Utility class for debouncing rapid actions.
///
/// Delays execution of an action until a quiet period has elapsed.
class Debouncer {
    private var task: Task<Void, Never>?

    /// Debounces an action with the specified delay.
    ///
    /// Cancels any pending action and schedules a new one. The action will only
    /// execute if no new calls to `debounce` occur within the delay period.
    ///
    /// - Parameters:
    ///   - delay: Delay in seconds before executing the action
    ///   - action: The action to execute after the delay
    func debounce(delay: Double, action: @escaping () -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            action()
        }
    }
}

// MARK: - Time based greetings

/// Returns a time-appropriate greeting based on the current hour.
///
/// - Returns: "Good morning", "Good afternoon", "Good evening", or "Hello"
func timeBasedGreeting() -> String {
    let hour = Calendar.current.component(.hour, from: Date())

    switch hour {
    case 5..<12:
        return "Good morning"
    case 12..<17:
        return "Good afternoon"
    case 17..<22:
        return "Good evening"
    default:
        return "Hello"
    }
}

/// Returns a random time-appropriate subheading based on the current hour.
///
/// Provides engaging prompts that change throughout the day.
///
/// - Returns: A randomly selected subheading appropriate for the current time
func timeBasedSubheading() -> String {
    let hour = Calendar.current.component(.hour, from: Date())

    let morning = [
        "What big thing can I take off your plate this morning?",
        "What can I kickstart for you today?",
        "What challenge can I tackle to power up your day?",
        "What early win can I secure for you this morning?",
        "What can I automate so your day starts smoother?",
        "What goal can I help you move closer to right now?",
    ]

    let afternoon = [
        "What can I take over so your afternoon runs smoother?",
        "What challenge can I eliminate for you today?",
        "What can I automate, solve, or build right now?",
        "What task can I handle so you can stay in flow?",
        "What’s the next thing you want me to make easier?",
        "What progress can I push forward for you this afternoon?",
    ]

    let evening = [
        "What big thing can I take off your plate tonight?",
        "What can I wrap up so your evening stays peaceful?",
        "What challenge can I tackle before the day ends?",
        "What can I automate or solve for you this evening?",
        "What task can I finish so you don’t have to?",
        "What mission am I taking on for you tonight?",
    ]

    let night = [
        "What can I handle while you wind down for the night?",
        "What final task can I take off your plate before you rest?",
        "What can I automate to make tomorrow easier?",
        "What late-night challenge can I solve for you?",
        "What can I take care of while you recharge?",
        "What should I work on so you can relax tonight?",
    ]

    switch hour {
    case 5..<12:
        return morning.randomElement() ?? ""
    case 12..<17:
        return afternoon.randomElement() ?? ""
    case 17..<22:
        return evening.randomElement() ?? ""
    default:
        return night.randomElement() ?? ""
    }
}

// MARK: - Automation Notification

/// Shows a system notification with the given title and body.
///
/// Requests notification permission if not already granted.
/// Silently fails if permission is denied.
///
/// - Parameters:
///   - title: The notification title
///   - body: The notification body text
func showNotification(title: String, body: String) {
    let center = UNUserNotificationCenter.current()

    // Check current authorization status
    center.getNotificationSettings { settings in
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            // Permission already granted, show notification
            sendNotification(title: title, body: body)

        case .notDetermined:
            // Permission not asked yet, request it
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if granted {
                    // Permission granted, show notification
                    sendNotification(title: title, body: body)
                }
                // If denied, do nothing
            }

        case .denied:
            // Permission denied, do nothing
            break

        @unknown default:
            break
        }
    }
}

/// Sends a notification immediately (internal helper).
///
/// - Parameters:
///   - title: The notification title
///   - body: The notification body text
private func sendNotification(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    // Trigger notification immediately
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("Error showing notification: \(error.localizedDescription)")
        }
    }
}
