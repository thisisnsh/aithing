//
//  NotchView+Agents.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 10/31/25.
//

import SwiftUI

// MARK: - AI Agents
extension NotchView {
    func refreshLocalAgents() async -> String {
        let newAgents = getAgentEntries()
        var allMatch = true

        if agents.count == newAgents.count {
            for (i, agent) in newAgents.enumerated() {
                let existing = agents[i]
                if existing.id != agent.id || existing.isEnabled != agent.isEnabled {
                    allMatch = false
                    break
                }
            }
        } else {
            allMatch = false
        }

        if allMatch {
            return ""
        }

        agents = newAgents
        allClientTools.removeAll()
        mcpAuthManagers.selfManagers.removeAll()

        let disconnectRc = await connectionManager.disconnect()
        if !disconnectRc.isEmpty {
            return "Failed to stop running agents: \(disconnectRc)"
        }

        var failure = ""

        for agent in agents {
            if !agent.isEnabled {
                continue
            }

            let name: String
            let primary: String
            var connectRc: String = ""

            switch agent.entry {
            case .url(let n, let url):
                name = n
                primary = url

                // URL is oauth ready if it has well known URLs
                // Skip connecting to oauth servers now, they will be connected later
                let oauth = await MCPAuthManager.hasWellKnownUrls(url: url)
                if oauth {
                    mcpAuthManagers.selfManagers[name] = MCPAuthManager(
                        server: McpServer(
                            id: name,
                            image: nil,
                            name: name,
                            url: url,
                            version: nil,
                            enabled: true,
                            custom: false
                        )
                    )
                    mcpAuthManagers.selfManagers[name]?.enabled = true
                    continue
                }

                connectRc = await connectionManager.connect(clientName: name, url: url, authToken: nil)

            case .urlWithToken(let n, let url, let token):
                name = n
                primary = url
                connectRc = await connectionManager.connect(clientName: name, url: url, authToken: token)

            case .command(let n, let command, let arguments):
                name = n
                primary = command
                connectRc = await connectionManager.connect(
                    clientName: name,
                    command: command,
                    args: arguments
                )
            }

            logger.debug("Added Agent: \(name)")

            if connectRc.isEmpty {
                let tools = await connectionManager.getTools(clientName: name, filter: [])
                allClientTools[name] = tools
            } else {
                failure += "\n\n\(name): \(connectRc)"
            }

        }

        if !failure.isEmpty {
            return "Failed to start agents\n" + failure
        }

        return ""
    }

    func getManagedAgents() async {
        let managedAgents = await firestoreManager.getManagedAgents()
        var allServerIds: [String] = []

        for server in managedAgents {
            if server.enabled ?? true == false { continue }

            if let id = server.id {
                allServerIds.append(id)

                if server.custom ?? false {
                    mcpAuthManagers.customManagers[id] = server
                    continue
                }

                if !mcpAuthManagers.managers.keys.contains(id) {
                    mcpAuthManagers.managers[id] = MCPAuthManager(server: server)
                }

                if let manager = mcpAuthManagers.managers[id] {
                    if manager.server.version != server.version {
                        mcpAuthManagers.managers[id] = MCPAuthManager(server: server)
                    }
                }

                // Always update image
                if let image = server.image {
                    mcpAuthManagers.managers[id]?.server.image = image
                }
            }
        }

        // Remove mcp servers that were added before but are no longer supported
        for key in mcpAuthManagers.managers.keys {
            if !allServerIds.contains(key) {
                mcpAuthManagers.managers.removeValue(forKey: key)
            }
        }
        for key in mcpAuthManagers.customManagers.keys {
            if !allServerIds.contains(key) {
                mcpAuthManagers.customManagers.removeValue(forKey: key)
            }
        }
    }

    func refreshManagedAgents(forceRefresh: Bool = true) async {
        await getManagedAgents()

        // Shared reconnect logic for any MCP OAuth manager.
        func handleManager(
            clientName: String,
            isEnabled: Bool,
            currentTokenAndExpiry: () -> (token: String?, expiry: Date?),
            generateToken: @escaping () async -> String?,
            url: @escaping () -> String,
            capabilities: @escaping () -> [String]
        ) async {
            guard isEnabled else {
                allClientTools.removeValue(forKey: clientName)
                return
            }

            let (accessToken, expiry) = currentTokenAndExpiry()

            var shouldRefreshToken = true
            if let expiry, !forceRefresh {
                // Token will expire in next 10 minutes
                shouldRefreshToken = Date().addingTimeInterval(10 * 60) >= expiry
            }

            var refreshedAccessToken: String? = nil

            if shouldRefreshToken, let newToken = await generateToken() {
                refreshedAccessToken = newToken
                logger.debug("\(clientName) RefreshedAccessToken \(String(describing: refreshedAccessToken))")

                // If token has been refreshed OR client does not exist
                if forceRefresh || accessToken != refreshedAccessToken
                    || !connectionManager.clientExists(clientName: clientName)
                {
                    _ = await connectionManager.reconnect(
                        clientName: clientName,
                        url: url(),
                        authToken: newToken
                    )

                    let tools = await connectionManager.getTools(
                        clientName: clientName,
                        filter: capabilities()
                    )
                    allClientTools[clientName] = tools

                    logger.debug("Refreshed \(clientName) with \(tools.count) tools")
                    logger.debug("\(clientName) Capabilities: \(tools)")
                }
            }
        }

        // Precompute the dynamic managers map (same as before).
        let keepingCurrent = mcpAuthManagers.managers.merging(mcpAuthManagers.selfManagers) {
            current,
            _ in current
        }

        await withTaskGroup(of: Void.self) { group in
            // Google
            group.addTask {
                let (token, expiry, capabilities) = await MainActor.run {
                    (
                        self.googleAuthManager.user?.accessToken.tokenString,
                        self.googleAuthManager.user?.accessToken.expirationDate,
                        self.googleAuthManager.enabledCapabilities()
                    )
                }

                let clientName = "managed_aithing_google"
                guard let server = await mcpAuthManagers.customManagers[clientName] else {
                    await MainActor.run { _ = allClientTools.removeValue(forKey: clientName) }
                    return
                }
                if server.enabled ?? false == false {
                    await MainActor.run { _ = allClientTools.removeValue(forKey: clientName) }
                    return
                }

                await handleManager(
                    clientName: clientName,
                    isEnabled: !self.googleAuthManager.enabled.isEmpty,
                    currentTokenAndExpiry: {
                        logger.debug("Google AccessToken \(String(describing: token))")
                        return (token, expiry)
                    },
                    generateToken: {
                        guard let user = await self.googleAuthManager.generateToken(refresh: true)
                        else { return nil }
                        return user.accessToken.tokenString
                    },
                    url: { server.url },
                    capabilities: { capabilities }
                )
            }

            // GitHub
            group.addTask {
                let (token, expiry, capabilities) = await MainActor.run {
                    (
                        self.githubAuthManager.user?.accessToken,
                        self.githubAuthManager.user?.expiresAt,
                        self.githubAuthManager.enabledCapabilities()
                    )
                }

                let clientName = "managed_aithing_github"
                guard let server = await mcpAuthManagers.customManagers[clientName] else {
                    await MainActor.run { _ = allClientTools.removeValue(forKey: clientName) }
                    return
                }
                if server.enabled ?? false == false {
                    await MainActor.run { _ = allClientTools.removeValue(forKey: clientName) }
                    return
                }

                await handleManager(
                    clientName: clientName,
                    isEnabled: !self.githubAuthManager.enabled.isEmpty,
                    currentTokenAndExpiry: {
                        logger.debug("Github AccessToken \(String(describing: token))")
                        return (token, expiry)
                    },
                    generateToken: {
                        guard let user = await self.githubAuthManager.generateToken(refresh: true)
                        else { return nil }
                        return user.accessToken
                    },
                    url: { server.url },
                    capabilities: { capabilities }
                )
            }

            // Other MCP OAuth managers
            for (clientName, agentOAuthManager) in keepingCurrent {
                let (token, expiry, url) = await MainActor.run {
                    (
                        agentOAuthManager.user?.accessToken,
                        agentOAuthManager.user?.expiresAt,
                        agentOAuthManager.server.url
                    )
                }

                if agentOAuthManager.enabled == false {
                    await MainActor.run { _ = allClientTools.removeValue(forKey: clientName) }
                    continue
                }

                group.addTask {
                    await handleManager(
                        clientName: clientName,
                        isEnabled: agentOAuthManager.enabled,
                        currentTokenAndExpiry: {
                            logger.debug("AccessToken \(String(describing: token))")
                            return (token, expiry)
                        },
                        generateToken: {
                            guard let user = await agentOAuthManager.generateToken(refresh: true)
                            else {
                                return nil
                            }
                            return user.accessToken
                        },
                        url: { url },
                        capabilities: { [] }
                    )
                }
            }
        }
    }
}

