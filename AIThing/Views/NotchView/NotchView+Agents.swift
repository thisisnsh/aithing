//
//  NotchView+Agents.swift
//  AIThing
//
//  AI/Agent management extension for NotchView.
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
        mcpOAuthManagers.selfManagers.removeAll()

        let disconnectRc = await mcpManager.disconnect()
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
                let oauth = await McpOAuthManager.hasWellKnownUrls(url: url)
                if oauth {
                    mcpOAuthManagers.selfManagers[name] = McpOAuthManager(
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
                    mcpOAuthManagers.selfManagers[name]?.enabled = true
                    continue
                }

                connectRc = await mcpManager.connect(clientName: name, url: url, authToken: nil)

            case .urlWithToken(let n, let url, let token):
                name = n
                primary = url
                connectRc = await mcpManager.connect(clientName: name, url: url, authToken: token)

            case .command(let n, let command, let arguments):
                name = n
                primary = command
                connectRc = await mcpManager.connect(
                    clientName: name,
                    command: command,
                    args: arguments
                )
            }

            AnalyticsManager.shared.customEvent(
                view: .NotchView,
                primary: .agentLoad,
                secondary: "\(name) \(primary)",
                sev: .info
            )

            logger.debug("Added Agent: \(name)")

            if connectRc.isEmpty {
                let tools = await mcpManager.getTools(clientName: name, filter: [])
                allClientTools[name] = tools
            } else {
                failure += "\n\n\(name): \(connectRc)"
            }

        }

        if !failure.isEmpty {
            AnalyticsManager.shared
                .customEvent(view: .NotchView, primary: .agentLoad, secondary: failure, sev: .error)
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
                    mcpOAuthManagers.customManagers[id] = server
                    continue
                }

                if !mcpOAuthManagers.managers.keys.contains(id) {
                    mcpOAuthManagers.managers[id] = McpOAuthManager(server: server)
                }

                if let manager = mcpOAuthManagers.managers[id] {
                    if manager.server.version != server.version {
                        mcpOAuthManagers.managers[id] = McpOAuthManager(server: server)
                    }
                }

                // Always update image
                if let image = server.image {
                    mcpOAuthManagers.managers[id]?.server.image = image
                }
            }
        }

        // Remove mcp servers that were added before but are no longer supported
        for key in mcpOAuthManagers.managers.keys {
            if !allServerIds.contains(key) {
                mcpOAuthManagers.managers.removeValue(forKey: key)
            }
        }
        for key in mcpOAuthManagers.customManagers.keys {
            if !allServerIds.contains(key) {
                mcpOAuthManagers.customManagers.removeValue(forKey: key)
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
                logger.debug(
                    "\(clientName) RefreshedAccessToken \(String(describing: refreshedAccessToken))"
                )

                // If token has been refreshed OR client does not exist
                if forceRefresh || accessToken != refreshedAccessToken
                    || !mcpManager.clientExists(clientName: clientName)
                {
                    _ = await mcpManager.reconnect(
                        clientName: clientName,
                        url: url(),
                        authToken: newToken
                    )

                    let tools = await mcpManager.getTools(
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
        let keepingCurrent = mcpOAuthManagers.managers.merging(mcpOAuthManagers.selfManagers) {
            current,
            _ in current
        }

        await withTaskGroup(of: Void.self) { group in
            // Google
            group.addTask {
                let (token, expiry, capabilities) = await MainActor.run {
                    (
                        self.googleOAuthManager.user?.accessToken.tokenString,
                        self.googleOAuthManager.user?.accessToken.expirationDate,
                        self.googleOAuthManager.enabledCapabilities()
                    )
                }

                let clientName = "managed_aithing_google"
                guard let server = await mcpOAuthManagers.customManagers[clientName] else {
                    await MainActor.run { _ = allClientTools.removeValue(forKey: clientName) }
                    return
                }
                if server.enabled ?? false == false {
                    await MainActor.run { _ = allClientTools.removeValue(forKey: clientName) }
                    return
                }

                await handleManager(
                    clientName: clientName,
                    isEnabled: !self.googleOAuthManager.enabled.isEmpty,
                    currentTokenAndExpiry: {
                        self.logger.debug("Google AccessToken \(String(describing: token))")
                        return (token, expiry)
                    },
                    generateToken: {
                        guard let user = await self.googleOAuthManager.generateToken(refresh: true)
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
                        self.githubOAuthManager.user?.accessToken,
                        self.githubOAuthManager.user?.expiresAt,
                        self.githubOAuthManager.enabledCapabilities()
                    )
                }

                let clientName = "managed_aithing_github"
                guard let server = await mcpOAuthManagers.customManagers[clientName] else {
                    await MainActor.run { _ = allClientTools.removeValue(forKey: clientName) }
                    return
                }
                if server.enabled ?? false == false {
                    await MainActor.run { _ = allClientTools.removeValue(forKey: clientName) }
                    return
                }

                await handleManager(
                    clientName: clientName,
                    isEnabled: !self.githubOAuthManager.enabled.isEmpty,
                    currentTokenAndExpiry: {
                        self.logger.debug("Github AccessToken \(String(describing: token))")
                        return (token, expiry)
                    },
                    generateToken: {
                        guard let user = await self.githubOAuthManager.generateToken(refresh: true)
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
                            self.logger.debug("AccessToken \(String(describing: token))")
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

