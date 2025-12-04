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
    let model = getModel()
    let modelContext = context.modelHandlers.getModelContext()
    
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
    
    guard let apiKey = getAnthropicAPIKey(), !apiKey.isEmpty else {
        return await handleMissingAPIKey(context: context)
    }
    
    logRuntime(name: "runTimeValidations", startTime: startTime)
    
    guard let request = buildAPIRequest(apiKey: apiKey) else { return true }
    
    var fileCount = 0
    if !context.query.isEmpty {
        fileCount = processInputContext(
            context: context,
            modelInput: &modelInput,
            modelContext: modelContext
        )
    }
    
    logRuntime(name: "runTimeContextBuild", startTime: startTime)
    
    let body = buildRequestBody(
        model: model,
        modelInput: modelInput,
        modelTools: modelTools
    )
    
    logRequestDetails(apiKey: apiKey, model: model, body: body)
    
    var finalRequest = request
    finalRequest.httpBody = try? JSONSerialization.data(withJSONObject: body)
    
    do {
        let (stream, response) = try await URLSession.shared.bytes(for: finalRequest)
        
        logRuntime(name: "runTimeResponse", startTime: startTime)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return await handleInvalidResponse(context: context)
        }
        
        if httpResponse.statusCode != 200 {
            return await handleHTTPError(
                context: context,
                statusCode: httpResponse.statusCode,
                stream: stream
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

// MARK: - Request Building

/// Builds the API request with proper headers.
///
/// - Parameter apiKey: The Anthropic API key
/// - Returns: Configured URLRequest or nil if URL is invalid
private func buildAPIRequest(apiKey: String) -> URLRequest? {
    guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
        return nil
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    request.setValue("\(apiKey)", forHTTPHeaderField: "x-api-key")
    request.setValue("extended-cache-ttl-2025-04-11", forHTTPHeaderField: "anthropic-beta")
    
    return request
}

/// Builds the request body for the API call.
///
/// - Parameters:
///   - model: The model identifier to use
///   - modelInput: The input messages
///   - modelTools: The tools available for the model
/// - Returns: Dictionary representing the request body
private func buildRequestBody(
    model: String,
    modelInput: [[String: Any]],
    modelTools: [[String: Any]]
) -> [String: Any] {
    [
        "model": model,
        "stream": true,
        "max_tokens": getOutputToken(),
        "temperature": 0.7,
        "messages": addCacheBlock(input: nonUsageFileMessages(from: modelInput), isMessage: true),
        "tools": addCacheBlock(input: modelTools),
        "system": addCacheBlock(input: buildSystemMessages()),
    ]
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
       context.selectionHandlers.getSelectionEnabled() {
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
        "content": [[
            "type": "image",
            "source": ["type": "base64", "media_type": "image/jpeg", "data": base64],
        ]],
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
        "content": [[
            "type": "image",
            "source": ["type": "base64", "media_type": "image/jpeg", "data": appContext.base64],
        ]],
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
    startTime: Date
) async -> StreamProcessingResult {
    let accumulator = StreamAccumulator()
    var finalToolUseId = ""
    var finalToolUseName = ""
    let throttleInterval: TimeInterval = 0.05
    
    do {
        for try await line in stream.lines {
            if line.starts(with: "data: ") {
                let jsonString = line.replacingOccurrences(of: "data: ", with: "")
                
                guard let data = jsonString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let dataType = json["type"] as? String
                else { continue }
                
                switch dataType {
                case "content_block_start":
                    if let toolInfo = parseToolBlockStart(json: json) {
                        finalToolUseId = toolInfo.id
                        finalToolUseName = toolInfo.name
                    }
                    
                case "content_block_delta":
                    await handleContentBlockDelta(
                        json: json,
                        accumulator: accumulator,
                        modelOutput: &modelOutput,
                        throttleInterval: throttleInterval,
                        setModelOutput: context.modelHandlers.setModelOutput
                    )
                    
                case "content_block_stop":
                    modelOutput = await accumulator.snapshotResponse()
                    context.modelHandlers.setModelOutput(modelOutput)
                    
                case "message_delta":
                    if let result = await handleMessageDelta(
                        json: json,
                        context: context,
                        modelInput: &modelInput,
                        modelOutput: modelOutput,
                        modelTools: modelTools,
                        accumulator: accumulator,
                        finalToolUseId: finalToolUseId,
                        finalToolUseName: finalToolUseName,
                        model: model,
                        apiKey: apiKey,
                        startTime: startTime
                    ) {
                        return StreamProcessingResult(recursiveResult: result)
                    }
                    
                default:
                    continue
                }
            }
        }
    } catch {
        // Stream error handling is done in the caller
    }
    
    return StreamProcessingResult(recursiveResult: nil)
}

/// Parses tool block start information from JSON.
private func parseToolBlockStart(json: [String: Any]) -> (id: String, name: String)? {
    guard let contentBlock = json["content_block"] as? [String: Any],
          let contentBlockType = contentBlock["type"] as? String,
          contentBlockType == "tool_use",
          let id = contentBlock["id"] as? String,
          let name = contentBlock["name"] as? String
    else { return nil }
    
    return (id: id, name: name)
}

/// Handles content block delta events from the stream.
private func handleContentBlockDelta(
    json: [String: Any],
    accumulator: StreamAccumulator,
    modelOutput: inout String,
    throttleInterval: TimeInterval,
    setModelOutput: (String) -> Void
) async {
    guard let delta = json["delta"] as? [String: Any],
          let deltaType = delta["type"] as? String
    else { return }
    
    switch deltaType {
    case "text_delta":
        guard let text = delta["text"] as? String else { return }
        await accumulator.appendResponse(String(text))
        if await accumulator.shouldThrottle(now: Date(), interval: throttleInterval) {
            modelOutput = await accumulator.snapshotResponse()
            setModelOutput(modelOutput + " " + shimmerPlaceholder())
        }
        
    case "input_json_delta":
        guard let partialJson = delta["partial_json"] as? String else { return }
        await accumulator.appendToolInput(partialJson)
        
    default:
        break
    }
}

/// Handles message delta events from the stream.
///
/// - Returns: Bool result if a tool call was made and recursive execution completed, nil otherwise
private func handleMessageDelta(
    json: [String: Any],
    context: ModelCallContext,
    modelInput: inout [[String: Any]],
    modelOutput: String,
    modelTools: [[String: Any]],
    accumulator: StreamAccumulator,
    finalToolUseId: String,
    finalToolUseName: String,
    model: String,
    apiKey: String,
    startTime: Date
) async -> Bool? {
    guard let delta = json["delta"] as? [String: Any],
          let stopReason = delta["stop_reason"] as? String
    else { return nil }
    
    if !modelOutput.isEmpty {
        modelInput.append([
            "role": "assistant",
            "content": [["text": modelOutput, "type": "text"]],
        ])
        
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
                    firestoreManager: context.services.firestoreManager
                )
                tabTitle = await createTitle(context: titleContext)
                await context.tabHandlers.setTabTitle(tabTitle)
                logRuntime(name: "runTimeTitle", startTime: startTimeTitle)
            }
        }
    }
    
    switch stopReason {
    case "max_tokens":
        return nil
        
    case "tool_use":
        let toolStartTime = Date()
        
        modelInput.append([
            "role": "assistant",
            "content": [[
                "type": "tool_use",
                "id": finalToolUseId,
                "name": finalToolUseName,
                "input": parseJSONStringToDictObject(await accumulator.snapshotToolInput()),
            ]],
        ])
        
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
        
        modelInput.append([
            "role": "user",
            "content": [[
                "type": "tool_result",
                "tool_use_id": finalToolUseId,
                "content": result,
            ]],
        ])
        
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
            getManagedModels: originalContext.modelHandlers.getManagedModels
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
private func handleMissingAPIKey(context: ModelCallContext) async -> Bool {
    context.uiHandlers.setIsThinking(false)
    await context.uiHandlers.animateOutput(
        """
        API key not found. You can create one at: https://console.anthropic.com/settings/keys

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
    stream: URLSession.AsyncBytes
) async -> Bool {
    context.uiHandlers.setIsThinking(false)
    
    var error = ""
    do {
        for try await line in stream.lines {
            error += line
        }
    } catch {}
    
    if statusCode == 429 {
        await context.uiHandlers.animateOutput(
            """
            You've reached your API key's rate limit.

            Learn more: https://console.anthropic.com/settings/limits
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
            "content": [[
                "type": "text",
                "text": """
                Total Usage:
                1 \(query.isEmpty ? "Agent Use" : "Query")
                \(fileCount) Attached Files
                """,
            ]],
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
    logger.debug("\(name) \(runtime) ms")
    
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
private func logRequestDetails(apiKey: String, model: String, body: [String: Any]) {
    logger.debug("API Key: \(apiKey)")
    logger.debug("Model: \(model)")
    logger.debug("Max Tokens: \(getOutputToken())")
    logger.debug("Messages: \(String(describing: redactDataKeys(in: body["messages"] ?? [:])))")
    logger.debug("Tools Count: \((body["tools"] as? [[String: Any]])?.count ?? 0)")
}
