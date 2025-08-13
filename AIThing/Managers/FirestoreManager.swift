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
    var name: String?
    var email: String
    var credits_total: Int
    var credits_remaining: Int
    var blocked: Bool?
}

class FirestoreManager: ObservableObject {
    let db = Firestore.firestore()

    func getBreakglass() async -> Bool {
        do {
            let snapshot = try await db.collection("System").document("Breakglass").getDocument()
            return snapshot.exists
        } catch {
            print(
                "[FirestoreManager] Error fetching Breakglass document: \(error.localizedDescription)"
            )
            return false
        }
    }

    func getProfile(profileId: String) async -> Profile? {
        do {
            let snapshot = try await db.collection("Profiles").document(profileId).getDocument()
            if let profile = try? snapshot.data(as: Profile.self) {
                print("Profile loaded: \(profile)")
                return profile
            }

            print("[FirestoreManager] Failed to decode profile for ID \(profileId)")
            return nil
        } catch {
            print(
                "[FirestoreManager] Error fetching profile for ID \(profileId): \(error.localizedDescription)"
            )
            return nil
        }
    }

    func createProfile(user: User) async -> Profile? {
        let id = user.uid

        if let profile = await getProfile(profileId: id) {
            return profile
        }

        let name = user.displayName
        let email = user.email
        let credit = 100

        let profile = Profile(
            name: user.displayName,
            email: user.email ?? "",  // todo: handle properly
            credits_total: 100,
            credits_remaining: 100,
            blocked: false
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

    func decrementCredits(profileId: String, by amount: Int) async {
        do {
            try await db.collection("Profiles").document(profileId).updateData([
                "credits": FieldValue.increment(Int64(-amount))
            ])
        } catch {
            print(
                "[FirestoreManager] Error decrementing credits by \(amount) for ID \(profileId): \(error.localizedDescription)"
            )
        }
    }

}
