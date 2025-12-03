//
//  ValidationHelpers.swift
//  AIThing
//
//  Helper functions for validating Firebase configs and login.
//

import Foundation

func validateFirebaseConfigs(
    firestoreManager: FirestoreManager,
    setIsThinking: (Bool) -> Void,
    animateOutput: (String) async -> Void
) async -> Bool {
    // Skip validation if Firebase isn't configured
    guard FirebaseConfiguration.shared.isConfigured else {
        return true
    }
    
    // Check if version is breakglassed
    if await firestoreManager.getBreakglass() {
        setIsThinking(false)
        await animateOutput(
            """
            This version has been disabled due to an internal issue.
            We apologize for the inconvenience. The app will be re-enabled soon.
            For updates, please contact help@aithing.dev.
            """
        )
        AnalyticsManager.shared
            .customEvent(
                view: .IntelligenceManager,
                primary: .query,
                secondary: "breakglass",
                sev: .error
            )
        return false
    }

    // Check if version is expired
    if await firestoreManager.getExpired() {
        setIsThinking(false)
        await animateOutput(
            """
            Current version has expired.
            Please [upgrade the version](https://aithing.dev/upgrade) to enjoy new features and continue using the app.
            """
        )
        AnalyticsManager.shared
            .customEvent(
                view: .IntelligenceManager,
                primary: .query,
                secondary: "version expired",
                sev: .error
            )
        return false
    }
    return true
}

func validateLogin(
    loginManager: LoginManager,
    firestoreManager: FirestoreManager,
    setIsThinking: (Bool) -> Void,
    animateOutput: (String) async -> Void
) async -> AppUser? {
    // Skip login validation if Firebase isn't configured - return a mock user
    guard FirebaseConfiguration.shared.isConfigured else {
        return AppUser(uid: "local_user", displayName: "Local User", email: nil)
    }
    
    let authState = await MainActor.run { loginManager.authState }

    switch authState {
    case .signedIn(let user):
        if let profile = await firestoreManager.getProfile(user: user) {
            // Check if profile is blocked
            if profile.blocked {
                setIsThinking(false)
                await animateOutput(
                    """
                    You access has been disabled. We apologize for the inconvenience.
                    Please contact help@aithing.dev for more information.
                    """
                )
                AnalyticsManager.shared
                    .customEvent(
                        view: .IntelligenceManager,
                        primary: .query,
                        secondary: "version blocked",
                        sev: .error
                    )
                return nil
            }

            AnalyticsManager.shared.setUserId(user.uid)
            return user
        }

        setIsThinking(false)
        await animateOutput(
            """
            Something went wrong. Please log out and log in again. 
            Report issue at help@aithing.dev
            """
        )
        AnalyticsManager.shared
            .customEvent(
                view: .IntelligenceManager,
                primary: .query,
                secondary: "profile error",
                sev: .error
            )
        return nil
    default:
        setIsThinking(false)
        await animateOutput(
            "Please log in from Settings to continue. [How?](https://aithing.dev/getstarted)"
        )
        AnalyticsManager.shared
            .customEvent(
                view: .IntelligenceManager,
                primary: .query,
                secondary: "no login",
                sev: .error
            )
        return nil
    }
}

