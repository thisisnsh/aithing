//
//  IntelligenceManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 11/10/25.
//

import Foundation

// MARK: - Public API

/// Executes a model call with the given context.
///
/// This is the main entry point for making AI model requests. It handles:
/// - Validation of Firebase configs and user login
/// - Processing of attached files and context
/// - Streaming response handling
/// - Tool execution and recursive calls
///
/// - Parameter context: The complete context containing all necessary state and callbacks
/// - Returns: `true` if the call completed successfully, `false` otherwise
func callModel(context: ModelCallContext) async -> Bool {
    return await executeModelCall(
        context: context,
        modelInput: context.modelHandlers.getModelInput(),
        modelOutput: context.modelHandlers.getModelOutput(),
        modelTools: context.toolHandlers.getUsedTools()
    )
}

// MARK: - Private Implementation

/// Internal execution of the model call with mutable state.
///
/// - Parameters:
///   - context: The model call context
///   - modelInput: Current model input messages (mutable copy)
///   - modelOutput: Current model output (mutable copy)
///   - modelTools: Current tools being used (mutable copy)
/// - Returns: `true` if successful, `false` otherwise
private func executeModelCall(
    context: ModelCallContext,
    modelInput: [[String: Any]],
    modelOutput: String,
    modelTools: [[String: Any]]
) async -> Bool {
    let startTime = Date()

    var modelInput = modelInput
    var modelOutput = modelOutput
    var modelTools = modelTools
    let modelContext = context.modelHandlers.getModelContext()

    guard let model = getModel() else {
        context.uiHandlers.setIsThinking(false)
        await context.uiHandlers.animateOutput("Model not selected")
        return false
    }

    // Get provider for the selected model
    let allModels = context.modelHandlers.getAllModels()
    guard let modelProvider = getModelProvider(model, all: allModels) else {
        context.uiHandlers.setIsThinking(false)
        await context.uiHandlers.animateOutput("Model provider not found")
        return false
    }

    guard let provider = AIProviderRegistry.shared.getProvider(for: modelProvider) else {
        context.uiHandlers.setIsThinking(false)
        await context.uiHandlers.animateOutput("Unsupported model provider: \(modelProvider.displayName)")
        return false
    }

    if context.tabHandlers.isTabRemoved() {
        logger.debug("Stop the query after tab removal")
        return true
    }

    context.uiHandlers.setIsThinking(true)

    // MARK: Check Firebase Configs
    if !context.query.isEmpty {
        let validationContext = ValidationContext(
            firestoreManager: context.services.firestoreManager,
            setIsThinking: context.uiHandlers.setIsThinking,
            animateOutput: context.uiHandlers.animateOutput
        )
        let rc = await validateFirebaseConfigs(context: validationContext)
        if !rc { return rc }
    }

    // MARK: Check Login
    let loginContext = LoginValidationContext(
        loginManager: context.services.loginManager,
        firestoreManager: context.services.firestoreManager,
        setIsThinking: context.uiHandlers.setIsThinking,
        animateOutput: context.uiHandlers.animateOutput
    )
    let appUser: AppUser? = await validateLogin(context: loginContext)
    if appUser == nil { return false }

    // MARK: Refresh Tools
    if modelTools.isEmpty {
        modelTools = context.toolHandlers.getAllClientTools().values.flatMap { $0 }
        if context.query.starts(with: "@aithing") {
            // InternalToolProvider.getTools() is not @MainActor, runs on current executor
            let aiThingTools = context.services.internalToolProvider.getTools()
            modelTools.append(contentsOf: aiThingTools)
        }
    }

    logToolAnalytics(model: model, toolCount: modelTools.count)

    // Get API key for the provider
    guard let apiKey = getAPIKey(for: modelProvider), !apiKey.isEmpty else {
        return await handleMissingAPIKey(context: context, provider: modelProvider)
    }

    logRuntime(name: "runTimeValidations", startTime: startTime)

    var fileCount = 0
    if !context.query.isEmpty {
        fileCount = processInputContext(
            context: context,
            modelInput: &modelInput,
            modelContext: modelContext
        )
    }

    logRuntime(name: "runTimeContextBuild", startTime: startTime)

    // Build request using provider
    let systemMessages = addCacheBlock(input: buildSystemMessages())
    let processedMessages = addCacheBlock(input: nonUsageFileMessages(from: modelInput), isMessage: true)
    let processedTools = addCacheBlock(input: modelTools)

    guard
        let request = provider.buildRequest(
            apiKey: apiKey,
            model: model,
            messages: processedMessages,
            tools: processedTools,
            systemMessages: systemMessages,
            maxTokens: getOutputToken()
        )
    else {
        return await handleInvalidResponse(context: context)
    }

    logRequestDetails(apiKey: apiKey, model: model, provider: modelProvider, messagesCount: processedMessages.count, toolsCount: processedTools.count)

    do {
        let (stream, response) = try await URLSession.shared.bytes(for: request)

        logRuntime(name: "runTimeResponse", startTime: startTime)

        guard let httpResponse = response as? HTTPURLResponse else {
            return await handleInvalidResponse(context: context)
        }

        if httpResponse.statusCode != 200 {
            return await handleHTTPError(
                context: context,
                statusCode: httpResponse.statusCode,
                stream: stream,
                provider: modelProvider
            )
        }

        // Track usage asynchronously
        Task {
            await trackUsage(
                appUser: appUser,
                query: context.query,
                fileCount: fileCount,
                modelInput: &modelInput,
                firestoreManager: context.services.firestoreManager
            )
        }

        context.modelHandlers.clearModelContext()

        // Store the current input
        await context.historyHandlers.storeHistory(context.tabId, modelInput)

        // Fetch and display it
        context.historyHandlers.setHistory(
            await context.historyHandlers.getHistory(context.tabId)
        )
        context.modelHandlers.setModelOutput("")
        context.uiHandlers.setDisplayQuery("")
        context.uiHandlers.setToolCall("")

        // Update sidebar
        Task { await context.historyHandlers.updateHistoryList() }

        logRuntime(name: "runTimeResponseParseStart", startTime: startTime)

        let streamResult = await processResponseStream(
            stream: stream,
            context: context,
            modelInput: &modelInput,
            modelOutput: &modelOutput,
            modelTools: modelTools,
            model: model,
            apiKey: apiKey,
            provider: provider,
            startTime: startTime
        )

        if let recursiveResult = streamResult.recursiveResult {
            return recursiveResult
        }

        logRuntime(name: "runTimeResponseParseEnd", startTime: startTime)

    } catch {
        return handleStreamError(context: context, error: error)
    }

    await context.historyHandlers.storeHistory(context.tabId, modelInput)

    context.uiHandlers.setIsThinking(false)
    context.modelHandlers.setModelInput(modelInput)

    context.historyHandlers.setHistory(
        await context.historyHandlers.getHistory(context.tabId)
    )
    context.modelHandlers.setModelOutput("")
    context.uiHandlers.setDisplayQuery("")
    context.uiHandlers.setToolCall("")

    Task { await context.historyHandlers.updateHistoryList() }

    logRuntime(name: "runTimeEnd", startTime: startTime)

    return true
}

// MARK: - Context Processing

/// Processes input context including files, selected text, and app context.
///
/// - Parameters:
///   - context: The model call context
///   - modelInput: The model input to append to
///   - modelContext: The dropped content to process
/// - Returns: Count of files processed
private func processInputContext(
    context: ModelCallContext,
    modelInput: inout [[String: Any]],
    modelContext: [DroppedContent]
) -> Int {
    var fileCount = 0

    // Process files
    for i in 0..<modelContext.count {
        switch modelContext[i] {
        case .image(let name, _, let base64):
            fileCount += 1
            appendImageToInput(name: name, base64: base64, modelInput: &modelInput)

        case .pdf(let name, _, _, let base64s):
            fileCount += 1
            appendPDFToInput(name: name, base64s: base64s, modelInput: &modelInput)

        case .text(let name, let text, _):
            fileCount += 1
            appendTextToInput(name: name, text: text, modelInput: &modelInput)
        }
    }

    // Process selected text
    if !context.selectionHandlers.getSelectedText().isEmpty,
        context.selectionHandlers.getSelectionEnabled()
    {
        appendSelectedTextToInput(
            text: context.selectionHandlers.getSelectedText(),
            modelInput: &modelInput
        )
        context.selectionHandlers.setSelectedText("")
    }

    // Process application context
    if let appContext = context.toolHandlers.getAppContextBase64() {
        appendAppContextToInput(appContext: appContext, modelInput: &modelInput)
    }

    // Add actual query
    modelInput.append([
        "role": "user",
        "content": [
            ["type": "text", "text": buildQuery(query: context.query)]
        ],
    ])

    return fileCount
}

/// Appends an image file to the model input.
private func appendImageToInput(
    name: String,
    base64: String,
    modelInput: inout [[String: Any]]
) {
    AnalyticsManager.shared.customEvent(
        view: .IntelligenceManager,
        primary: .file,
        secondary: "use image",
        sev: .info
    )
    modelInput.append([
        "role": "file",
        "content": [["type": "file", "text": "File \(name)", "skip_next_messages": false]],
    ])
    modelInput.append([
        "role": "user",
        "content": [
            [
                "type": "image",
                "source": ["type": "base64", "media_type": "image/jpeg", "data": base64],
            ]
        ],
    ])
}

/// Appends a PDF file to the model input.
private func appendPDFToInput(
    name: String,
    base64s: [String],
    modelInput: inout [[String: Any]]
) {
    AnalyticsManager.shared.customEvent(
        view: .IntelligenceManager,
        primary: .file,
        secondary: "use pdf",
        sev: .info
    )
    modelInput.append([
        "role": "file",
        "content": [["type": "file", "text": "File \(name)", "skip_next_messages": false]],
    ])
    var content: [[String: Any]] = []
    for base64 in base64s {
        content.append([
            "type": "image",
            "source": ["type": "base64", "media_type": "image/jpeg", "data": base64],
        ])
    }
    modelInput.append(["role": "user", "content": content])
}

/// Appends a text file to the model input.
private func appendTextToInput(
    name: String,
    text: String,
    modelInput: inout [[String: Any]]
) {
    AnalyticsManager.shared.customEvent(
        view: .IntelligenceManager,
        primary: .file,
        secondary: "use text",
        sev: .info
    )
    modelInput.append([
        "role": "file",
        "content": [["type": "file", "text": "File \(name)", "skip_next_messages": true]],
    ])
    modelInput.append([
        "role": "user",
        "content": [["type": "text", "text": "```\n\(text)\n```"]],
    ])
}

/// Appends selected text to the model input.
private func appendSelectedTextToInput(
    text: String,
    modelInput: inout [[String: Any]]
) {
    AnalyticsManager.shared.customEvent(
        view: .IntelligenceManager,
        primary: .file,
        secondary: "use selection",
        sev: .info
    )
    modelInput.append([
        "role": "file",
        "content": [["type": "file", "text": "Selected Text", "skip_next_messages": true]],
    ])
    modelInput.append([
        "role": "user",
        "content": [["type": "text", "text": "```\n\(text)\n```"]],
    ])
}

/// Appends application context screenshot to the model input.
private func appendAppContextToInput(
    appContext: AppContextModel,
    modelInput: inout [[String: Any]]
) {
    AnalyticsManager.shared.customEvent(
        view: .IntelligenceManager,
        primary: .file,
        secondary: "use application context",
        sev: .info
    )
    let contextText = "\(appContext.appName)\(appContext.windowName.count > 0 ? ": " : "")\(appContext.windowName)"
    modelInput.append([
        "role": "file",
        "content": [["type": "file", "text": contextText, "skip_next_messages": false]],
    ])
    modelInput.append([
        "role": "user",
        "content": [
            [
                "type": "image",
                "source": ["type": "base64", "media_type": "image/jpeg", "data": appContext.base64],
            ]
        ],
    ])
}

// MARK: - Stream Processing

/// Result of processing a response stream.
private struct StreamProcessingResult {
    /// If set, indicates a recursive call result that should be returned
    let recursiveResult: Bool?
}

/// Processes the streaming response from the API.
///
/// - Parameters:
///   - stream: The byte stream from the API
///   - context: The model call context
///   - modelInput: Model input messages (mutable)
///   - modelOutput: Model output text (mutable)
///   - modelTools: Available tools
///   - model: Model identifier
///   - apiKey: API key for title generation
///   - provider: The AI provider implementation
///   - startTime: Start time for metrics
/// - Returns: Stream processing result
private func processResponseStream(
    stream: URLSession.AsyncBytes,
    context: ModelCallContext,
    modelInput: inout [[String: Any]],
    modelOutput: inout String,
    modelTools: [[String: Any]],
    model: String,
    apiKey: String,
    provider: AIProviderProtocol,
    startTime: Date
) async -> StreamProcessingResult {
    let accumulator = StreamAccumulator()
    var finalToolUseId = ""
    var finalToolUseName = ""
    let throttleInterval: TimeInterval = 0.05

    do {
        for try await line in stream.lines {
            guard let event = provider.parseStreamLine(line) else { continue }

            switch event {
            case .text(let text):
                await accumulator.appendResponse(text)
                if await accumulator.shouldThrottle(now: Date(), interval: throttleInterval) {
                    modelOutput = await accumulator.snapshotResponse()
                    context.modelHandlers.setModelOutput(modelOutput + " " + shimmerPlaceholder())
                }

            case .toolUseStart(let id, let name):
                finalToolUseId = id
                finalToolUseName = name

            case .toolInput(let input):
                await accumulator.appendToolInput(input)

            case .contentBlockStop:
                modelOutput = await accumulator.snapshotResponse()
                context.modelHandlers.setModelOutput(modelOutput)

            case .done(let stopReason):
                if let result = await handleStreamCompletion(
                    stopReason: stopReason,
                    context: context,
                    modelInput: &modelInput,
                    modelOutput: modelOutput,
                    modelTools: modelTools,
                    accumulator: accumulator,
                    finalToolUseId: finalToolUseId,
                    finalToolUseName: finalToolUseName,
                    model: model,
                    apiKey: apiKey,
                    provider: provider,
                    startTime: startTime
                ) {
                    return StreamProcessingResult(recursiveResult: result)
                }

            case .error(let message):
                context.modelHandlers.setModelOutput("Error: \(message)")
                return StreamProcessingResult(recursiveResult: false)
            }
        }
    } catch {
        // Stream error handling is done in the caller
    }

    return StreamProcessingResult(recursiveResult: nil)
}

/// Handles stream completion events.
///
/// - Returns: Bool result if a tool call was made and recursive execution completed, nil otherwise
private func handleStreamCompletion(
    stopReason: StopReason,
    context: ModelCallContext,
    modelInput: inout [[String: Any]],
    modelOutput: String,
    modelTools: [[String: Any]],
    accumulator: StreamAccumulator,
    finalToolUseId: String,
    finalToolUseName: String,
    model: String,
    apiKey: String,
    provider: AIProviderProtocol,
    startTime: Date
) async -> Bool? {
    // Add assistant text message if there's output
    if !modelOutput.isEmpty {
        let assistantMessage = provider.buildAssistantTextMessage(text: modelOutput)
        modelInput.append(assistantMessage)

        var tabTitle = context.tabHandlers.getTabTitle()
        Task {
            if !context.query.isEmpty && (tabTitle.isEmpty || tabTitle == "New Chat") {
                let startTimeTitle = Date()
                let titleContext = TitleGenerationContext(
                    query: context.query,
                    response: modelOutput,
                    model: model,
                    apiKey: apiKey,
                    tabTitle: tabTitle,
                    firestoreManager: context.services.firestoreManager,
                    provider: provider.provider
                )
                tabTitle = await createTitle(context: titleContext)
                await context.tabHandlers.setTabTitle(tabTitle)
                logRuntime(name: "runTimeTitle", startTime: startTimeTitle)
            }
        }
    }

    switch stopReason {
    case .maxTokens:
        return nil

    case .toolUse:
        let toolStartTime = Date()

        let toolInput = parseJSONStringToDictObject(await accumulator.snapshotToolInput())
        let assistantToolMessage = provider.buildAssistantToolUseMessage(
            text: modelOutput.isEmpty ? nil : modelOutput,
            toolUseId: finalToolUseId,
            toolName: finalToolUseName,
            toolInput: toolInput
        )

        // Remove the text-only message if we added one, since tool message includes text
        if !modelOutput.isEmpty {
            modelInput.removeLast()
        }
        modelInput.append(assistantToolMessage)

        context.uiHandlers.setToolCall("Calling tool: \(finalToolUseName)...")

        var result: [[String: Any]] = []
        if finalToolUseName.starts(with: "aithing_") {
            result = await context.services.internalToolProvider.callTools(
                name: finalToolUseName,
                input: await accumulator.snapshotToolInput(),
                automationManager: context.services.automationManager
            )
        } else {
            result = await context.services.connectionManager.callTools(
                clientName: getClientName(
                    toolName: finalToolUseName,
                    allClientTools: context.toolHandlers.getAllClientTools()
                ),
                name: finalToolUseName,
                input: await accumulator.snapshotToolInput()
            )
        }

        AnalyticsManager.shared.customEvent(
            view: .IntelligenceManager,
            primary: .tool,
            secondary: finalToolUseName,
            sev: .info
        )

        logger.debug("Called tool: \(finalToolUseName)")
        let snapshotToolInput = await accumulator.snapshotToolInput()
        logger.debug("Tool input: \(parseJSONStringToDictObject(snapshotToolInput))")
        logger.debug("Tool output: \(result)")

        let toolResultMessage = provider.buildToolResultMessage(toolUseId: finalToolUseId, result: result)
        modelInput.append(toolResultMessage)

        logRuntime(name: "runTimeTools", startTime: toolStartTime)

        // Create recursive context with empty query and updated state
        let recursiveContext = createRecursiveContext(
            originalContext: context,
            modelInput: modelInput,
            modelOutput: modelOutput,
            modelTools: modelTools
        )

        return await callModel(context: recursiveContext)

    default:
        return nil
    }
}

/// Creates a context for recursive model calls after tool execution.
private func createRecursiveContext(
    originalContext: ModelCallContext,
    modelInput: [[String: Any]],
    modelOutput: String,
    modelTools: [[String: Any]]
) -> ModelCallContext {
    let capturedInput = modelInput
    let capturedOutput = modelOutput
    let capturedTools = modelTools

    return ModelCallContext(
        tabId: originalContext.tabId,
        query: "",
        tabHandlers: originalContext.tabHandlers,
        selectionHandlers: originalContext.selectionHandlers,
        modelHandlers: ModelHandlers(
            getModelInput: { capturedInput },
            setModelInput: originalContext.modelHandlers.setModelInput,
            getModelOutput: { capturedOutput },
            setModelOutput: originalContext.modelHandlers.setModelOutput,
            getModelContext: originalContext.modelHandlers.getModelContext,
            clearModelContext: originalContext.modelHandlers.clearModelContext,
            getAllModels: originalContext.modelHandlers.getAllModels
        ),
        historyHandlers: originalContext.historyHandlers,
        uiHandlers: originalContext.uiHandlers,
        toolHandlers: ToolHandlers(
            getAllClientTools: originalContext.toolHandlers.getAllClientTools,
            getUsedTools: { capturedTools },
            getAppContextBase64: { nil }
        ),
        services: originalContext.services
    )
}

// MARK: - Error Handling

/// Handles missing API key error.
private func handleMissingAPIKey(context: ModelCallContext, provider: AIProvider) async -> Bool {
    context.uiHandlers.setIsThinking(false)

    let keyUrl: String
    switch provider {
    case .anthropic:
        keyUrl = "https://console.anthropic.com/settings/keys"
    case .openai:
        keyUrl = "https://platform.openai.com/api-keys"
    case .gemini:
        keyUrl = "https://aistudio.google.com/app/apikey"
    }

    await context.uiHandlers.animateOutput(
        """
        \(provider.displayName) API key not found. You can create one at: \(keyUrl)

        For setup instructions, visit: https://aithing.dev/getstarted
        """
    )
    AnalyticsManager.shared.customEvent(
        view: .IntelligenceManager,
        primary: .query,
        secondary: "no api key",
        sev: .error
    )
    return false
}

/// Handles invalid HTTP response.
private func handleInvalidResponse(context: ModelCallContext) async -> Bool {
    context.uiHandlers.setIsThinking(false)
    await context.uiHandlers.animateOutput("Invalid response\n\nReport issue at help@aithing.dev")
    AnalyticsManager.shared.customEvent(
        view: .IntelligenceManager,
        primary: .query,
        secondary: "invalid response",
        sev: .error
    )
    return false
}

/// Handles HTTP error responses.
private func handleHTTPError(
    context: ModelCallContext,
    statusCode: Int,
    stream: URLSession.AsyncBytes,
    provider: AIProvider
) async -> Bool {
    context.uiHandlers.setIsThinking(false)

    var error = ""
    do {
        for try await line in stream.lines {
            error += line
        }
    } catch {}

    if statusCode == 429 {
        let limitsUrl: String
        switch provider {
        case .anthropic:
            limitsUrl = "https://console.anthropic.com/settings/limits"
        case .openai:
            limitsUrl = "https://platform.openai.com/account/limits"
        case .gemini:
            limitsUrl = "https://aistudio.google.com/app/billing"
        }

        await context.uiHandlers.animateOutput(
            """
            You've reached your API key's rate limit.

            Learn more: \(limitsUrl)
            """
        )
        AnalyticsManager.shared.customEvent(
            view: .IntelligenceManager,
            primary: .query,
            secondary: "rate limit reached",
            sev: .error
        )
    } else {
        await context.uiHandlers.animateOutput(
            "Error \(statusCode)\n\n```\n\(error)\n```\n\nReport issue at help@aithing.dev"
        )
        AnalyticsManager.shared.customEvent(
            view: .IntelligenceManager,
            primary: .query,
            secondary: "error response",
            sev: .error
        )
    }
    return false
}

/// Handles stream processing errors.
private func handleStreamError(context: ModelCallContext, error: Error) -> Bool {
    context.uiHandlers.setIsThinking(false)
    context.modelHandlers.setModelOutput(
        "Error streaming response: \(error.localizedDescription)\n\nReport issue at help@aithing.dev"
    )
    AnalyticsManager.shared.customEvent(
        view: .IntelligenceManager,
        primary: .query,
        secondary: "error streaming",
        sev: .error
    )
    return false
}

// MARK: - Usage Tracking

/// Tracks usage statistics for the model call.
private func trackUsage(
    appUser: AppUser?,
    query: String,
    fileCount: Int,
    modelInput: inout [[String: Any]],
    firestoreManager: FirestoreManager
) async {
    if let appUser {
        let usage = Usage(
            query: query.isEmpty ? 0 : 1,
            agentUse: query.isEmpty ? 1 : 0,
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
        AnalyticsManager.shared.customEvent(
            view: .IntelligenceManager,
            primary: .query,
            secondary: "usage not calculated",
            sev: .error
        )
    }
}

// MARK: - Logging Helpers

/// Logs tool-related analytics events.
private func logToolAnalytics(model: String, toolCount: Int) {
    AnalyticsManager.shared.customEvent(
        view: .IntelligenceManager,
        primary: .model,
        secondary: "model",
        sev: .info
    )
    AnalyticsManager.shared.customEvent(
        view: .IntelligenceManager,
        primary: .count,
        secondary: "\(toolCount)",
        sev: .info
    )
}

/// Logs runtime metrics.
private func logRuntime(name: String, startTime: Date) {
    let runtime = Date().timeIntervalSince(startTime) * 1000
    logger.debug("Metrics \(name): \(runtime) ms")

    let primary: AnalyticsManager.EventPrimary
    switch name {
    case "runTimeValidations": primary = .runTimeValidations
    case "runTimeContextBuild": primary = .runTimeContextBuild
    case "runTimeResponse": primary = .runTimeResponse
    case "runTimeResponseParseStart": primary = .runTimeResponseParseStart
    case "runTimeResponseParseEnd": primary = .runTimeResponseParseEnd
    case "runTimeTitle": primary = .runTimeTitle
    case "runTimeTools": primary = .runTimeTools
    case "runTimeEnd": primary = .runTimeEnd
    default: return
    }

    AnalyticsManager.shared.customEvent(
        view: .IntelligenceManager,
        primary: primary,
        secondary: "\(runtime)ms",
        sev: .info
    )
}

/// Logs request details for debugging.
private func logRequestDetails(apiKey: String, model: String, provider: AIProvider, messagesCount: Int, toolsCount: Int) {
    logger.debug("API Key: \(apiKey.prefix(10))...")
    logger.debug("Model: \(model)")
    logger.debug("Provider: \(provider.displayName)")
    logger.debug("Max Tokens: \(getOutputToken())")
    logger.debug("Messages Count: \(messagesCount)")
    logger.debug("Tools Count: \(toolsCount)")
}
