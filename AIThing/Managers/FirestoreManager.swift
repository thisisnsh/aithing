//
//  FirestoreManager.swift
//  BF2
//
//  Created by Nishant Singh Hada on 6/21/25.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation

struct Profile: Codable {
    var id: String
    var name: String?
    var email: String
    var creditsTotal: Int
    var creditsUsed: Int
    var blocked: Bool?
    var apiKeyAnthropic: String
    var apiKeyOpenAI: String
}

struct PlanDetail: Codable {
    var credits: Int
}

struct PlanOrder: Codable {
    var id: String
    var planId: String
    var endDate: Date
}

class FirestoreManager: ObservableObject {
    let db = Firestore.firestore()

    func getBreakglass() async -> Bool {
        do {
            let snapshot = try await db.collection("System").document("Configs-1.4").getDocument()
            guard let data = snapshot.data() else { return false }
            guard let breakglass = data["breakglass"] as? Bool else { return false }
            AnalyticsManager.shared.customFirestore(action: "get_breakglass", status: "success")
            return breakglass
        } catch {
            AnalyticsManager.shared.customFirestore(action: "get_breakglass", status: "failure")
            print(
                "[FirestoreManager] Error fetching breakglass: \(error.localizedDescription)"
            )
            return false
        }
    }

    func getExpired() async -> Bool {
        do {
            let snapshot = try await db.collection("System").document("Configs-1.4").getDocument()
            guard let data = snapshot.data() else { return false }
            guard let expired = data["expired"] as? Bool else { return false }
            AnalyticsManager.shared.customFirestore(action: "get_expired", status: "success")
            return expired
        } catch {
            AnalyticsManager.shared.customFirestore(action: "get_expired", status: "failure")
            print(
                "[FirestoreManager] Error fetching expired: \(error.localizedDescription)"
            )
            return false
        }
    }

    func getApiKeyAnthropic() async -> String {
        do {
            let snapshot = try await db.collection("System").document("Configs-1.4").getDocument()
            guard let data = snapshot.data() else { return "" }
            guard let apiKeyAnthropic = data["apiKeyAnthropic"] as? String else { return "" }
            AnalyticsManager.shared.customFirestore(
                action: "get_anthropic_api_key",
                status: "success"
            )
            return apiKeyAnthropic
        } catch {
            AnalyticsManager.shared.customFirestore(
                action: "get_anthropic_api_key",
                status: "failure"
            )
            print(
                "[FirestoreManager] Error fetching apiKeyAnthropic: \(error.localizedDescription)"
            )
            return ""
        }
    }

    func getDefaultCredits() async -> Int? {
        do {
            let snapshot = try await db.collection("System").document("Configs-1.4").getDocument()
            guard let data = snapshot.data() else { return nil }
            guard let defaultCredits = data["defaultCredits"] as? Int else { return nil }
            AnalyticsManager.shared.customFirestore(
                action: "get_default_credits",
                status: "success"
            )
            return defaultCredits
        } catch {
            AnalyticsManager.shared.customFirestore(
                action: "get_default_credits",
                status: "failure"
            )
            print(
                "[FirestoreManager] Error fetching defaultCredits: \(error.localizedDescription)"
            )
            return nil
        }
    }

    private func _getProfile(user: AppUser) async -> Profile? {
        let id = user.uid

        do {
            let snapshot = try await db.collection("Profiles").document(id).getDocument()
            if let profile = try? snapshot.data(as: Profile.self) {
                AnalyticsManager.shared.customFirestore(action: "get_profile", status: "success")
                return profile
            }

            return nil
        } catch {
            AnalyticsManager.shared.customFirestore(action: "get_profile", status: "failure")
            print(
                "[FirestoreManager] Error fetching profile for ID \(id): \(error.localizedDescription)"
            )
            return nil
        }
    }

    func getProfile(user: AppUser) async -> Profile? {
        let id = user.uid

        if let profile = await _getProfile(user: user) {
            return profile
        }

        let apiKeyAnthropic = await getApiKeyAnthropic()
        let defaultCredits = await getDefaultCredits()

        let profile = Profile(
            id: id,
            name: user.displayName,
            email: user.email ?? "",  // todo: handle properly
            creditsTotal: defaultCredits ?? 50,
            creditsUsed: 0,
            blocked: false,
            apiKeyAnthropic: apiKeyAnthropic,
            apiKeyOpenAI: ""
        )

        do {
            try db.collection("Profiles").document(id).setData(from: profile)
            AnalyticsManager.shared.customFirestore(action: "create_profile", status: "success")
            return profile
        } catch {
            AnalyticsManager.shared.customFirestore(action: "create_profile", status: "failure")
            print(
                "[FirestoreManager] Error creating profile for ID \(id): \(error.localizedDescription)"
            )
            return nil
        }
    }

    func incrementCredits(user: AppUser, by amount: Int) async {
        let id = user.uid

        do {
            try await db.collection("Profiles").document(id).updateData([
                "creditsUsed": FieldValue.increment(Int64(amount))
            ])
            AnalyticsManager.shared.customFirestore(action: "increment_credit", status: "success")
        } catch {
            AnalyticsManager.shared.customFirestore(action: "increment_credit", status: "failure")
            print(
                "[FirestoreManager] Error incrementing creditsUsed by \(amount) for ID \(id): \(error.localizedDescription)"
            )
        }
    }

    func getModelInfos() async -> [ModelInfo] {
        do {
            let snapshot = try await db.collection("Models").getDocuments()

            let models: [ModelInfo] = snapshot.documents.compactMap { doc in
                if let model = try? doc.data(as: ModelInfo.self) {
                    return model
                }
                return nil
            }

            AnalyticsManager.shared.customFirestore(action: "get_model_info", status: "success")

            // Sort: first by order, then by title if order is equal
            return models.sorted {
                if $0.order == $1.order {
                    return $0.title.localizedCompare($1.title) == .orderedAscending
                }
                return $0.order < $1.order
            }
        } catch {
            AnalyticsManager.shared.customFirestore(action: "get_model_info", status: "failure")
            print("[FirestoreManager] Error fetching models: \(error.localizedDescription)")
            return []
        }
    }

    func createModel(model: ModelInfo) async {
        do {
            try db.collection("Models").document(model.id).setData(from: model)
            print("[FirestoreManager] Created/updated model with id \(model.id)")
        } catch {
            print(
                "[FirestoreManager] Error creating model \(model.id): \(error.localizedDescription)"
            )
        }
    }

    func fetchCreditsPlans(email: String) async -> Int {
        let creditsPlans = await getActivePlanCredits(forEmail: email)
        return creditsPlans
    }

}

extension FirestoreManager {

    private func getActivePlanCredits(forEmail email: String, asOf: Date = Date()) async -> Int {
        let planCredits = await getPlanDetailsMap()

        let orders = await getActiveOrders(forEmail: email, planCredits: planCredits, asOf: asOf)

        var total = 0
        for order in orders {
            if let credits = planCredits[order.planId] {
                total += credits
            } else {
                AnalyticsManager.shared.customFirestore(
                    action: "fetch_credits_missing_plan_details",
                    status: "failure"
                )
                print("[FirestoreManager] Missing PlanDetails for planId \(order.planId)")
            }
        }
        return total
    }

    /// Returns a map of planId -> credits, read from /PlanDetails/<planId>.
    func getPlanDetailsMap() async -> [String: Int] {
        var result: [String: Int] = [:]
        do {
            let snapshot = try await db.collection("PlanDetails").getDocuments()
            for doc in snapshot.documents {
                if let detail = try? doc.data(as: PlanDetail.self) {
                    result[doc.documentID] = detail.credits
                } else {
                    // If decoding fails, try a tolerant read
                    let data = doc.data()
                    if let credits = data["credits"] as? Int {
                        result[doc.documentID] = credits
                    }
                }
            }
        } catch {
            AnalyticsManager.shared.customFirestore(
                action: "fetch_credits_error_plan_details",
                status: "failure"
            )
            print("[FirestoreManager] Error fetching PlanDetails: \(error.localizedDescription)")
        }
        return result
    }

    /// Loads all orders for the given email with endDate in the future relative to `asOf`.
    ///
    /// Implementation note:
    /// - We first fetch all planIds from /PlanDetails, then for each planId we read the subcollection
    ///   /Plans/<email>/<planId>.
    /// - We try a server filter `whereField("endDate", isGreaterThan:)` assuming endDate is a Timestamp.
    ///   If the field is stored as string, we fall back to fetching the subcollection and filtering client-side.
    func getActiveOrders(forEmail email: String, planCredits: [String: Int], asOf: Date = Date())
        async -> [PlanOrder]
    {
        var active: [PlanOrder] = []
        let planIds = Array(planCredits.keys)  // Using PlanDetails as the source of truth for valid planIds
        if planIds.isEmpty {
            return []
        }

        let userDoc = db.collection("Plans").document(email)

        await withTaskGroup(of: [PlanOrder].self) { group in
            for planId in planIds {
                group.addTask { [weak self] in
                    guard let self = self else { return [] }

                    let subcol = userDoc.collection(planId)
                    var collected: [PlanOrder] = []

                    // Preferred path: endDate is a Firestore Timestamp (server-side filter)
                    do {

                        let ts = Timestamp(date: asOf)

                        let snap = try await subcol.whereField("endDate", isGreaterThan: ts)
                            .getDocuments()

                        for doc in snap.documents {

                            if let order = self.decodeOrder(
                                doc: doc,
                                planId: planId,
                                fallbackStringParsing: false
                            ) {
                                collected.append(order)
                            }
                        }
                        return collected.sorted { $0.endDate < $1.endDate }
                    } catch {
                        // Fallback: load all docs and parse endDate that might be a String

                        do {
                            let snap = try await subcol.getDocuments()

                            for doc in snap.documents {

                                if let order = self.decodeOrder(
                                    doc: doc,
                                    planId: planId,
                                    fallbackStringParsing: true
                                ),
                                    order.endDate > asOf
                                {
                                    collected.append(order)
                                }
                            }
                            return collected.sorted { $0.endDate < $1.endDate }
                        } catch {
                            AnalyticsManager.shared.customFirestore(
                                action: "fetch_credits_error_reading_orders",
                                status: "failure"
                            )
                            print(
                                "[FirestoreManager] Error reading /Plans/\(email)/\(planId): \(error.localizedDescription)"
                            )
                            return []
                        }
                    }
                }
            }

            for await chunk in group {
                active.append(contentsOf: chunk)
            }
        }

        return active
    }

    /// Attempts to decode a PlanOrder from a DocumentSnapshot.
    /// - Tries Codable first if the schema matches.
    /// - Otherwise, reads fields manually and parses endDate as Timestamp or String.
    private func decodeOrder(doc: DocumentSnapshot, planId: String, fallbackStringParsing: Bool)
        -> PlanOrder?
    {
        // Try Codable first (if you ever add @DocumentID etc.):
        // if let order = try? doc.data(as: PlanOrder.self) { return order }

        let data = doc.data() ?? [:]

        // Try Timestamp
        if let ts = data["endDate"] as? Timestamp {
            return PlanOrder(id: doc.documentID, planId: planId, endDate: ts.dateValue())
        }

        // Optionally parse String endDate
        if fallbackStringParsing, let s = data["endDate"] as? String,
            let parsed = parseEndDateString(s)
        {
            return PlanOrder(id: doc.documentID, planId: planId, endDate: parsed)
        }

        // Try ISO8601 string variants too, if you store them that way
        if fallbackStringParsing, let s = data["endDateISO"] as? String,
            let parsed = ISO8601DateFormatter().date(from: s)
        {
            return PlanOrder(id: doc.documentID, planId: planId, endDate: parsed)
        }

        AnalyticsManager.shared.customFirestore(
            action: "fetch_credits_error_decoding_date",
            status: "failure"
        )
        return nil
    }

    /// Parses example strings like: "endDate September 16, 2025 at 11:59:59 PM UTC-4"
    /// Tries a few tolerant formats; add/remove as your data dictates.
    private func parseEndDateString(_ raw: String) -> Date? {
        // Strip leading "endDate " if present
        let s = raw.replacingOccurrences(of: "^endDate\\s+", with: "", options: .regularExpression)

        // Common patterns you might encounter:
        let candidates: [(DateFormatter, String)] = {
            var list: [(DateFormatter, String)] = []

            func df(
                _ format: String,
                tz: TimeZone? = nil,
                locale: Locale = Locale(identifier: "en_US_POSIX")
            ) -> DateFormatter {
                let f = DateFormatter()
                f.locale = locale
                f.dateFormat = format
                f.timeZone = tz
                return f
            }

            // Example with “at”, timezone suffix like "UTC-4"
            list.append(
                (
                    df("MMMM d, yyyy 'at' h:mm:ss a 'UTC'XXXXX"),
                    "MMMM d, yyyy at h:mm:ss a 'UTC'XXXXX"
                )
            )
            list.append(
                (df("MMMM d, yyyy 'at' h:mm a 'UTC'XXXXX"), "MMMM d, yyyy at h:mm a 'UTC'XXXXX")
            )

            // Without the word “at”
            list.append(
                (df("MMMM d, yyyy h:mm:ss a 'UTC'XXXXX"), "MMMM d, yyyy h:mm:ss a 'UTC'XXXXX")
            )
            list.append((df("MMMM d, yyyy h:mm a 'UTC'XXXXX"), "MMMM d, yyyy h:mm a 'UTC'XXXXX"))

            // Fallback: no explicit timezone -> assume system (or set to Eastern)
            let eastern = TimeZone(identifier: "America/New_York")
            list.append(
                (df("MMMM d, yyyy 'at' h:mm:ss a", tz: eastern), "MMMM d, yyyy at h:mm:ss a")
            )
            list.append((df("MMMM d, yyyy 'at' h:mm a", tz: eastern), "MMMM d, yyyy at h:mm a"))

            return list
        }()

        for (formatter, _) in candidates {
            if let d = formatter.date(from: s) {
                return d
            }
        }

        // Try ISO8601 as last resort
        if let d = ISO8601DateFormatter().date(from: s) {
            return d
        }

        print("[FirestoreManager] Failed to parse endDate string: \(raw)")
        return nil
    }
}
