//
//  FirestoreManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 6/21/25.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import os

// MARK: - Firestore Manager

/// Manages all Firestore database operations including profiles, configs, models, and agents.
/// All operations are no-op when Firebase is not configured.
final class FirestoreManager: ObservableObject {

    // MARK: - Properties

    private var _db: Firestore?

    private var db: Firestore? {
        guard isEnabled else { return nil }
        if _db == nil { _db = Firestore.firestore() }
        return _db
    }

    private var isEnabled: Bool {
        FirebaseConfiguration.shared.isConfigured
    }

    // MARK: - Constants

    private enum Collection {
        static let system = "System"
        static let profiles = "Profiles"
        static let agents = "Agents"
        static let models = "Models-2"
    }

    private enum Document {
        static let configs = "Configs-2.1"
        static let managedGitHubAgent = "managed_aithing_github"
    }

    private enum ConfigKey {
        static let breakglass = "breakglass"
        static let expired = "expired"
        static let notification = "notification"
        static let greeting = "greeting"
    }

    private enum ProfileField {
        static let usageQuery = "usageData.query"
        static let usageAgentUse = "usageData.agentUse"
        static let usageFilesAttached = "usageData.filesAttached"
    }
}

// MARK: - System Configuration

extension FirestoreManager {

    /// Fetches the breakglass flag from system config
    func getBreakglass() async -> Bool {
        await fetchConfigValue(key: ConfigKey.breakglass) ?? false
    }

    /// Fetches the expired flag from system config
    func getExpired() async -> Bool {
        await fetchConfigValue(key: ConfigKey.expired) ?? false
    }

    /// Fetches the notification message from system config
    func getNotification() async -> String? {
        await fetchConfigValue(key: ConfigKey.notification)
    }

    // MARK: - Private Config Helpers

    private func fetchConfigValue<T>(key: String) async -> T? {
        guard isEnabled, let db else {
            return nil
        }

        do {
            let snapshot = try await db.collection(Collection.system)
                .document(Document.configs)
                .getDocument()

            guard let data = snapshot.data(),
                let value = data[key] as? T
            else {
                return nil
            }

            return value
        } catch {
            logger.error("[FirestoreManager] Error fetching \(key): \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Profile Management

extension FirestoreManager {

    /// Fetches or creates a profile for the given user
    func getProfile(user: AppUser) async -> Profile? {
        guard isEnabled, let db else {
            return createDefaultProfile(for: user)
        }

        // Try to fetch existing profile
        if let profile = await fetchExistingProfile(userId: user.uid) {
            return profile
        }

        // Create new profile if none exists
        return await createNewProfile(for: user, in: db)
    }

    /// Increments usage statistics for a user
    func incrementUsage(user: AppUser, usage: Usage) async {
        await updateProfileField(
            userId: user.uid,
            updates: [
                ProfileField.usageQuery: FieldValue.increment(Int64(usage.query)),
                ProfileField.usageAgentUse: FieldValue.increment(Int64(usage.agentUse)),
                ProfileField.usageFilesAttached: FieldValue.increment(Int64(usage.filesAttached)),
            ],
            analyticsKey: "increment_usage"
        )
    }

    // MARK: - Private Profile Helpers

    private func createDefaultProfile(for user: AppUser) -> Profile {
        Profile(
            id: user.uid,
            name: user.displayName,
            email: user.email ?? "",
            blocked: false,
            usageData: Usage()
        )
    }

    private func fetchExistingProfile(userId: String) async -> Profile? {
        guard let db else { return nil }

        do {
            let snapshot = try await db.collection(Collection.profiles)
                .document(userId)
                .getDocument()

            if let profile = try? snapshot.data(as: Profile.self) {
                return profile
            }
            return nil
        } catch {
            logger.error("[FirestoreManager] Error fetching profile for ID \(userId): \(error.localizedDescription)")
            return nil
        }
    }

    private func createNewProfile(for user: AppUser, in db: Firestore) async -> Profile? {
        let profile = Profile(
            id: user.uid,
            name: user.displayName,
            email: user.email ?? "",
            blocked: false,
            usageData: Usage()
        )

        do {
            try db.collection(Collection.profiles)
                .document(user.uid)
                .setData(from: profile)

            return profile
        } catch {
            logger.error("[FirestoreManager] Error creating profile for ID \(user.uid): \(error.localizedDescription)")
            return nil
        }
    }

    private func updateProfileField(userId: String, updates: [String: Any], analyticsKey: String) async {
        guard isEnabled, let db else {
            return
        }

        do {
            try await db.collection(Collection.profiles)
                .document(userId)
                .updateData(updates)
        } catch {
            logger.error("[FirestoreManager] Error updating \(analyticsKey) for ID \(userId): \(error.localizedDescription)")
        }
    }
}

// MARK: - Models

extension FirestoreManager {

    /// Fetches all available model configurations from Firestore and local plist.
    func getModelInfos() async -> [ModelInfo] {
        var allModels: [ModelInfo] = []

        // Load from Firestore
        if isEnabled, let db {
            do {
                let snapshot = try await db.collection(Collection.models).getDocuments()
                let firestoreModels = snapshot.documents.compactMap { try? $0.data(as: ModelInfo.self) }
                allModels.append(contentsOf: firestoreModels)
            } catch {
                logger.error("[FirestoreManager] Error fetching models: \(error.localizedDescription)")
            }
        }

        // Load from local plist
        let localModels = loadLocalModels()
        allModels.append(contentsOf: localModels)

        return allModels
    }

    private func sortModels(_ models: [ModelInfo]) -> [ModelInfo] {
        let providerOrder: [AIProvider: Int] = [
            .anthropic: 0,
            .openai: 1,
            .google: 2,
        ]

        return models.sorted { a, b in
            if a.provider == b.provider {
                return a.name.localizedCompare(b.name) == .orderedAscending
            }
            return providerOrder[a.provider, default: 99] < providerOrder[b.provider, default: 99]
        }
    }

    /// Loads models from the local Models.plist file in the app bundle.
    private func loadLocalModels() -> [ModelInfo] {
        guard let url = Bundle.main.url(forResource: "Models", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plistArray = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]]
        else {
            return []
        }

        return plistArray.compactMap { dict -> ModelInfo? in
            guard let id = dict["id"] as? String, !id.isEmpty else {
                return nil
            }

            let name = (dict["name"] as? String) ?? id
            let providerString = dict["provider"] as? String ?? "anthropic"
            let provider = AIProvider(rawValue: providerString) ?? .anthropic

            return ModelInfo(id: id, name: name, provider: provider)
        }
    }
}

// MARK: - Agents

extension FirestoreManager {

    /// Managed GitHub Agent credentials
    struct ManagedGitHubAgent: Codable {
        let clientId: String
        let clientSecret: String
    }

    /// Fetches the managed GitHub agent credentials
    func getManagedGitHubAgent() async -> ManagedGitHubAgent? {
        guard isEnabled, let db else {
            return nil
        }

        do {
            let snapshot = try await db.collection(Collection.agents)
                .document(Document.managedGitHubAgent)
                .getDocument()

            if let agent = try? snapshot.data(as: ManagedGitHubAgent.self) {
                return agent
            }
            return nil
        } catch {
            logger.error("[FirestoreManager] Error fetching managed GitHub agent: \(error.localizedDescription)")
            return nil
        }
    }

    /// Fetches all managed MCP agents
    func getManagedAgents() async -> [McpServer] {
        guard isEnabled, let db else {
            return []
        }

        do {
            let snapshot = try await db.collection(Collection.agents).getDocuments()
            let agents = snapshot.documents.compactMap { doc -> McpServer? in
                guard let server = try? doc.data(as: McpServer.self) else { return nil }
                return McpServer(
                    id: doc.documentID,
                    image: server.image,
                    name: server.name,
                    url: server.url,
                    version: server.version,
                    enabled: server.enabled,
                    custom: server.custom
                )
            }

            return agents
        } catch {
            logger.error("[FirestoreManager] Error fetching managed agents: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - Date Parser

private enum DateParser {

    /// Parses date strings in various formats (e.g., "September 16, 2025 at 11:59:59 PM UTC-4")
    static func parseEndDate(_ raw: String) -> Date? {
        // Strip leading "endDate " if present
        let cleaned = raw.replacingOccurrences(
            of: "^endDate\\s+",
            with: "",
            options: .regularExpression
        )

        for formatter in dateFormatters {
            if let date = formatter.date(from: cleaned) {
                return date
            }
        }

        // Try ISO8601 as last resort
        return ISO8601DateFormatter().date(from: cleaned)
    }

    private static var dateFormatters: [DateFormatter] {
        let eastern = TimeZone(identifier: "America/New_York")
        let locale = Locale(identifier: "en_US_POSIX")

        let formats: [(String, TimeZone?)] = [
            ("MMMM d, yyyy 'at' h:mm:ss a 'UTC'XXXXX", nil),
            ("MMMM d, yyyy 'at' h:mm a 'UTC'XXXXX", nil),
            ("MMMM d, yyyy h:mm:ss a 'UTC'XXXXX", nil),
            ("MMMM d, yyyy h:mm a 'UTC'XXXXX", nil),
            ("MMMM d, yyyy 'at' h:mm:ss a", eastern),
            ("MMMM d, yyyy 'at' h:mm a", eastern),
        ]

        return formats.map { format, tz in
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.dateFormat = format
            formatter.timeZone = tz
            return formatter
        }
    }
}
