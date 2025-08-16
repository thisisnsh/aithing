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

class FirestoreManager: ObservableObject {
    let db = Firestore.firestore()

    func getBreakglass() async -> Bool {
        do {
            let snapshot = try await db.collection("System").document("Configs-1.4").getDocument()
            guard let data = snapshot.data() else { return false }
            guard let breakglass = data["breakglass"] as? Bool else { return false }
            return breakglass
        } catch {
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
            return expired
        } catch {
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
            return apiKeyAnthropic
        } catch {
            print(
                "[FirestoreManager] Error fetching apiKeyAnthropic: \(error.localizedDescription)"
            )
            return ""
        }
    }

    private func _getProfile(user: AppUser) async -> Profile? {
        let id = user.uid

        do {
            let snapshot = try await db.collection("Profiles").document(id).getDocument()
            if let profile = try? snapshot.data(as: Profile.self) {
                // print("Profile loaded: \(profile)")
                return profile
            }

            // print("[FirestoreManager] Failed to find profile for ID \(id)")
            return nil
        } catch {
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

        let profile = Profile(
            id: id,
            name: user.displayName,
            email: user.email ?? "",  // todo: handle properly
            creditsTotal: 100,
            creditsUsed: 0,
            blocked: false,
            apiKeyAnthropic: apiKeyAnthropic,
            apiKeyOpenAI: ""
        )

        do {
            try db.collection("Profiles").document(id).setData(from: profile)
            return profile
        } catch {
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
        } catch {
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

            // Sort: first by order, then by title if order is equal
            return models.sorted {
                if $0.order == $1.order {
                    return $0.title.localizedCompare($1.title) == .orderedAscending
                }
                return $0.order < $1.order
            }
        } catch {
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
}
