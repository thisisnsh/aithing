//
//  IntelligenceManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 11/10/25.
//

import Foundation

func callModel(
    tabId: String,
    query: String,
    isTabRemoved: () -> Bool,
    getAppContextBase64: () -> AppContextModel?,
    getSelectedText: () -> String,
    setSelectedText: (String) -> Void,
    getSelectionEnabled: () -> Bool,
    setSelectionEnabled: (Bool) -> Void,
    getTabTitle: () -> String,
    setTabTitle: @escaping (String) async -> Void,
    setDisplayQuery: (String) -> Void,
    setToolCall: (String) -> Void,
    getHistory: (String) async -> History?,
    storeHistory: (String, [[String: Any]]) async -> Void,
    setHistory: (History?) -> Void,
    setIsThinking: (Bool) -> Void,
    getModelInput: () -> [[String: Any]],
    setModelInput: @escaping ([[String: Any]]) -> Void,
    getModelOutput: () -> String,
    setModelOutput: (String) -> Void,
    animateOutput: (String) async -> Void,
    getAllClientTools: () -> [String: [[String: Any]]],
    getUsedTools: () -> [[String: Any]],
    getModelContext: () -> [DroppedContent],
    clearModelContext: () -> Void,
    getManagedModels: () -> [ModelInfo],
    updateHistoryList: @escaping () async -> Void,
    firestoreManager: FirestoreManager,
    loginManager: LoginManager,
    mcpManager: MCPManager,
    automationManager: AutomationManager,
    aiThingMcpManager: AIThingMCPManager
) async -> Bool {
    let startTime = Date()

    var modelInput = getModelInput()
    var modelOutput = getModelOutput()
    var modelTools = getUsedTools()
    let model = getModel()
    let modelContext = getModelContext()

    if isTabRemoved() {
        logger.debug("Stop the query after tab removal")
        return true
    }

    setIsThinking(true)

    // MARK: Check Firebase Configs
    if !query.isEmpty {
        let rc = await validateFirebaseConfigs(
            firestoreManager: firestoreManager,
            setIsThinking: setIsThinking,
            animateOutput: animateOutput
        )
        if !rc { return rc }
    }

    // MARK: Check Login
    let appUser: AppUser? = await validateLogin(
        loginManager: loginManager,
        firestoreManager: firestoreManager,
        setIsThinking: setIsThinking,
        animateOutput: animateOutput
    )
    if appUser == nil { return false }

    // MARK: Refresh Tools
    if modelTools.isEmpty {
        modelTools = getAllClientTools().values.flatMap { $0 }
        if query.starts(with: "@aithing") {
            let aiThingTools = await MainActor.run { aiThingMcpManager.getTools() }
            modelTools.append(contentsOf: aiThingTools)
        }
    }

    AnalyticsManager.shared.customEvent(
        view: .IntelligenceManager,
        primary: .model,
        secondary: "model",
        sev: .info
    )
    AnalyticsManager.shared.customEvent(
        view: .IntelligenceManager,
        primary: .count,
        secondary: "\(modelTools.count)",
        sev: .info
    )

    guard let apiKey = getAnthropicAPIKey(), !apiKey.isEmpty
    else {
        setIsThinking(false)
        await animateOutput(
            """
            API key not found. You can create one at: https://console.anthropic.com/settings/keys

            For setup instructions, visit: https://aithing.dev/getstarted
            """
        )
        AnalyticsManager.shared
            .customEvent(
                view: .IntelligenceManager,
                primary: .query,
                secondary: "no api key",
                sev: .error
            )
        return false
    }

    let runTimeValidations = Date().timeIntervalSince(startTime) * 1000
    logger.debug("runTimeValidations \(runTimeValidations) ms")
    AnalyticsManager.shared
        .customEvent(
            view: .IntelligenceManager,
            primary: .runTimeValidations,
            secondary: "\(runTimeValidations)ms",
            sev: .info
        )

    guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return true }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    request.setValue("\(apiKey)", forHTTPHeaderField: "x-api-key")
    request.setValue("extended-cache-ttl-2025-04-11", forHTTPHeaderField: "anthropic-beta")

    var fileCount = 0
    if !query.isEmpty {
        // MARK: Put files only once when query is non-empty
        for i in 0..<modelContext.count {
            switch modelContext[i] {
            case .image(let name, _, let base64):
                fileCount += 1
                AnalyticsManager.shared.customEvent(
                    view: .IntelligenceManager,
                    primary: .file,
                    secondary: "use image",
                    sev: .info
                )
                modelInput.append(
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
                modelInput.append(
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
                modelInput.append(
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
                    view: .IntelligenceManager,
                    primary: .file,
                    secondary: "use pdf",
                    sev: .info
                )
                modelInput.append(
                    [
                        "role": "user",
                        "content": content,
                    ]
                )
            case .text(let name, let text, _):
                fileCount += 1
                AnalyticsManager.shared.customEvent(
                    view: .IntelligenceManager,
                    primary: .file,
                    secondary: "use text",
                    sev: .info
                )
                modelInput.append(
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
                modelInput.append(
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

        // MARK: Put selected text only once when query is non-empty
        if !getSelectedText().isEmpty, getSelectionEnabled() {
            AnalyticsManager.shared.customEvent(
                view: .IntelligenceManager,
                primary: .file,
                secondary: "use selection",
                sev: .info
            )
            modelInput.append(
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
            modelInput.append(
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

        // MARK: Get application context as screenshot
        if let appContext = getAppContextBase64() {
            AnalyticsManager.shared.customEvent(
                view: .IntelligenceManager,
                primary: .file,
                secondary: "use application context",
                sev: .info
            )
            modelInput.append(
                [
                    "role": "file",
                    "content": [
                        [
                            "type": "file",
                            "text":
                                "\(appContext.appName)\(appContext.windowName.count > 0 ? ": " : "")\(appContext.windowName)",
                            "skip_next_messages": false,
                        ]
                    ],
                ]
            )
            modelInput.append(
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": appContext.base64,
                            ],
                        ]
                    ],
                ]
            )
        }

        // MARK: Add actual query
        modelInput.append(
            [
                "role": "user",
                "content": [
                    ["type": "text", "text": buildQuery(query: query)]
                ],
            ]
        )
    }

    let runTimeContextBuild = Date().timeIntervalSince(startTime) * 1000
    logger.debug("runTimeContextBuild \(runTimeContextBuild) ms")
    AnalyticsManager.shared
        .customEvent(
            view: .IntelligenceManager,
            primary: .runTimeContextBuild,
            secondary: "\(runTimeContextBuild)ms",
            sev: .info
        )

    let body: [String: Any] = [
        "model": model,
        "stream": true,
        "max_tokens": getOutputToken(),
        "temperature": 0.7,
        "messages": addCacheBlock(input: nonUsageFileMessages(from: modelInput), isMessage: true),
        "tools": addCacheBlock(input: modelTools),
        "system": addCacheBlock(input: buildSystemMessages()),
    ]

    logger.debug("API Key: \(apiKey)")
    logger.debug("Model: \(model)")
    logger.debug("Max Tokens: \(getOutputToken())")
    logger.debug("Messages: \(String(describing: redactDataKeys(in: body["messages"] ?? [:])))")
    logger.debug("Tools Count: \((body["tools"] as? [[String: Any]])?.count ?? 0)")

    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    do {
        let (stream, response) = try await URLSession.shared.bytes(for: request)

        let runTimeResponse = Date().timeIntervalSince(startTime) * 1000
        logger.debug("runTimeResponse \(runTimeResponse) ms")
        AnalyticsManager.shared
            .customEvent(
                view: .IntelligenceManager,
                primary: .runTimeResponse,
                secondary: "\(runTimeResponse)ms",
                sev: .info
            )

        guard let httpResponse = response as? HTTPURLResponse
        else {
            setIsThinking(false)
            await animateOutput("Invalid response\n\nReport issue at help@aithing.dev")
            AnalyticsManager.shared
                .customEvent(
                    view: .IntelligenceManager,
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
                    """
                )
                AnalyticsManager.shared
                    .customEvent(
                        view: .IntelligenceManager,
                        primary: .query,
                        secondary: "rate limit reached",
                        sev: .error
                    )
            } else {
                await animateOutput(
                    "Error \(httpResponse.statusCode)\n\n```\n\(error)\n```\n\nReport issue at help@aithing.dev"
                )
                AnalyticsManager.shared
                    .customEvent(
                        view: .IntelligenceManager,
                        primary: .query,
                        secondary: "error response",
                        sev: .error
                    )
            }
            return false
        }

        Task {
            if let appUser {
                let usage = Usage(
                    query: (query.isEmpty ? 0 : 1),
                    agentUse: (query.isEmpty ? 1 : 0),
                    filesAttached: fileCount
                )
                await firestoreManager.incrementUsage(user: appUser, usage: usage)
                modelInput.append([
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
                        view: .IntelligenceManager,
                        primary: .query,
                        secondary: "usage not calculated",
                        sev: .error
                    )
            }
        }

        clearModelContext()

        // Store the current input
        await storeHistory(tabId, modelInput)

        // Fetch and display it
        setHistory(await getHistory(tabId))
        setModelOutput("")
        setDisplayQuery("")
        setToolCall("")

        // Update sidebar
        Task { await updateHistoryList() }

        let accumulator = StreamAccumulator()
        var finalToolUseId = ""
        var finalToolUseName = ""
        let throttleInterval: TimeInterval = 0.05

        let runTimeResponseParseStart = Date().timeIntervalSince(startTime) * 1000
        logger.debug("runTimeResponseParseStart \(runTimeResponseParseStart) ms")
        AnalyticsManager.shared
            .customEvent(
                view: .IntelligenceManager,
                primary: .runTimeResponseParseStart,
                secondary: "\(runTimeResponseParseStart)ms",
                sev: .info
            )

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
                        await accumulator.appendResponse(String(text))
                        if await accumulator.shouldThrottle(now: Date(), interval: throttleInterval)
                        {
                            modelOutput = await accumulator.snapshotResponse()
                            setModelOutput(modelOutput + " " + shimmerPlaceholder())
                        }

                    case "input_json_delta":
                        guard let partial_json = delta["partial_json"] as? String else {
                            continue
                        }
                        await accumulator.appendToolInput(partial_json)

                    default:
                        continue
                    }

                case "content_block_stop":
                    modelOutput = await accumulator.snapshotResponse()
                    setModelOutput(modelOutput)

                case "message_delta":
                    guard let delta = json["delta"] as? [String: Any] else { continue }
                    guard let delta_stop_reason = delta["stop_reason"] as? String else {
                        continue
                    }

                    if !modelOutput.isEmpty {
                        modelInput.append([
                            "role": "assistant",
                            "content": [["text": modelOutput, "type": "text"]],
                        ])

                        var tabTitle = getTabTitle()
                        Task {
                            if !query.isEmpty && (tabTitle.isEmpty || tabTitle == "New Chat") {
                                let startTimeTitle = Date()
                                tabTitle = await createTitle(
                                    query: query,
                                    response: modelOutput,
                                    model: model,
                                    apiKey: apiKey,
                                    tabTitle: tabTitle,
                                    firestoreManager: firestoreManager
                                )
                                await setTabTitle(tabTitle)
                                let runTimeTitle = Date().timeIntervalSince(startTimeTitle) * 1000
                                logger.debug("runTimeTitle \(runTimeTitle) ms")
                                AnalyticsManager.shared
                                    .customEvent(
                                        view: .IntelligenceManager,
                                        primary: .runTimeTitle,
                                        secondary: "\(runTimeTitle)ms",
                                        sev: .info
                                    )
                            }
                        }
                    }

                    switch delta_stop_reason {
                    case "max_tokens":
                        continue
                    case "tool_use":
                        let startTimeTools = Date()
                        modelInput.append([
                            "role": "assistant",
                            "content": [
                                [
                                    "type": "tool_use",
                                    "id": finalToolUseId,
                                    "name": finalToolUseName,
                                    "input": parseJSONStringToDictObject(
                                        await accumulator.snapshotToolInput()
                                    ),
                                ]
                            ],
                        ])

                        setToolCall("Calling tool: \(finalToolUseName)...")
                        var result: [[String: Any]] = []
                        if finalToolUseName.starts(with: "aithing_") {
                            result = await aiThingMcpManager.callTools(
                                name: finalToolUseName,
                                input: await accumulator.snapshotToolInput(),
                                automationManager: automationManager
                            )
                        } else {
                            result = await mcpManager.callTools(
                                clientName: getClientName(
                                    toolName: finalToolUseName,
                                    allClientTools: getAllClientTools()
                                ),
                                name: finalToolUseName,
                                input: await accumulator.snapshotToolInput()
                            )
                        }

                        AnalyticsManager.shared
                            .customEvent(
                                view: .IntelligenceManager,
                                primary: .tool,
                                secondary: finalToolUseName,
                                sev: .info
                            )

                        logger.debug("Called tool: \(finalToolUseName)")
                        let snapshotToolInput = await accumulator.snapshotToolInput()
                        logger.debug(
                            "Tool input: \(parseJSONStringToDictObject(snapshotToolInput))"
                        )
                        logger.debug("Tool output: \(result)")

                        modelInput.append([
                            "role": "user",
                            "content": [
                                [
                                    "type": "tool_result",
                                    "tool_use_id": finalToolUseId,
                                    "content": result,
                                ]
                            ],
                        ])

                        let runTimeTools = Date().timeIntervalSince(startTimeTools) * 1000
                        logger.debug("runTimeTools \(runTimeTools) ms")
                        AnalyticsManager.shared
                            .customEvent(
                                view: .IntelligenceManager,
                                primary: .runTimeTools,
                                secondary: "\(runTimeTools)ms",
                                sev: .info
                            )

                        return await callModel(
                            tabId: tabId,
                            query: "",
                            isTabRemoved: isTabRemoved,
                            getAppContextBase64: { return nil },
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
                            getModelInput: { modelInput },
                            setModelInput: setModelInput,
                            getModelOutput: { modelOutput },
                            setModelOutput: setModelOutput,
                            animateOutput: animateOutput,
                            getAllClientTools: getAllClientTools,
                            // reuse the same tools in entire run
                            getUsedTools: { modelTools },
                            getModelContext: getModelContext,
                            clearModelContext: clearModelContext,
                            getManagedModels: getManagedModels,
                            updateHistoryList: updateHistoryList,
                            firestoreManager: firestoreManager,
                            loginManager: loginManager,
                            mcpManager: mcpManager,
                            automationManager: automationManager,
                            aiThingMcpManager: aiThingMcpManager
                        )

                    default:
                        continue
                    }

                default:
                    continue
                }
            }
        }

        let runTimeResponseParseEnd = Date().timeIntervalSince(startTime) * 1000
        logger.debug("runTimeResponseParseEnd \(runTimeResponseParseEnd) ms")
        AnalyticsManager.shared
            .customEvent(
                view: .IntelligenceManager,
                primary: .runTimeResponseParseEnd,
                secondary: "\(runTimeResponseParseEnd)ms",
                sev: .info
            )
    } catch {
        setIsThinking(false)
        setModelOutput(
            "Error streaming response: \(error.localizedDescription)\n\nReport issue at help@aithing.dev"
        )
        AnalyticsManager.shared
            .customEvent(
                view: .IntelligenceManager,
                primary: .query,
                secondary: "error streaming",
                sev: .error
            )

        return false
    }

    await storeHistory(tabId, modelInput)

    setIsThinking(false)
    setModelInput(modelInput)

    setHistory(await getHistory(tabId))
    setModelOutput("")
    setDisplayQuery("")
    setToolCall("")

    Task { await updateHistoryList() }

    let runTimeEnd = Date().timeIntervalSince(startTime) * 1000
    logger.debug("runTimeEnd \(runTimeEnd) ms")
    AnalyticsManager.shared
        .customEvent(
            view: .IntelligenceManager,
            primary: .runTimeEnd,
            secondary: "\(runTimeEnd)ms",
            sev: .info
        )

    return true
}

