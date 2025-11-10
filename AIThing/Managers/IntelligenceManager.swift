//
//  IntelligenceManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 11/10/25.
//

import Foundation

@MainActor
func callModel(
    tabId: String,
    query: String,
    getSelectedText: () -> String,
    setSelectedText: (String) -> Void,
    getSelectionEnabled: () -> Bool,
    setSelectionEnabled: (Bool) -> Void,
    getTabTitle: () -> String,
    setTabTitle: (String) -> Void,
    setDisplayQuery: (String) -> Void,
    setToolCall: (String) -> Void,
    getHistory: (String) async -> History?,
    storeHistory: (String, String, [[String: Any]]) async -> Void,
    setHistory: (History?) -> Void,
    setIsThinking: (Bool) -> Void,
    getModelInput: () -> [[String: Any]],
    appendModelInput: ([String: Any]) -> Void,
    getModelOutput: () -> String,
    setModelOutput: (String) -> Void,
    animateOutput: (String, Bool) async -> Void,
    getAllClientTools: () -> [String: [[String: Any]]],
    reconnectManagedAgents: () async -> Void,
    getModelContext: () -> [DroppedContent],
    clearModelContext: () -> Void,
    getManagedModels: () -> [ModelInfo],
    firestoreManager: FirestoreManager,
    loginManager: LoginManager,
    mcpManager: MCPManager,
) async -> Bool {
    // Check if version is breakglassed
    if await firestoreManager.getBreakglass() {
        setIsThinking(false)
        await animateOutput(
            """
            This version has been disabled due to an internal issue.
            We apologize for the inconvenience. The app will be re-enabled soon.
            For updates, please contact help@aithing.dev.
            """,
            true
        )
        AnalyticsManager.shared
            .customEvent(
                view: .IntelligenceView,
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
            """,
            true
        )
        AnalyticsManager.shared
            .customEvent(
                view: .IntelligenceView,
                primary: .query,
                secondary: "version expired",
                sev: .error
            )
        return false
    }

    var appUser: AppUser?
    switch loginManager.authState {
    case .signedIn(let user):
        if let profile = await firestoreManager.getProfile(user: user) {
            // Check if profile is blocked
            if profile.blocked {
                setIsThinking(false)
                await animateOutput(
                    """
                    You access has been disabled. We apologize for the inconvenience.
                    Please contact help@aithing.dev for more information.
                    """,
                    true
                )
                AnalyticsManager.shared
                    .customEvent(
                        view: .IntelligenceView,
                        primary: .query,
                        secondary: "version blocked",
                        sev: .error
                    )
                return false
            }

            appUser = user
            AnalyticsManager.shared.setUserId(user.uid)
            break
        }

        setIsThinking(false)
        await animateOutput(
            """
            Something went wrong. Please log out and log in again. 
            Report issue at help@aithing.dev
            """,
            true
        )
        AnalyticsManager.shared
            .customEvent(
                view: .IntelligenceView,
                primary: .query,
                secondary: "profile error",
                sev: .error
            )
        return false
    default:
        setIsThinking(false)
        await animateOutput(
            """
            ### 👋 Welcome to **AI Thing**

            I’m your personal AI assistant — built to handle everything from simple tasks to complex automations.
            With multiple AI models and specialized agents, I can work in the background to get things done securely.

            **Please log in from Settings to continue.**

            [aithing.dev](https://aithing.dev) • [Privacy Policy](https://aithing.dev/privacy)                
            """,
            true
        )
        AnalyticsManager.shared
            .customEvent(
                view: .IntelligenceView,
                primary: .query,
                secondary: "no login",
                sev: .error
            )
        return false
    }

    do {
        // Sleeping just to complete debounce on typing
        try await Task.sleep(nanoseconds: 200_000_000)
    } catch {}

    // Load latest tools
    await reconnectManagedAgents()
    let modelAgentCount = getAllClientTools().keys.count
    let modelTools = getAllClientTools().values.flatMap { $0 }

    let model = getModel()

    AnalyticsManager.shared.customEvent(
        view: .IntelligenceView,
        primary: .model,
        secondary: "model",
        sev: .info
    )
    AnalyticsManager.shared
        .customEvent(
            view: .IntelligenceView,
            primary: .count,
            secondary: "\(modelTools.count)",
            sev: .info
        )

    guard let apiKey = getAnthropicAPIKey(), !apiKey.isEmpty
    else {
        let modelTitle = getModelTitle(getModel(), all: getManagedModels())

        setIsThinking(false)
        await animateOutput(
            """
            API key not found.

            You have selected the \(modelTitle) model in **Settings** under the *"Use Own API Key"* section in the **Models** tab.

            This model requires you to provide an API key.

            You can create one at: https://console.anthropic.com/settings/keys

            For setup instructions, visit: https://aithing.dev/quickstart
            """,
            true
        )
        AnalyticsManager.shared
            .customEvent(
                view: .IntelligenceView,
                primary: .query,
                secondary: "no api key",
                sev: .error
            )
        return false
    }

    guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return true }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    request.setValue("\(apiKey)", forHTTPHeaderField: "x-api-key")
    request.setValue("extended-cache-ttl-2025-04-11", forHTTPHeaderField: "anthropic-beta")

    var fileCount = 0
    // query is non-empty only on first parse
    let modelContext = getModelContext()
    if !query.isEmpty {
        for i in 0..<modelContext.count {
            switch modelContext[i] {
            case .image(let name, _, let base64):
                fileCount += 1
                AnalyticsManager.shared.customEvent(
                    view: .IntelligenceView,
                    primary: .file,
                    secondary: "use image",
                    sev: .info
                )
                appendModelInput(
                    [
                        "role": "file",
                        "content": [
                            [
                                "type": "file",
                                "text": "File \(name)",
                                "skip_next_messages": false,
                            ]
                        ],
                    ]
                )
                appendModelInput(
                    [
                        "role": "user",
                        "content": [
                            [
                                "type": "image",
                                "source": [
                                    "type": "base64",
                                    "media_type": "image/jpeg",
                                    "data": base64,
                                ],
                            ]
                        ],
                    ]
                )
            case .pdf(let name, _, _, let base64s):
                fileCount += 1
                appendModelInput(
                    [
                        "role": "file",
                        "content": [
                            [
                                "type": "file",
                                "text": "File \(name)",
                                "skip_next_messages": false,
                            ]
                        ],
                    ]
                )
                var content: [[String: Any]] = []
                for base64 in base64s {
                    content.append([
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": base64,
                        ],
                    ])
                }
                AnalyticsManager.shared.customEvent(
                    view: .IntelligenceView,
                    primary: .file,
                    secondary: "use pdf",
                    sev: .info
                )
                appendModelInput(
                    [
                        "role": "user",
                        "content": content,
                    ]
                )
            case .text(let name, let text, _):
                fileCount += 1
                AnalyticsManager.shared.customEvent(
                    view: .IntelligenceView,
                    primary: .file,
                    secondary: "use text",
                    sev: .info
                )
                appendModelInput(
                    [
                        "role": "file",
                        "content": [
                            [
                                "type": "file",
                                "text": "File \(name)",
                                "skip_next_messages": true,
                            ]
                        ],
                    ]
                )
                appendModelInput(
                    [
                        "role": "user",
                        "content": [
                            [
                                "type": "text",
                                "text": "```\n\(text)\n```",
                            ]
                        ],
                    ]
                )
            }
        }

        if !getSelectedText().isEmpty, getSelectionEnabled() {
            AnalyticsManager.shared.customEvent(
                view: .IntelligenceView,
                primary: .file,
                secondary: "use selection",
                sev: .info
            )
            appendModelInput(
                [
                    "role": "file",
                    "content": [
                        [
                            "type": "file",
                            "text": "Selected Text",
                            "skip_next_messages": true,
                        ]
                    ],
                ]
            )
            appendModelInput(
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": "```\n\(getSelectedText())\n```",
                        ]
                    ],
                ]
            )
            setSelectedText("")
        }

        appendModelInput(
            [
                "role": "user",
                "content": [
                    ["type": "text", "text": buildQuery(query: query)]
                ],
            ]
        )
    }

    let body: [String: Any] = [
        "model": model,
        "stream": true,
        "max_tokens": getOutputToken(),
        "temperature": 0.7,
        "messages": addCacheBlock(
            input: nonUsageFileMessages(from: getModelInput()),
            isMessage: true
        ),
        "tools": addCacheBlock(input: modelTools),
        "system": addCacheBlock(input: buildSystemMessages()),

    ]

    // logger.debug("api key: \(apiKey)")
    logger.debug("model: \(model)")
    logger.debug("max tokens: \(getOutputToken())")
    logger.debug("messages: \(String(describing: body["messages"]))")
    logger.debug("tools count: \((body["tools"] as? [[String: Any]])?.count ?? 0)")

    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    do {
        let (stream, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse
        else {
            setIsThinking(false)
            await animateOutput(
                "Invalid response\n\nReport issue at help@aithing.dev",
                true
            )
            AnalyticsManager.shared
                .customEvent(
                    view: .IntelligenceView,
                    primary: .query,
                    secondary: "invalid response",
                    sev: .error
                )
            return false
        }

        if httpResponse.statusCode != 200 {
            setIsThinking(false)
            var error = ""
            for try await line in stream.lines {
                error += line
            }
            if httpResponse.statusCode == 429 {
                await animateOutput(
                    """
                    You’ve reached your API key’s rate limit.

                    Learn more: https://console.anthropic.com/settings/limits
                    """,
                    true
                )
                AnalyticsManager.shared
                    .customEvent(
                        view: .IntelligenceView,
                        primary: .query,
                        secondary: "rate limit reached",
                        sev: .error
                    )
            } else {
                await animateOutput(

                    "Error \(httpResponse.statusCode)\n\(error)\n\nReport issue at help@aithing.dev",
                    true
                )
                AnalyticsManager.shared
                    .customEvent(
                        view: .IntelligenceView,
                        primary: .query,
                        secondary: "error response",
                        sev: .error
                    )
            }
            return false
        }

        if let appUser {
            let usage = Usage(
                query: (query.isEmpty ? 0 : 1),
                agentUse: (query.isEmpty ? 1 : 0),
                filesAttached: fileCount
            )
            await firestoreManager.incrementUsage(user: appUser, usage: usage)
            appendModelInput([
                "role": "usage",
                "content": [
                    [
                        "type": "text",
                        "text": """
                        Total Usage:
                        1 \(query.isEmpty ? "Agent Use" : "Query")
                        \(fileCount) Attached Files                                
                        """,
                    ]
                ],
            ])

        } else {
            AnalyticsManager.shared
                .customEvent(
                    view: .IntelligenceView,
                    primary: .query,
                    secondary: "usage not calculated",
                    sev: .error
                )
        }

        clearModelContext()

        // Store the current input
        await storeHistory(tabId, getTabTitle(), getModelInput())
        // Fetch and display it
        setModelOutput("")
        setDisplayQuery("")
        setToolCall("")
        setHistory(getHistory(tabId))

        var finalResponse = ""
        var finalToolUseInputParam = ""
        var finalToolUseId = ""
        var finalToolUseName = ""

        for try await line in stream.lines {
            if line.starts(with: "data: ") {
                let jsonString = line.replacingOccurrences(of: "data: ", with: "")

                guard let data = jsonString.data(using: .utf8) else { continue }
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { continue }

                guard let data_type = json["type"] as? String else { continue }

                switch data_type {
                case "content_block_start":
                    guard let content_block = json["content_block"] as? [String: Any] else {
                        continue
                    }
                    guard let content_block_type = content_block["type"] as? String else {
                        continue
                    }

                    switch content_block_type {
                    case "text":
                        continue
                    case "tool_use":
                        guard let id = content_block["id"] as? String else { continue }
                        guard let name = content_block["name"] as? String else { continue }
                        finalToolUseId = id
                        finalToolUseName = name
                    default:
                        continue
                    }

                case "content_block_delta":
                    guard let delta = json["delta"] as? [String: Any] else { continue }
                    guard let delta_type = delta["type"] as? String else { continue }

                    switch delta_type {
                    case "text_delta":
                        guard let text = delta["text"] as? String else { continue }
                        setIsThinking(false)
                        finalResponse += String(text)
                        await MainActor.run {
                            setModelOutput(finalResponse + " " + shimmerPlaceholder())
                        }

                    case "input_json_delta":
                        guard let partial_json = delta["partial_json"] as? String else {
                            continue
                        }
                        finalToolUseInputParam += partial_json

                    default:
                        continue
                    }

                case "content_block_stop":
                    await MainActor.run {
                        setModelOutput(finalResponse)
                    }

                case "message_delta":
                    guard let delta = json["delta"] as? [String: Any] else { continue }
                    guard let delta_stop_reason = delta["stop_reason"] as? String else {
                        continue
                    }

                    if !getModelOutput().isEmpty {
                        appendModelInput([
                            "role": "assistant",
                            "content": [["text": getModelOutput(), "type": "text"]],
                        ])

                        setTabTitle(
                            await createTitle(
                                query: getModelOutput(),
                                model: model,
                                apiKey: apiKey,
                                tabTitle: getTabTitle(),
                                firestoreManager: firestoreManager
                            )
                        )

                        await storeHistory(tabId, getTabTitle(), getModelInput())
                    }

                    switch delta_stop_reason {
                    case "max_tokens":
                        continue
                    case "tool_use":
                        appendModelInput([
                            "role": "assistant",
                            "content": [
                                [
                                    "type": "tool_use",
                                    "id": finalToolUseId,
                                    "name": finalToolUseName,
                                    "input": parseJSONStringToDictObject(
                                        finalToolUseInputParam
                                    ),
                                ]
                            ],
                        ])

                        setToolCall("Calling tool: \(finalToolUseName)...")
                        let result = await mcpManager.callTools(
                            clientName: getClientName(
                                toolName: finalToolUseName,
                                allClientTools: getAllClientTools()
                            ),
                            name: finalToolUseName,
                            input: finalToolUseInputParam
                        )

                        AnalyticsManager.shared
                            .customEvent(
                                view: .IntelligenceView,
                                primary: .tool,
                                secondary: finalToolUseName,
                                sev: .info
                            )

                        logger.debug("Call tool: \(finalToolUseName)")
                        logger.debug("Tool input: \(finalToolUseInputParam)")
                        logger.debug("Tool output: \(result)")

                        appendModelInput([
                            "role": "user",
                            "content": [
                                [
                                    "type": "tool_result",
                                    "tool_use_id": finalToolUseId,
                                    "content": result,
                                ]
                            ],
                        ])

                        let rc = await callModel(
                            tabId: tabId,
                            query: "",
                            getSelectedText: getSelectedText,
                            setSelectedText: setSelectedText,
                            getSelectionEnabled: getSelectionEnabled,
                            setSelectionEnabled: setSelectionEnabled,
                            getTabTitle: getTabTitle,
                            setTabTitle: setTabTitle,
                            setDisplayQuery: setDisplayQuery,
                            setToolCall: setToolCall,
                            getHistory: getHistory,
                            storeHistory: storeHistory,
                            setHistory: setHistory,
                            setIsThinking: setIsThinking,
                            getModelInput: getModelInput,
                            appendModelInput: appendModelInput,
                            getModelOutput: getModelOutput,
                            setModelOutput: setModelOutput,
                            animateOutput: animateOutput,
                            getAllClientTools: getAllClientTools,
                            reconnectManagedAgents: reconnectManagedAgents,
                            getModelContext: getModelContext,
                            clearModelContext: clearModelContext,
                            getManagedModels: getManagedModels,
                            firestoreManager: firestoreManager,
                            loginManager: loginManager,
                            mcpManager: mcpManager,
                        )
                        return rc

                    default:
                        continue
                    }

                default:
                    continue
                }
            }
        }
    } catch {
        await MainActor.run {
            setIsThinking(false)
            setModelOutput(
                "Error streaming response: \(error.localizedDescription)\n\nReport issue at help@aithing.dev"
            )
            AnalyticsManager.shared
                .customEvent(
                    view: .IntelligenceView,
                    primary: .query,
                    secondary: "error streaming",
                    sev: .error
                )
        }
        return false
    }
    return true
}

private func buildQuery(query: String) -> String {
    return query
}

private func getClientName(toolName: String, allClientTools: [String: [[String: Any]]]) -> String {
    for (clientName, tools) in allClientTools {
        for tool in tools {
            if let name = tool["name"] as? String, name == toolName {
                return clientName
            }
        }
    }
    return ""
}

private func addCacheBlock(input: [[String: Any]], isMessage: Bool = false) -> [[String: Any]] {
    if !getCacheMessages() {
        return input
    }

    var updated = input

    if isMessage {
        guard var last = input.last,
            var contentArray = last["content"] as? [[String: Any]],
            var lastContent = contentArray.last
        else {
            return input
        }

        lastContent["cache_control"] = [
            "type": "ephemeral",
            "ttl": "5m",
        ]
        contentArray[contentArray.count - 1] = lastContent
        last["content"] = contentArray

        updated[updated.count - 1] = last
    } else {

        guard var last = input.last else {
            return input
        }

        last["cache_control"] = [
            "type": "ephemeral",
            "ttl": "5m",
        ]

        updated[updated.count - 1] = last
    }
    return updated
}

private func buildSystemMessages() -> [[String: Any]] {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .none
    formatter.locale = Locale(identifier: "en_US")
    let today = formatter.string(from: Date())

    let messages: [[String: Any]] = [
        [
            "type": "text",
            "text":
                """
            ## Identity  
            - Your name is **AI Thing**.  
            - You are an AI tool with a special abilities. 
            - You can handle simple, complex or repetitive tasks in background.                
            - You have multiple AI models and agents that users can use for their tasks. 
            - You are secure and store all data locally. 
            - Website: aithing.dev
            - Privacy Policy: aithing.dev/privacy                                                 
            """,
        ],
        [
            "type": "text",
            "text": "## Today is \(today).",
        ],
        [
            "type": "text",
            "text":
                """
            ## Behavior Rules  
            - Act as an **agent**: perceive instructions, reason, and invoke tools when needed.  
            - Be **precise, context-aware**, and never guess if info is missing.                   
            """,
        ],
        [
            "type": "text",
            "text":
                """
            ## Answer Style  
            - Keep answers **brief** by default.  
            - Only elaborate when explicitly asked.  
            - If in doubt, **ask first** before expanding with detail.  
            - Output response in Markdown.  
            """,
        ],
    ]

    return messages
}

private func createTitle(
    query: String,
    model: String,
    apiKey: String,
    tabTitle: String,
    firestoreManager: FirestoreManager,
) async -> String {
    if !tabTitle.isEmpty && tabTitle != "New Chat" {
        return tabTitle
    }

    // Check if version is breakglassed
    if await firestoreManager.getBreakglass() {
        return tabTitle
    }

    // Check if version is expired
    if await firestoreManager.getExpired() {
        return tabTitle
    }

    guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return tabTitle }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    request.setValue("\(apiKey)", forHTTPHeaderField: "x-api-key")
    request.setValue("extended-cache-ttl-2025-04-11", forHTTPHeaderField: "anthropic-beta")

    let input = [
        [
            "role": "user",
            "content": [
                ["type": "text", "text": buildQuery(query: query)]
            ],
        ]
    ]

    let body: [String: Any] = [
        "model": model,
        "stream": false,
        "max_tokens": 10,
        "temperature": 0.7,
        "messages": input,
        "system":
            "Generate a concise title of no more than 18 characters. Do not include quotation marks or any extra text. Output only the title, nothing else. If you can not generate the title output \"New Chat\"",
    ]

    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    do {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
        else {
            logger.error("Bad HTTP response")
            return tabTitle
        }

        // Parse JSON manually
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let contentArray = json["content"] as? [[String: Any]]
        {
            // Find the first item with type = "text"
            for item in contentArray {
                if let type = item["type"] as? String, type == "text",
                    let text = item["text"] as? String
                {
                    return text
                }
            }
        }
        return tabTitle
    } catch {
        return tabTitle
    }
}

private func shimmerPlaceholder() -> String {
    return "▌"  // or use "…" or a flashing cursor symbol
}
