//
//  IntelligenceView+Query.swift
//  AIThing
//
//  Query handling extension for IntelligenceView.
//

import AppKit
import SwiftUI

extension IntelligenceView {
    func handleQuery() async {
        let trimmed = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else { return }

        var appContextBase64: AppContextModel? = nil
        if appContextEnabled {
            if let ss = getAppContextBase64(
                appName: selectedAppName,
                windowName: selectedWindowName
            ) {
                appContextBase64 = ss
            } else {
                appContext.refresh()
                appContextEnabled = false
                selectedAppIcon = nil
                selectedAppName = ""
                selectedWindowName = ""
                return
            }
        }

        displayQuery = trimmed
        modelOutput = ""
        isThinking = true
        toolCall = ""
        query = ""
        inputHeight = baseHeight
        showSavedQueries = false

        AnalyticsManager.shared.customEvent(
            view: .IntelligenceView,
            primary: .query,
            secondary: "start",
            sev: .info
        )

        let result = await callModel(
            tabId: tabId,
            query: trimmed,
            isTabRemoved: isTabRemoved,
            getAppContextBase64: { return appContextBase64 },
            getSelectedText: { return selectedText },
            setSelectedText: { selectedText = $0 },
            getSelectionEnabled: { return selectionEnabled },
            setSelectionEnabled: { selectionEnabled = $0 },
            getTabTitle: { return tabTitle },
            setTabTitle: {
                tabTitle = $0
                await setTitle(tabId, $0)
            },
            setDisplayQuery: { displayQuery = $0 },
            setToolCall: { toolCall = $0 },
            getHistory: { return await self.getHistory($0) },
            storeHistory: { await storeHistory($0, $1) },
            setHistory: { history = $0 },
            setIsThinking: { isThinking = $0 },
            getModelInput: { return modelInput },
            setModelInput: { modelInput = $0 },
            getModelOutput: { return modelOutput },
            setModelOutput: { modelOutput = $0 },
            animateOutput: { await self.animateOutput($0) },
            getAllClientTools: { return allClientTools },
            getUsedTools: { return [] },
            getModelContext: { return modelContext },
            clearModelContext: { modelContext.removeAll() },
            getManagedModels: { return managedModels },
            updateHistoryList: updateHistoryList,
            firestoreManager: firestoreManager,
            loginManager: loginManager,
            mcpManager: mcpManager,
            automationManager: automationManager,
            aiThingMcpManager: aiThingMcpManager
        )

        if isTabRemoved() {
            logger.debug("Stop the query after tab removal")
            return
        }

        if !isTabShowing() {
            await setUnseen(tabId, true)
        } else {
            await setUnseen(tabId, false)
        }

        appContext.refresh()
        appContextEnabled = false
        selectedAppIcon = nil
        selectedAppName = ""
        selectedWindowName = ""

        AnalyticsManager.shared.customEvent(
            view: .IntelligenceView,
            primary: .query,
            secondary: "end",
            sev: .info
        )

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

    func animateOutput(_ content: String) async {
        var partial = ""
        for text in content.split(separator: " ") {
            partial += String(text) + " "
            await MainActor.run {
                modelOutput = partial + " " + shimmerPlaceholder()
            }
            do {
                try await Task.sleep(for: .milliseconds(10))
            } catch {}
        }
        modelOutput = partial
    }

    func shimmerPlaceholder() -> String {
        return "▌"  // or use "…" or a flashing cursor symbol
    }

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

