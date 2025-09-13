//
//  AsanaOAuthManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 9/9/25.
//

import AppKit
import AuthenticationServices
import Foundation
import OAuthSwift
import os

@MainActor
final class AsanaOAuthManager: ObservableObject {
    @Published var user: AsanaUser?
    @Published var enabled: Set<AsanaTool> = []

    private let logger = Logger(
        subsystem: "com.thisisnsh.mac.AIThing",
        category: "AsanaOAuthManager"
    )

    private let issuer = URL(string: "https://mcp.asana.com")!
    private var authorizationEndpoint: URL { issuer.appending(path: "authorize") }
    private var tokenEndpoint: URL { issuer.appending(path: "token") }
    private var registrationEndpoint: URL { issuer.appending(path: "register") }

    private let callbackScheme = "http"
    private var callbackURLString = ""
    private var oauth: OAuth2Swift?

    /// Generates (or refreshes) a Bearer token and returns a hydrated `AsanaUser?`.
    /// - Parameter refresh: when true, tries to refresh first if a refresh token is available.
    func generateToken(refresh: Bool) async -> AsanaUser? {
        do {
            let loopback = OAuthLoopback()
            let redirectURL = try await loopback.start { code, state in
                Task {
                    if let cred = try await self.getAccessToken(code: code) {
                        let profile = AsanaUser(accessToken: cred.credential.oauthToken)
                        let merged = self.merge(profile: profile, credential: cred.credential)
                        self.user = merged
                    } else {
                        throw AsanaOAuthError.cancelled
                    }
                }
            }

            callbackURLString = redirectURL.absoluteString
            let client = try await registerClient()
            let oauth = makeOAuth(client: client)
            self.oauth = oauth

            let _ = try await authorizeInteractively()
            return self.user
        } catch {
            logger.error("Asana generateToken error: \(error.localizedDescription)")
            self.user = nil
            return nil
        }
    }

    func resetToken() {
        user = nil
    }

    enum AsanaTool: String, CaseIterable, Identifiable {
        case search = "Search"
        case pages = "Pages"
        case databases = "Databases"
        case comments = "Comments"

        var id: String { rawValue }
    }

    let toolScopesMap: [AsanaTool: [String]] = [
        .search: [],
        .pages: [],
        .databases: [],
        .comments: [],
    ]

    let toolCapabilities: [AsanaTool: [String]] = [
        .search: [
            "search",
            "fetch",
        ],
        .pages: [
            "notion-create-pages",
            "notion-update-page",
            "notion-move-pages",
            "notion-duplicate-page",
        ],
        .databases: [
            "notion-create-database",
            "notion-update-database",
        ],
        .comments: [
            "notion-create-comment",
            "notion-get-comments",
        ],
    ]

    func enabledCapabilities() -> [String] {
        var s = enabled.flatMap { toolCapabilities[$0] ?? [] }
        // Default
        s.append(contentsOf: [
            "notion-get-self",
            "notion-get-users",
            "notion-get-user",
            "notion-get-teams",
        ])
        return s
    }
}

// MARK: - Helpers
extension AsanaOAuthManager {
    private func tokenIsValid(_ user: AsanaUser) -> Bool {
        guard let exp = user.expiresAt else { return !user.accessToken.isEmpty }
        // Renew 60 seconds early
        return Date() < exp.addingTimeInterval(-60)
    }

    private func merge(profile: AsanaUser, credential: OAuthSwiftCredential) -> AsanaUser {
        var merged = profile
        merged.accessToken = credential.oauthToken
        if !credential.oauthRefreshToken.isEmpty {
            merged.refreshToken = credential.oauthRefreshToken
        }
        merged.expiresAt = credential.oauthTokenExpiresAt
        return merged
    }
}

extension AsanaOAuthManager {
    struct RegisteredClient: Codable {
        let client_id: String
        let client_secret: String?
        // Additional fields from RFC 7591 may exist; ignore for now
    }

    private func registerClient() async throws -> RegisteredClient {
        var req = URLRequest(url: registrationEndpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "application_type": "native",
            "client_name": "AIThing (macOS)",
            "client_uri": "https://aithing.dev",
            "redirect_uris": [callbackURLString],
            "grant_types": ["authorization_code", "refresh_token"],
            "response_types": ["code"],
            "token_endpoint_auth_method": "client_secret_post",
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AsanaOAuthError.registrationFailed
        }
        let registered = try JSONDecoder().decode(RegisteredClient.self, from: data)

        return registered
    }

    private func makeOAuth(client: RegisteredClient) -> OAuth2Swift {
        let oauth = OAuth2Swift(
            consumerKey: client.client_id,
            consumerSecret: client.client_secret ?? "",
            authorizeUrl: authorizationEndpoint.absoluteString,
            accessTokenUrl: tokenEndpoint.absoluteString,
            responseType: "code"
        )
        oauth.accessTokenBasicAuthentification = false
        oauth.authorizeURLHandler = MyASWebAuthURLHandler(callbackScheme: callbackScheme)
        return oauth
    }

    private func authorizeInteractively() async throws -> Bool {
        guard let callbackURL = URL(string: callbackURLString) else {
            throw AtlassianOAuthError.notConfigured
        }

        return try await withCheckedThrowingContinuation { continuation in
            let _ = self.oauth!.authorize(
                withCallbackURL: callbackURL,
                scope: "",
                state: UUID().uuidString,
                parameters: [:]
            ) { result in
                continuation.resume(returning: true)
            }
        }
    }

    private func getAccessToken(code: String) async throws -> OAuthSwift.TokenSuccess? {
        guard let oauth else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            let _ = oauth.postOAuthAccessTokenWithRequestToken(
                byCode: code,
                callbackURL: URL(string: callbackURLString)!,
                headers: nil,
                completionHandler: { result in
                    switch result {
                    case .success(let success):
                        continuation.resume(returning: success)
                    case .failure(let err):
                        self.logger.error("Asana get token failed: \(err.localizedDescription)")
                        continuation.resume(returning: nil)  // fall back to full auth
                    }
                }
            )
        }
    }

    private func renewAccessToken(refreshToken: String) async throws -> OAuthSwift.TokenSuccess? {
        guard let oauth else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            let _ = oauth.renewAccessToken(withRefreshToken: refreshToken) { result in
                switch result {
                case .success(let success):
                    continuation.resume(returning: success)
                case .failure(let err):
                    self.logger.error("Asana refresh failed: \(err.localizedDescription)")
                    continuation.resume(returning: nil)  // fall back to full auth
                }
            }
        }
    }
}

// MARK: - Public model
public struct AsanaUser: Codable, Equatable {
    // Tokens
    public var accessToken: String
    public var refreshToken: String?
    public var expiresAt: Date?

    // Profile
    public var id: String?
    public var name: String?
    public var email: String?
    public var avatarURL: URL?
}

// MARK: - Errors
enum AsanaOAuthError: LocalizedError {
    case notConfigured
    case registrationFailed
    case authorizationFailed
    case cancelled
    case invalidHTTPResponse
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Asana OAuth not configured."
        case .registrationFailed: return "Client registration failed."
        case .authorizationFailed: return "Authorization failed."
        case .cancelled: return "User cancelled."
        case .invalidHTTPResponse: return "Invalid response from Asana."
        case .decodeFailed: return "Failed to decode Asana response."
        }
    }
}

extension String {

    var parametersFromQueryString: [String: String] {
        return dictionaryBySplitting("&", keyValueSeparator: "=")
    }

    /// Encodes url string making it ready to be passed as a query parameter. This encodes pretty much everything apart from
    /// alphanumerics and a few other characters compared to standard query encoding.
    var urlEncoded: String {
        let customAllowedSet = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        )
        return self.addingPercentEncoding(withAllowedCharacters: customAllowedSet)!
    }

    var urlQueryEncoded: String? {
        return self.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
    }

    /// Returns new url query string by appending query parameter encoding it first, if specified.
    func urlQueryByAppending(
        parameter name: String,
        value: String,
        encode: Bool = true,
        _ encodeError: ((String, String) -> Void)? = nil
    ) -> String? {
        if value.isEmpty {
            return self
        } else if let value = encode ? value.urlQueryEncoded : value {
            return "\(self)\(self.isEmpty ? "" : "&")\(name)=\(value)"
        } else {
            encodeError?(name, value)
            return nil
        }
    }

    /// Returns new url string by appending query string at the end.
    func urlByAppending(query: String) -> String {
        return "\(self)\(self.contains("?") ? "&" : "?")\(query)"
    }

    fileprivate func dictionaryBySplitting(_ elementSeparator: String, keyValueSeparator: String)
        -> [String: String]
    {
        var string = self

        if hasPrefix(elementSeparator) {
            string = String(dropFirst(1))
        }

        var parameters = [String: String]()

        let scanner = Scanner(string: string)

        while !scanner.isAtEnd {
            if #available(iOS 13.0, tvOS 13.0, OSX 10.15, watchOS 6.0, *) {
                let key = scanner.scanUpToString(keyValueSeparator)
                _ = scanner.scanString(keyValueSeparator)

                let value = scanner.scanUpToString(elementSeparator)
                _ = scanner.scanString(elementSeparator)

                if let key = key {
                    if let value = value {
                        if key.contains(elementSeparator) {
                            var keys = key.components(separatedBy: elementSeparator)
                            if let key = keys.popLast() {
                                parameters.updateValue(value, forKey: String(key))
                            }
                            for flag in keys {
                                parameters.updateValue("", forKey: flag)
                            }
                        } else {
                            parameters.updateValue(value, forKey: key)
                        }
                    } else {
                        parameters.updateValue("", forKey: key)
                    }
                }
            } else {
                var key: NSString?
                scanner.scanUpTo(keyValueSeparator, into: &key)
                scanner.scanString(keyValueSeparator, into: nil)

                var value: NSString?
                scanner.scanUpTo(elementSeparator, into: &value)
                scanner.scanString(elementSeparator, into: nil)
                if let key = key as String? {
                    if let value = value as String? {
                        if key.contains(elementSeparator) {
                            var keys = key.components(separatedBy: elementSeparator)
                            if let key = keys.popLast() {
                                parameters.updateValue(value, forKey: String(key))
                            }
                            for flag in keys {
                                parameters.updateValue("", forKey: flag)
                            }
                        } else {
                            parameters.updateValue(value, forKey: key)
                        }
                    } else {
                        parameters.updateValue("", forKey: key)
                    }
                }
            }
        }

        return parameters
    }

    public var headerDictionary: OAuthSwift.Headers {
        return dictionaryBySplitting(",", keyValueSeparator: "=")
    }

    var safeStringByRemovingPercentEncoding: String {
        return self.removingPercentEncoding ?? self
    }

    mutating func dropLast() {
        self.remove(at: self.index(before: self.endIndex))
    }

    subscript(bounds: CountableClosedRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start...end])
    }

    subscript(bounds: CountableRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start..<end])
    }
}

extension String.Encoding {

    var charset: String {
        let charset = CFStringConvertEncodingToIANACharSetName(
            CFStringConvertNSStringEncodingToEncoding(self.rawValue)
        )
        // swiftlint:disable:next force_cast superfluous_disable_command
        return charset! as String
    }

}
