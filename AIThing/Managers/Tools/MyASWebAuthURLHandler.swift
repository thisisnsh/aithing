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

/// Minimal ASWebAuthenticationSession-based handler for macOS.
final class MyASWebAuthURLHandler: NSObject, OAuthSwiftURLHandlerType,
    ASWebAuthenticationPresentationContextProviding
{
    private let callbackScheme: String
    private var authSession: ASWebAuthenticationSession?

    init(callbackScheme: String) {
        self.callbackScheme = callbackScheme
    }

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

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // best available window
        return NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? .init()
    }
}
