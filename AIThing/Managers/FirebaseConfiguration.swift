//
//  FirebaseConfiguration.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 12/3/25.
//

import Foundation
import os

/// A helper class to detect if Firebase is properly configured.
/// Firebase is considered "configured" if the GoogleService-Info.plist
/// contains valid (non-empty) values for essential keys.
final class FirebaseConfiguration {
    static let shared = FirebaseConfiguration()
    
    private let logger = Logger(subsystem: "com.thisisnsh.mac.AIThing", category: "FirebaseConfiguration")
    
    /// Whether Firebase is properly configured with valid credentials
    let isConfigured: Bool
    
    private init() {
        self.isConfigured = FirebaseConfiguration.checkConfiguration()
        
        if !isConfigured {
            Logger(subsystem: "com.thisisnsh.mac.AIThing", category: "FirebaseConfiguration")
                .warning("⚠️ Firebase is not configured. GoogleService-Info.plist has empty or missing values. Firebase features will be disabled (no-op mode).")
        }
    }
    
    /// Checks if the GoogleService-Info.plist has valid configuration values.
    /// Returns true if all essential keys have non-empty values.
    private static func checkConfiguration() -> Bool {
        guard let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plistData = FileManager.default.contents(atPath: plistPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            return false
        }
        
        // Essential keys that must have non-empty values for Firebase to work
        let essentialKeys = [
            "API_KEY",
            "GCM_SENDER_ID",
            "PROJECT_ID",
            "GOOGLE_APP_ID"
        ]
        
        for key in essentialKeys {
            guard let value = plist[key] as? String, !value.isEmpty else {
                return false
            }
        }
        
        return true
    }
    
    /// Logs a warning that a Firebase operation was skipped due to missing configuration
    func logSkipped(operation: String) {
        logger.debug("Firebase operation '\(operation)' skipped - Firebase not configured")
    }
}

