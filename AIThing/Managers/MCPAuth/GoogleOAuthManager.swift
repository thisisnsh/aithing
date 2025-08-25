//
//  GoogleOAuthManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/25/25.
//

import Firebase
import Foundation
import GoogleSignIn
import SwiftUI

@MainActor
class GoogleOAuthManager: ObservableObject {
    @Published var user: GIDGoogleUser?

    func generateToken() async {
        do {
            // Refresh token if user already exists
            if let user = self.user {
                do {
                    try await user.refreshTokensIfNeeded()
                    return
                } catch {}
            }

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
                withPresenting: presentingWindow,
                hint: nil,
                additionalScopes: [
                    "https://www.googleapis.com/auth/userinfo.email",
                    "https://www.googleapis.com/auth/chat.messages",
                    "https://www.googleapis.com/auth/gmail.labels",
                    "https://www.googleapis.com/auth/chat.spaces",
                    "https://www.googleapis.com/auth/presentations.readonly",
                    "https://www.googleapis.com/auth/tasks",
                    "https://www.googleapis.com/auth/forms.responses.readonly",
                    "https://www.googleapis.com/auth/userinfo.profile",
                    "https://www.googleapis.com/auth/spreadsheets",
                    "https://www.googleapis.com/auth/calendar",
                    "https://www.googleapis.com/auth/presentations",
                    "https://www.googleapis.com/auth/drive.file",
                    "https://www.googleapis.com/auth/documents", "openid",
                    "https://www.googleapis.com/auth/spreadsheets.readonly",
                    "https://www.googleapis.com/auth/tasks.readonly",
                    "https://www.googleapis.com/auth/gmail.readonly",
                    "https://www.googleapis.com/auth/cse",
                    "https://www.googleapis.com/auth/chat.messages.readonly",
                    "https://www.googleapis.com/auth/gmail.send",
                    "https://www.googleapis.com/auth/documents.readonly",
                    "https://www.googleapis.com/auth/forms.body",
                    "https://www.googleapis.com/auth/calendar.events",
                    "https://www.googleapis.com/auth/gmail.compose",
                    "https://www.googleapis.com/auth/calendar.readonly",
                    "https://www.googleapis.com/auth/gmail.modify",
                    "https://www.googleapis.com/auth/forms.body.readonly",
                    "https://www.googleapis.com/auth/drive",
                    "https://www.googleapis.com/auth/drive.readonly",
                ]
            )

            user = result.user
        } catch {
            print("Get token: \(error.localizedDescription)")
            user = nil
        }
    }

    func resetToken() {
        user = nil
    }
}
