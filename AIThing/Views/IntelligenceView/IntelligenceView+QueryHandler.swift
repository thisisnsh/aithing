//
//  IntelligenceView+QueryHandler.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 11/1/25.
//

import AppKit
import SwiftUI

extension IntelligenceView {

    // MARK: - Query Handling

    /// Handles the submission and execution of a user query.
    ///
    /// This method:
    /// 1. Validates and prepares the query
    /// 2. Captures app context if enabled
    /// 3. Builds the model call context
    /// 4. Executes the model call
    /// 5. Cleans up state after completion
    func handleQuery() async {
        showRefreshButton = false
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Capture app context if enabled
        var appContextBase64: AppContextModel? = nil
        if appContextEnabled {
            if let ss = getAppContextBase64(appName: selectedAppName, windowName: selectedWindowName) {
                appContextBase64 = ss
            } else {
                resetAppContext()
                return
            }
        }

        // Prepare UI state
        prepareUIForQuery(trimmed)

        // Build and execute the model call
        let context = buildModelCallContext(
            query: trimmed,
            appContextBase64: appContextBase64
        )
        let result = await callModel(context: context)

        // Handle post-query state
        await handleQueryCompletion(result: result)
    }

    // MARK: - Context Building

    /// Builds the complete model call context from current state.
    ///
    /// - Parameters:
    ///   - query: The trimmed query string
    ///   - appContextBase64: Optional app context screenshot
    /// - Returns: Configured ModelCallContext
    private func buildModelCallContext(
        query: String,
        appContextBase64: AppContextModel?
    ) -> ModelCallContext {
        ModelCallContext(
            tabId: tabId,
            query: query,
            tabHandlers: buildTabHandlers(),
            selectionHandlers: buildSelectionHandlers(),
            modelHandlers: buildModelHandlers(),
            historyHandlers: buildHistoryHandlers(),
            uiHandlers: buildUIHandlers(),
            toolHandlers: buildToolHandlers(appContextBase64: appContextBase64),
            services: buildServices()
        )
    }

    /// Builds tab handlers for the model call context.
    private func buildTabHandlers() -> TabHandlers {
        TabHandlers(
            isTabRemoved: isTabRemoved,
            getTabTitle: { [self] in tabTitle },
            setTabTitle: { [self] newTitle in
                tabTitle = newTitle
                await setTitle(tabId, newTitle)
            }
        )
    }

    /// Builds selection handlers for the model call context.
    private func buildSelectionHandlers() -> SelectionHandlers {
        SelectionHandlers(
            getSelectedText: { [self] in selectedText },
            setSelectedText: { [self] text in selectedText = text },
            getSelectionEnabled: { [self] in selectionEnabled },
            setSelectionEnabled: { [self] enabled in selectionEnabled = enabled }
        )
    }

    /// Builds model state handlers for the model call context.
    private func buildModelHandlers() -> ModelHandlers {
        ModelHandlers(
            getModelInput: { [self] in modelInput },
            setModelInput: { [self] input in modelInput = input },
            getModelOutput: { [self] in modelOutput },
            setModelOutput: { [self] output in modelOutput = output },
            getModelContext: { [self] in modelContext },
            clearModelContext: { [self] in modelContext.removeAll() },
            getAllModels: { [self] in allModels }
        )
    }

    /// Builds history handlers for the model call context.
    private func buildHistoryHandlers() -> HistoryHandlers {
        HistoryHandlers(
            getHistory: { [self] id in await getHistory(id) },
            storeHistory: { [self] id, history in await storeHistory(id, history) },
            setHistory: { [self] hist in history = hist },
            updateHistoryList: { [self] in await updateHistoryList() }
        )
    }

    /// Builds UI handlers for the model call context.
    private func buildUIHandlers() -> UIHandlers {
        UIHandlers(
            setDisplayQuery: { [self] q in displayQuery = q },
            setToolCall: { [self] tool in toolCall = tool },
            setIsThinking: { [self] thinking in isThinking = thinking },
            animateOutput: { [self] content in await animateOutput(content) }
        )
    }

    /// Builds tool handlers for the model call context.
    ///
    /// - Parameter appContextBase64: Optional app context screenshot
    /// - Returns: Configured ToolHandlers
    private func buildToolHandlers(appContextBase64: AppContextModel?) -> ToolHandlers {
        ToolHandlers(
            getAllClientTools: { [self] in allClientTools },
            getUsedTools: { [] },
            getAppContextBase64: { appContextBase64 }
        )
    }

    /// Builds service dependencies for the model call context.
    private func buildServices() -> ModelCallServices {
        ModelCallServices(
            firestoreManager: firestoreManager,
            loginManager: loginManager,
            connectionManager: connectionManager,
            automationManager: automationManager,
            internalToolProvider: internalToolProvider
        )
    }

    // MARK: - UI State Management

    /// Prepares the UI state before executing a query.
    ///
    /// - Parameter trimmedQuery: The trimmed query string
    private func prepareUIForQuery(_ trimmedQuery: String) {
        displayQuery = buildQuery(query: trimmedQuery)
        modelOutput = ""
        isThinking = true
        toolCall = ""
        query = ""
        inputHeight = baseHeight
        showSavedQueries = false
    }

    /// Handles cleanup after query completion.
    ///
    /// - Parameter result: Whether the query was successful
    private func handleQueryCompletion(result: Bool) async {
        if isTabRemoved() {
            logger.debug("Stop the query after tab removal")
            return
        }

        // Update unseen status based on tab visibility
        if !isTabShowing() {
            await setUnseen(tabId, true)
        } else {
            await setUnseen(tabId, false)
        }

        // Reset app context state
        resetAppContext()

        // Reset selection and UI state
        viewModel.selectedText = ""
        selectedText = ""
        selectionEnabled = false
        displayQuery = ""
        toolCall = ""
        isThinking = false

        if result {
            modelOutput = ""
        }
    }

    /// Resets the app context state to defaults.
    private func resetAppContext() {
        appContext.refresh()
        appContextEnabled = false
        selectedAppIcon = nil
        selectedAppName = ""
        selectedWindowName = ""
    }

    // MARK: - App Context Capture

    /// Captures the current app context as a screenshot.
    ///
    /// - Parameters:
    ///   - appName: The name of the app to capture
    ///   - windowName: Optional window title to capture
    /// - Returns: AppContextModel with screenshot data, or nil if capture fails
    func getAppContextBase64(appName: String, windowName: String?) -> AppContextModel? {
        if !appContextEnabled || appName.isEmpty {
            return nil
        }

        let (image, error) = captureWindow(
            appName: appName,
            windowTitle: windowName
        )

        if let image = image {
            let thumb = image.resized(maxDimension: 1024)
            guard let data = thumb.jpegData() else {
                return nil
            }
            return AppContextModel(
                appName: selectedAppName,
                windowName: selectedWindowName,
                screenshot: thumb,
                base64: data.base64EncodedString()
            )
        }

        if let error = error {
            toastText = ""
            toastText = error
        }
        return nil
    }

    // MARK: - Output Animation

    /// Animates the output text word by word.
    ///
    /// - Parameter content: The content to animate
    func animateOutput(_ content: String, delay: Int = 10) async {
        var partial = ""
        for text in content.split(separator: " ") {
            partial += String(text) + " "
            await MainActor.run {
                modelOutput = partial + " " + shimmerPlaceholder()
            }
            do {
                try await Task.sleep(for: .milliseconds(delay))
            } catch {}
        }
        modelOutput = partial
    }

    // MARK: - Date Formatting

    /// Formats an epoch timestamp to a localized date string.
    ///
    /// - Parameters:
    ///   - epochS: The epoch timestamp as a string
    ///   - format: The date format string (defaults to "MMMM, dd yyyy HH:mm")
    /// - Returns: The formatted date string, or nil if parsing fails
    func formatEpochLocal(_ epochS: String, format: String = "MMMM, dd yyyy HH:mm") -> String? {
        if let epoch = Double(epochS) {
            let date = Date(timeIntervalSince1970: epoch)
            let formatter = DateFormatter()
            formatter.dateFormat = format
            return formatter.string(from: date)
        } else {
            return nil
        }
    }
}
