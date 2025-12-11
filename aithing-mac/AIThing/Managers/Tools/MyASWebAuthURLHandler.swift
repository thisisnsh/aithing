//
//  MyASWebAuthURLHandler.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 9/13/25.
//

import AuthenticationServices
import Foundation
import OAuthSwift
import os

// MARK: - Web Authentication Handler

/// Handles OAuth web authentication flows using ASWebAuthenticationSession.
///
/// Provides a minimal implementation of OAuthSwift's URL handler protocol
/// for macOS, presenting the authentication UI in a web browser session.
final class MyASWebAuthURLHandler: NSObject, OAuthSwiftURLHandlerType,
    ASWebAuthenticationPresentationContextProviding
{
    private let callbackScheme: String
    private var authSession: ASWebAuthenticationSession?

    /// Initializes the handler with a custom callback URL scheme.
    ///
    /// - Parameter callbackScheme: The URL scheme used for OAuth callbacks
    init(callbackScheme: String) {
        self.callbackScheme = callbackScheme
    }

    /// Handles the OAuth URL by presenting a web authentication session.
    ///
    /// Opens the authorization URL in a browser session and waits for
    /// the callback URL to be triggered.
    ///
    /// - Parameter url: The OAuth authorization URL to open
    func handle(_ url: URL) {
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) {
            callbackURL,
            error in
            if let url = callbackURL {
                OAuthSwift.handle(url: url)
            } else {
                OAuthSwift.handle(url: URL(filePath: "Error")!)
            }
        }
        session.presentationContextProvider = self
        // set to true if you want no shared browser state
        // session.prefersEphemeralWebBrowserSession = true
        self.authSession = session
        _ = session.start()
    }

    // MARK: ASWebAuthenticationPresentationContextProviding (macOS)

    /// Provides the window anchor for presenting the authentication session.
    ///
    /// Returns the key window if available, otherwise the first available window,
    /// or creates a new window if none exist.
    ///
    /// - Parameter session: The web authentication session
    /// - Returns: The presentation anchor window
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // best available window
        return NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? .init()
    }
}
