//
//  OAuthManagerProtocol.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 12/5/25.
//

import Foundation

/// Protocol that defines the common interface for OAuth managers.
/// Implementations should handle token generation, refresh, and reset functionality.
protocol OAuthManagerProtocol: ObservableObject {
    /// The type of token this manager produces
    associatedtype TokenType
    
    /// Generates or refreshes an OAuth token
    /// - Parameter refresh: If true, attempts to refresh existing token before full auth
    /// - Returns: The token if successful, nil otherwise
    func generateToken(refresh: Bool) async -> TokenType?
    
    /// Resets/clears the current token
    func resetToken()
    
    /// Whether this OAuth manager has any tools enabled
    var hasEnabledTools: Bool { get }
}

