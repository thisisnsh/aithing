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
    
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.thisisnsh.mac.AIThing",
        category: "FirestoreManager"
    )
    
    private var isEnabled: Bool {
        FirebaseConfiguration.shared.isConfigured
    }
    
    // MARK: - Constants
    
    private enum Collection {
        static let system = "System"
        static let profiles = "Profiles"
        static let models = "Models"
        static let agents = "Agents"
        static let planDetails = "PlanDetails"
        static let plans = "Plans"
    }
    
    private enum Document {
        static let configs = "Configs-2.0"
        static let managedGitHubAgent = "managed_github_agent"
    }
    
    private enum ConfigKey {
        static let breakglass = "breakglass"
        static let expired = "expired"
        static let apiKeyAnthropic = "apiKeyAnthropic"
        static let defaultCredits = "defaultCredits"
        static let notification = "notification"
        static let greeting = "greeting"
    }
    
    private enum ProfileField {
        static let creditsUsed = "creditsUsed"
        static let usageQuery = "usageData.query"
        static let usageAgentUse = "usageData.agentUse"
        static let usageFilesAttached = "usageData.filesAttached"
    }
}

// MARK: - System Configuration

extension FirestoreManager {
    
    /// Fetches the breakglass flag from system config
    func getBreakglass() async -> Bool {
        await fetchConfigValue(key: ConfigKey.breakglass, analyticsKey: "get_breakglass") ?? false
    }
    
    /// Fetches the expired flag from system config
    func getExpired() async -> Bool {
        await fetchConfigValue(key: ConfigKey.expired, analyticsKey: "get_expired") ?? false
    }
    
    /// Fetches the Anthropic API key from system config
    func getApiKeyAnthropic() async -> String {
        await fetchConfigValue(key: ConfigKey.apiKeyAnthropic, analyticsKey: "get_anthropic_api_key") ?? ""
    }
    
    /// Fetches the default credits amount from system config
    func getDefaultCredits() async -> Int? {
        guard isEnabled else {
            FirebaseConfiguration.shared.logSkipped(operation: "getDefaultCredits")
            return 50 // Default when Firebase is not configured
        }
        return await fetchConfigValue(key: ConfigKey.defaultCredits, analyticsKey: "get_default_credits")
    }
    
    /// Fetches the notification message from system config
    func getNotification() async -> String? {
        await fetchConfigValue(key: ConfigKey.notification, analyticsKey: "get_notification")
    }
    
    /// Fetches the greeting message from system config
    func getGreeting() async -> String? {
        await fetchConfigValue(key: ConfigKey.greeting, analyticsKey: "get_greeting")
    }
    
    // MARK: - Private Config Helpers
    
    private func fetchConfigValue<T>(key: String, analyticsKey: String) async -> T? {
        guard isEnabled, let db else {
            FirebaseConfiguration.shared.logSkipped(operation: analyticsKey)
            return nil
        }
        
        do {
            let snapshot = try await db.collection(Collection.system)
                .document(Document.configs)
                .getDocument()
            
            guard let data = snapshot.data(),
                  let value = data[key] as? T else {
                return nil
            }
            
            logAnalytics(operation: analyticsKey, success: true)
            return value
        } catch {
            logAnalytics(operation: analyticsKey, success: false)
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
            FirebaseConfiguration.shared.logSkipped(operation: "getProfile")
            return createDefaultProfile(for: user)
        }
        
        // Try to fetch existing profile
        if let profile = await fetchExistingProfile(userId: user.uid) {
            return profile
        }
        
        // Create new profile if none exists
        return await createNewProfile(for: user, in: db)
    }
    
    /// Increments the credits used for a user
    func incrementCredits(user: AppUser, by amount: Int) async {
        await updateProfileField(
            userId: user.uid,
            updates: [ProfileField.creditsUsed: FieldValue.increment(Int64(amount))],
            analyticsKey: "increment_credit"
        )
    }
    
    /// Increments usage statistics for a user
    func incrementUsage(user: AppUser, usage: Usage) async {
        await updateProfileField(
            userId: user.uid,
            updates: [
                ProfileField.usageQuery: FieldValue.increment(Int64(usage.query)),
                ProfileField.usageAgentUse: FieldValue.increment(Int64(usage.agentUse)),
                ProfileField.usageFilesAttached: FieldValue.increment(Int64(usage.filesAttached))
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
            creditsTotal: 50,
            creditsUsed: 0,
            blocked: false,
            apiKeyAnthropic: "",
            apiKeyOpenAI: "",
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
                logAnalytics(operation: "get_profile", success: true)
                return profile
            }
            return nil
        } catch {
            logAnalytics(operation: "get_profile", success: false)
            logger.error("[FirestoreManager] Error fetching profile for ID \(userId): \(error.localizedDescription)")
            return nil
        }
    }
    
    private func createNewProfile(for user: AppUser, in db: Firestore) async -> Profile? {
        let apiKey = await getApiKeyAnthropic()
        let defaultCredits = await getDefaultCredits()
        
        let profile = Profile(
            id: user.uid,
            name: user.displayName,
            email: user.email ?? "",
            creditsTotal: defaultCredits ?? 50,
            creditsUsed: 0,
            blocked: false,
            apiKeyAnthropic: apiKey,
            apiKeyOpenAI: "",
            usageData: Usage()
        )
        
        do {
            try db.collection(Collection.profiles)
                .document(user.uid)
                .setData(from: profile)
            logAnalytics(operation: "create_profile", success: true)
            return profile
        } catch {
            logAnalytics(operation: "create_profile", success: false)
            logger.error("[FirestoreManager] Error creating profile for ID \(user.uid): \(error.localizedDescription)")
            return nil
        }
    }
    
    private func updateProfileField(userId: String, updates: [String: Any], analyticsKey: String) async {
        guard isEnabled, let db else {
            FirebaseConfiguration.shared.logSkipped(operation: analyticsKey)
            return
        }
        
        do {
            try await db.collection(Collection.profiles)
                .document(userId)
                .updateData(updates)
            logAnalytics(operation: analyticsKey, success: true)
        } catch {
            logAnalytics(operation: analyticsKey, success: false)
            logger.error("[FirestoreManager] Error updating \(analyticsKey) for ID \(userId): \(error.localizedDescription)")
        }
    }
}

// MARK: - Models

extension FirestoreManager {
    
    /// Fetches all available model configurations
    func getModelInfos() async -> [ModelInfo] {
        guard isEnabled, let db else {
            FirebaseConfiguration.shared.logSkipped(operation: "getModelInfos")
            return []
        }
        
        do {
            let snapshot = try await db.collection(Collection.models).getDocuments()
            let models = snapshot.documents.compactMap { try? $0.data(as: ModelInfo.self) }
            
            logAnalytics(operation: "get_model_info", success: true)
            return sortModels(models)
        } catch {
            logAnalytics(operation: "get_model_info", success: false)
            logger.error("[FirestoreManager] Error fetching models: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Creates or updates a model configuration
    func createModel(model: ModelInfo) async {
        guard isEnabled, let db else {
            FirebaseConfiguration.shared.logSkipped(operation: "createModel")
            return
        }
        
        do {
            try db.collection(Collection.models)
                .document(model.id)
                .setData(from: model)
            logger.info("[FirestoreManager] Created/updated model with id \(model.id)")
        } catch {
            logger.error("[FirestoreManager] Error creating model \(model.id): \(error.localizedDescription)")
        }
    }
    
    private func sortModels(_ models: [ModelInfo]) -> [ModelInfo] {
        models.sorted {
            if $0.order == $1.order {
                return $0.title.localizedCompare($1.title) == .orderedAscending
            }
            return $0.order < $1.order
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
            FirebaseConfiguration.shared.logSkipped(operation: "getManagedGitHubAgent")
            return nil
        }
        
        do {
            let snapshot = try await db.collection(Collection.agents)
                .document(Document.managedGitHubAgent)
                .getDocument()
            
            if let agent = try? snapshot.data(as: ManagedGitHubAgent.self) {
                logAnalytics(operation: "get_managed_github_agent", success: true)
                return agent
            }
            return nil
        } catch {
            logAnalytics(operation: "get_managed_github_agent", success: false)
            logger.error("[FirestoreManager] Error fetching managed GitHub agent: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Fetches all managed MCP agents
    func getManagedAgents() async -> [McpServer] {
        guard isEnabled, let db else {
            FirebaseConfiguration.shared.logSkipped(operation: "getManagedAgents")
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
            
            logAnalytics(operation: "get_managed_agents", success: true)
            return agents
        } catch {
            logAnalytics(operation: "get_managed_agents", success: false)
            logger.error("[FirestoreManager] Error fetching managed agents: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - Plans & Credits

extension FirestoreManager {
    
    /// Fetches the total credits from active plans for an email
    func fetchCreditsPlans(email: String) async -> Int {
        guard isEnabled else {
            FirebaseConfiguration.shared.logSkipped(operation: "fetchCreditsPlans")
            return 0
        }
        return await calculateActivePlanCredits(forEmail: email)
    }
    
    /// Returns a map of planId -> credits from PlanDetails collection
    func getPlanDetailsMap() async -> [String: Int] {
        guard isEnabled, let db else {
            FirebaseConfiguration.shared.logSkipped(operation: "getPlanDetailsMap")
            return [:]
        }
        
        do {
            let snapshot = try await db.collection(Collection.planDetails).getDocuments()
            return parsePlanDetails(from: snapshot.documents)
        } catch {
            logAnalytics(operation: "fetch_credits_error_plan_details", success: false)
            logger.error("[FirestoreManager] Error fetching PlanDetails: \(error.localizedDescription)")
            return [:]
        }
    }
    
    /// Fetches active orders for a user that haven't expired
    func getActiveOrders(forEmail email: String, planCredits: [String: Int], asOf: Date = Date()) async -> [PlanOrder] {
        guard isEnabled, let db else {
            FirebaseConfiguration.shared.logSkipped(operation: "getActiveOrders")
            return []
        }
        
        let planIds = Array(planCredits.keys)
        guard !planIds.isEmpty else { return [] }
        
        let userDoc = db.collection(Collection.plans).document(email)
        
        return await withTaskGroup(of: [PlanOrder].self) { group in
            for planId in planIds {
                group.addTask { [weak self] in
                    await self?.fetchActiveOrdersForPlan(
                        planId: planId,
                        userDoc: userDoc,
                        asOf: asOf
                    ) ?? []
                }
            }
            
            var allOrders: [PlanOrder] = []
            for await orders in group {
                allOrders.append(contentsOf: orders)
            }
            return allOrders
        }
    }
    
    // MARK: - Private Plan Helpers
    
    private func calculateActivePlanCredits(forEmail email: String, asOf: Date = Date()) async -> Int {
        let planCredits = await getPlanDetailsMap()
        let orders = await getActiveOrders(forEmail: email, planCredits: planCredits, asOf: asOf)
        
        return orders.reduce(0) { total, order in
            if let credits = planCredits[order.planId] {
                return total + credits
            } else {
                logAnalytics(operation: "fetch_credits_missing_plan_details", success: false)
                logger.error("[FirestoreManager] Missing PlanDetails for planId \(order.planId)")
                return total
            }
        }
    }
    
    private func parsePlanDetails(from documents: [DocumentSnapshot]) -> [String: Int] {
        var result: [String: Int] = [:]
        
        for doc in documents {
            if let detail = try? doc.data(as: PlanDetail.self) {
                result[doc.documentID] = detail.credits
            } else if let credits = doc.data()?["credits"] as? Int {
                // Fallback: tolerant read if Codable fails
                result[doc.documentID] = credits
            }
        }
        
        return result
    }
    
    private func fetchActiveOrdersForPlan(
        planId: String,
        userDoc: DocumentReference,
        asOf: Date
    ) async -> [PlanOrder] {
        let subcol = userDoc.collection(planId)
        
        // Try server-side filter first (requires Timestamp endDate)
        if let orders = await fetchOrdersWithServerFilter(subcol: subcol, planId: planId, asOf: asOf) {
            return orders
        }
        
        // Fallback to client-side filtering
        return await fetchOrdersWithClientFilter(subcol: subcol, planId: planId, asOf: asOf)
    }
    
    private func fetchOrdersWithServerFilter(
        subcol: CollectionReference,
        planId: String,
        asOf: Date
    ) async -> [PlanOrder]? {
        do {
            let ts = Timestamp(date: asOf)
            let snap = try await subcol.whereField("endDate", isGreaterThan: ts).getDocuments()
            
            let orders = snap.documents.compactMap { doc in
                decodeOrder(doc: doc, planId: planId, fallbackStringParsing: false)
            }
            return orders.sorted { $0.endDate < $1.endDate }
        } catch {
            return nil // Fall back to client-side filtering
        }
    }
    
    private func fetchOrdersWithClientFilter(
        subcol: CollectionReference,
        planId: String,
        asOf: Date
    ) async -> [PlanOrder] {
        do {
            let snap = try await subcol.getDocuments()
            
            let orders = snap.documents.compactMap { doc -> PlanOrder? in
                guard let order = decodeOrder(doc: doc, planId: planId, fallbackStringParsing: true),
                      order.endDate > asOf else {
                    return nil
                }
                return order
            }
            return orders.sorted { $0.endDate < $1.endDate }
        } catch {
            logAnalytics(operation: "fetch_credits_error_reading_orders", success: false)
            logger.error("[FirestoreManager] Error reading orders for planId \(planId): \(error.localizedDescription)")
            return []
        }
    }
    
    private func decodeOrder(doc: DocumentSnapshot, planId: String, fallbackStringParsing: Bool) -> PlanOrder? {
        let data = doc.data() ?? [:]
        
        // Try Timestamp first
        if let ts = data["endDate"] as? Timestamp {
            return PlanOrder(id: doc.documentID, planId: planId, endDate: ts.dateValue())
        }
        
        // Try string parsing if enabled
        if fallbackStringParsing {
            if let dateString = data["endDate"] as? String,
               let parsed = DateParser.parseEndDate(dateString) {
                return PlanOrder(id: doc.documentID, planId: planId, endDate: parsed)
            }
            
            if let isoString = data["endDateISO"] as? String,
               let parsed = ISO8601DateFormatter().date(from: isoString) {
                return PlanOrder(id: doc.documentID, planId: planId, endDate: parsed)
            }
        }
        
        logAnalytics(operation: "fetch_credits_error_decoding_date", success: false)
        return nil
    }
}

// MARK: - Analytics Helper

private extension FirestoreManager {
    
    func logAnalytics(operation: String, success: Bool) {
        AnalyticsManager.shared.customEvent(
            view: .FirebaseManager,
            primary: .firebase,
            secondary: operation,
            sev: success ? .info : .error
        )
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
            ("MMMM d, yyyy 'at' h:mm a", eastern)
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

