//
//  GitHubOAuthManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/25/25.
//

import Foundation
import OAuthSwift

@MainActor
class GitHubOAuthManager: ObservableObject {
    @Published var enabled: Bool = false

}
