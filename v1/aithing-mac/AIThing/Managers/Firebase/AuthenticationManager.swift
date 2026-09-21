//
//  AuthenticationManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/8/25.
//

import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import SwiftUI
import os

// MARK: - Authentication Manager

/// Manages user authentication state and sign-in/sign-out operations.
/// Supports Google Sign-In via Firebase Authentication.
@MainActor
final class AuthenticationManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var authState: AuthState = .loading
    @Published private(set) var isLoading = false

    // MARK: - Properties

    private var authStateListener: AuthStateDidChangeListenerHandle?

    private var isFirebaseEnabled: Bool {
        FirebaseConfiguration.shared.isConfigured
    }

    // MARK: - Computed Properties

    var isSignedIn: Bool {
        if case .signedIn = authState { return true }
        return false
    }

    var currentUser: AppUser? {
        if case .signedIn(let user) = authState { return user }
        return nil
    }

    // MARK: - Initialization

    init() {
        setupAuthStateListener()
    }

    deinit {
        // Note: Inline cleanup because deinit is nonisolated and can't call @MainActor methods
        if let listener = authStateListener, FirebaseConfiguration.shared.isConfigured {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Public Methods

    /// Initiates Google Sign-In flow
    func signInWithGoogle() async {
        guard isFirebaseEnabled else {
            handleFirebaseNotConfigured()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let credential = try await performGoogleSignIn()
            try await signInToFirebase(with: credential)
        } catch let error as LoginError {
            authState = .error(error.localizedDescription)
        } catch {
            authState = .error("Sign in failed: \(error.localizedDescription)")
        }
    }

    /// Signs out the current user
    func signOut() {
        guard isFirebaseEnabled else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            authState = .signedOut
        } catch {
            authState = .error("Sign out failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    private func setupAuthStateListener() {
        guard isFirebaseEnabled else {
            authState = .signedOut
            return
        }

        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }

            if let user {
                self.authState = .signedIn(AppUser(from: user))
            } else {
                self.authState = .signedOut
            }
        }
    }

    private func handleFirebaseNotConfigured() {        
        authState = .error(
            "Firebase is not configured. Please add valid credentials to GoogleService-Info.plist"
        )
    }

    private func performGoogleSignIn() async throws -> AuthCredential {
        guard let presentingWindow = NSApplication.shared.keyWindow else {
            throw LoginError.noPresentingWindow
        }

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw LoginError.noClientID
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingWindow)

        guard let idToken = result.user.idToken?.tokenString else {
            throw LoginError.noIDToken
        }

        return GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
    }

    private func signInToFirebase(with credential: AuthCredential) async throws {
        let authResult = try await Auth.auth().signIn(with: credential)
        logger.info("Successfully signed in user: \(authResult.user.email ?? "No email")")
    }
}

// MARK: - Type Alias for backward compatibility

typealias LoginManager = AuthenticationManager
