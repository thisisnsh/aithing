//
//  FirebaseConfiguration.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 12/3/25.
//

import Foundation
import os

// MARK: - Firebase Configuration

/// Manages Firebase configuration state and validation.
/// Detects if Firebase is properly configured via GoogleService-Info.plist.
final class FirebaseConfiguration {

    // MARK: - Singleton

    static let shared = FirebaseConfiguration()

    // MARK: - Properties

    /// Whether Firebase is properly configured with valid credentials
    let isConfigured: Bool

    // MARK: - Constants

    private enum Constants {
        static let plistName = "GoogleService-Info"
        static let plistType = "plist"

        /// Essential keys required for Firebase to function
        static let essentialKeys = [
            "API_KEY",
            "GCM_SENDER_ID",
            "PROJECT_ID",
            "GOOGLE_APP_ID",
        ]
    }

    // MARK: - Initialization

    private init() {
        self.isConfigured = Self.validateConfiguration()
        logConfigurationStatus()        
    }

    // MARK: - Private Methods

    private func logConfigurationStatus() {
        guard !isConfigured else { return }
    }

    /// Validates that GoogleService-Info.plist contains all essential non-empty values
    private static func validateConfiguration() -> Bool {
        guard let plist = loadPlist() else { return false }
        return hasAllEssentialKeys(in: plist)
    }

    private static func loadPlist() -> [String: Any]? {
        guard
            let plistPath = Bundle.main.path(
                forResource: Constants.plistName,
                ofType: Constants.plistType
            )
        else { return nil }

        guard let plistData = FileManager.default.contents(atPath: plistPath) else { return nil }

        return try? PropertyListSerialization.propertyList(
            from: plistData,
            format: nil
        ) as? [String: Any]
    }

    private static func hasAllEssentialKeys(in plist: [String: Any]) -> Bool {
        Constants.essentialKeys.allSatisfy { key in
            guard let value = plist[key] as? String else { return false }
            return !value.isEmpty
        }
    }
}
