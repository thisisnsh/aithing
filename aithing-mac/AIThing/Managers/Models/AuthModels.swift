//
//  AuthModels.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/8/25.
//

import FirebaseAuth
import Foundation

struct AppUser {
    let uid: String
    let email: String?
    let displayName: String?
    let photoURL: URL?

    init(from firebaseUser: User) {
        self.uid = firebaseUser.uid
        self.email = firebaseUser.email
        self.displayName = firebaseUser.displayName
        self.photoURL = firebaseUser.photoURL
    }
    
    /// Direct initializer for when Firebase isn't configured
    init(uid: String, displayName: String?, email: String?, photoURL: URL? = nil) {
        self.uid = uid
        self.displayName = displayName
        self.email = email
        self.photoURL = photoURL
    }
}

enum AuthState {
    case loading
    case signedOut
    case signedIn(AppUser)
    case error(String)
}

enum LoginError: LocalizedError {
    case noPresentingWindow
    case noClientID
    case configurationFailed
    case noIDToken

    var errorDescription: String? {
        switch self {
        case .noPresentingWindow:
            return "No presenting window available"
        case .noClientID:
            return "Firebase client ID not found"
        case .configurationFailed:
            return "Google Sign-In configuration failed"
        case .noIDToken:
            return "Failed to get ID token from Google"
        }
    }
}

