//
//  GoogleAuthManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 12/5/25.
//

import Firebase
import Foundation
import GoogleSignIn
import SwiftUI
import os

// MARK: - Google Auth Manager

/// Manages Google OAuth authentication flow.
/// Handles token generation, refresh, and scope management.
@MainActor
class GoogleAuthManager: ObservableObject, OAuthManagerProtocol {
    typealias TokenType = GIDGoogleUser

    // MARK: - Published Properties

    @Published var user: GIDGoogleUser?
    @Published var enabled: Set<GoogleTool> = getGoogleTools()

    var hasEnabledTools: Bool { !enabled.isEmpty }

    // MARK: - Private Properties

    private var generating = false

    // MARK: - OAuthManagerProtocol

    /// Generates or refreshes a Google OAuth token
    /// - Parameter refresh: When true, attempts to refresh existing token first
    /// - Returns: The authenticated user if successful
    func generateToken(refresh: Bool) async -> GIDGoogleUser? {
        guard !generating else { return nil }
        generating = true
        defer { generating = false }

        do {
            if refresh, let user = self.user {
                do {
                    try await user.refreshTokensIfNeeded()
                    return user
                } catch {
                    // Fall through to full auth
                }
            }

            guard let presentingWindow = NSApplication.shared.keyWindow else {
                throw LoginError.noPresentingWindow
            }

            guard let clientID = FirebaseApp.app()?.options.clientID else {
                throw LoginError.noClientID
            }

            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config

            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presentingWindow,
                hint: nil,
                additionalScopes: additionalScopes()
            )

            user = result.user
            return user
        } catch {
            logger.error("Google token generation error: \(error.localizedDescription)")
            user = nil
            return user
        }
    }

    /// Clears the current authentication
    func resetToken() {
        user = nil
    }

    // MARK: - Scope Management

    /// Returns OAuth scopes based on enabled tools
    func additionalScopes() -> [String] {
        var scopes = Set(enabled.flatMap { GoogleToolModels.toolScopesMap[$0] ?? [] })

        // Add base scopes
        for scope in GoogleToolModels.ScopeGroups.base {
            scopes.insert(scope)
        }

        return Array(scopes)
    }

    /// Returns API capabilities based on enabled tools
    func enabledCapabilities() -> [String] {
        enabled.flatMap { GoogleToolModels.toolCapabilities[$0] ?? [] }
    }
}
