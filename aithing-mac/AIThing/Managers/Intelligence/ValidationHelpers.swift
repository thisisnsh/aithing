//
//  ValidationHelpers.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 12/5/25.
//

import Foundation

// MARK: - Public API

/// Validates Firebase configuration before making a model call.
///
/// Checks for breakglass and expiration flags that would prevent
/// the app from functioning properly.
///
/// - Parameter context: The validation context with dependencies
/// - Returns: `true` if validation passes, `false` if blocked
func validateFirebaseConfigs(context: ValidationContext) async -> Bool {
    // Skip validation if Firebase isn't configured
    guard FirebaseConfiguration.shared.isConfigured else {
        return true
    }
    
    // Check if version is breakglassed
    if await context.firestoreManager.getBreakglass() {
        await handleBreakglass(context: context)
        return false
    }

    // Check if version is expired
    if await context.firestoreManager.getExpired() {
        await handleExpired(context: context)
        return false
    }
    
    return true
}

/// Validates user login status before making a model call.
///
/// Verifies that the user is signed in and their profile is not blocked.
/// Returns a mock user when Firebase is not configured.
///
/// - Parameter context: The login validation context with dependencies
/// - Returns: `AppUser` if validation passes, `nil` if blocked or not logged in
func validateLogin(context: LoginValidationContext) async -> AppUser? {
    // Skip login validation if Firebase isn't configured - return a mock user
    guard FirebaseConfiguration.shared.isConfigured else {
        return AppUser(uid: "local_user", displayName: "Local User", email: nil)
    }
    
    let authState = await MainActor.run { context.loginManager.authState }

    switch authState {
    case .signedIn(let user):
        return await validateSignedInUser(user: user, context: context)
    default:
        await handleNotSignedIn(context: context)
        return nil
    }
}

// MARK: - Private Helpers

/// Handles the breakglass blocked state.
///
/// - Parameter context: The validation context
private func handleBreakglass(context: ValidationContext) async {
    context.setIsThinking(false)
    await context.animateOutput(
        """
        This version has been disabled due to an internal issue.
        We apologize for the inconvenience. The app will be re-enabled soon.
        For updates, please contact help@aithing.dev.
        """
    )
}

/// Handles the version expired state.
///
/// - Parameter context: The validation context
private func handleExpired(context: ValidationContext) async {
    context.setIsThinking(false)
    await context.animateOutput(
        """
        Current version has expired.
        Please [upgrade the version](https://aithing.dev/upgrade) to enjoy new features and continue using the app.
        """
    )
}

/// Validates a signed-in user's profile and blocked status.
///
/// - Parameters:
///   - user: The signed-in user
///   - context: The login validation context
/// - Returns: The user if valid, nil otherwise
private func validateSignedInUser(
    user: AppUser,
    context: LoginValidationContext
) async -> AppUser? {
    if let profile = await context.firestoreManager.getProfile(user: user) {
        // Check if profile is blocked
        if profile.blocked {
            await handleBlockedUser(context: context)
            return nil
        }
        
        return user
    }
    
    await handleProfileError(context: context)
    return nil
}

/// Handles the blocked user state.
///
/// - Parameter context: The login validation context
private func handleBlockedUser(context: LoginValidationContext) async {
    context.setIsThinking(false)
    await context.animateOutput(
        """
        You access has been disabled. We apologize for the inconvenience.
        Please contact help@aithing.dev for more information.
        """
    )
}

/// Handles profile fetch error state.
///
/// - Parameter context: The login validation context
private func handleProfileError(context: LoginValidationContext) async {
    context.setIsThinking(false)
    await context.animateOutput(
        """
        Something went wrong. Please log out and log in again. 
        Report issue at help@aithing.dev
        """
    )
}

/// Handles not signed in state.
///
/// - Parameter context: The login validation context
private func handleNotSignedIn(context: LoginValidationContext) async {
    context.setIsThinking(false)
    await context.animateOutput(
        "Please log in from Settings to continue. [How?](https://aithing.dev/getstarted)"
    )
}
