//
//  LoginManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/8/25.
//

import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import SwiftUI
import os

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
}

enum AuthState {
    case loading
    case signedOut
    case signedIn(AppUser)
    case error(String)
}

@MainActor
class LoginManager: ObservableObject {
    @Published var authState: AuthState = .loading
    @Published var isLoading = false

    private var authStateListener: AuthStateDidChangeListenerHandle?
    let logger = Logger(subsystem: "com.thisisnsh.mac.AIThing", category: "LoginManager")

    init() {
        setupAuthStateListener()
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }

            if let user = user {
                let appUser = AppUser(from: user)
                self.authState = .signedIn(appUser)
            } else {
                self.authState = .signedOut
            }
        }
    }

    func signInWithGoogle() async {
        isLoading = true

        do {
            // Get the presenting window (required for macOS)
            guard let presentingWindow = NSApplication.shared.keyWindow else {
                throw LoginError.noPresentingWindow
            }
            // Configure Google Sign-In
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                throw LoginError.noClientID
            }

            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config

            // Perform Google Sign-In
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presentingWindow
            )
            let user = result.user
            // Get ID token and access token
            guard let idToken = user.idToken?.tokenString else {
                throw LoginError.noIDToken
            }

            let accessToken = user.accessToken.tokenString

            // Create Firebase credential
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )
            // Sign in to Firebase
            let authResult = try await Auth.auth().signIn(with: credential)
            logger.debug("Successfully signed in user: \(authResult.user.email ?? "No email")")

        } catch let error as LoginError {
            authState = .error(error.localizedDescription)
        } catch {
            authState = .error("Sign in failed: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func signOut() {
        isLoading = true

        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            authState = .signedOut
        } catch {
            authState = .error("Sign out failed: \(error.localizedDescription)")
        }

        isLoading = false
    }

    var isSignedIn: Bool {
        if case .signedIn = authState {
            return true
        }
        return false
    }

    var currentUser: AppUser? {
        if case .signedIn(let user) = authState {
            return user
        }
        return nil
    }
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

extension NSApplication {
    var keyWindow: NSWindow? {
        return NSApplication.shared.windows.first { $0.isKeyWindow }
    }
}
