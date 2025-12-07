//
//  IntelligenceModels.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 12/5/25.
//

import Foundation
import MCP

// MARK: - Model Call Context

/// Contains all state and callbacks needed for model execution.
/// Groups related parameters to reduce function argument count.
struct ModelCallContext {
    /// Unique identifier for the current tab
    let tabId: String
    
    /// The user's query to process
    let query: String
    
    /// Handlers for tab state management
    let tabHandlers: TabHandlers
    
    /// Handlers for selection state management
    let selectionHandlers: SelectionHandlers
    
    /// Handlers for model state management
    let modelHandlers: ModelHandlers
    
    /// Handlers for history operations
    let historyHandlers: HistoryHandlers
    
    /// Handlers for UI updates
    let uiHandlers: UIHandlers
    
    /// Handlers for tool operations
    let toolHandlers: ToolHandlers
    
    /// Service dependencies for the model call
    let services: ModelCallServices
}

// MARK: - Handler Structs

/// Handlers for tab state management
struct TabHandlers {
    /// Checks if the current tab has been removed
    let isTabRemoved: () -> Bool
    
    /// Gets the current tab title
    let getTabTitle: () -> String
    
    /// Sets the tab title asynchronously
    let setTabTitle: @Sendable (String) async -> Void
}

/// Handlers for selection state management
struct SelectionHandlers {
    /// Gets the currently selected text
    let getSelectedText: () -> String
    
    /// Sets the selected text
    let setSelectedText: (String) -> Void
    
    /// Gets whether selection is enabled
    let getSelectionEnabled: () -> Bool
    
    /// Sets whether selection is enabled
    let setSelectionEnabled: (Bool) -> Void
}

/// Handlers for model state management
struct ModelHandlers {
    /// Gets the current model input messages
    let getModelInput: () -> [ChatItem]
    
    /// Sets the model input messages
    let setModelInput: @Sendable ([ChatItem]) -> Void
    
    /// Gets the current model output
    let getModelOutput: () -> String
    
    /// Sets the model output
    let setModelOutput: (String) -> Void
    
    /// Gets the current model context (dropped files, etc.)
    let getModelContext: () -> [DroppedContent]
    
    /// Clears the model context
    let clearModelContext: () -> Void
    
    /// Gets all available managed models
    let getAllModels: () -> [ModelInfo]
}

/// Handlers for history operations
struct HistoryHandlers {
    /// Gets history for a tab ID
    let getHistory: (String) async -> History?
    
    /// Stores history for a tab ID
    let storeHistory: (String, [ChatItem]) async -> Void
    
    /// Sets the current history state
    let setHistory: (History?) -> Void
    
    /// Updates the history list in the sidebar
    let updateHistoryList: @Sendable () async -> Void
}

/// Handlers for UI updates
struct UIHandlers {
    /// Sets the display query shown in the UI
    let setDisplayQuery: (String) -> Void
    
    /// Sets the current tool call status
    let setToolCall: (String) -> Void
    
    /// Sets whether the model is thinking
    let setIsThinking: (Bool) -> Void
    
    /// Animates output text in the UI
    let animateOutput: (String) async -> Void
}

/// Handlers for tool operations
struct ToolHandlers {
    /// Gets all client tools organized by client name
    let getAllClientTools: () -> [String: [Tool]]
    
    /// Gets the tools being used in current execution
    let getUsedTools: () -> [Tool]
    
    /// Gets the application context as base64 encoded image
    let getAppContextBase64: () -> AppContextModel?
}

/// Service dependencies for the model call
struct ModelCallServices {
    /// Firestore database manager
    let firestoreManager: FirestoreManager
    
    /// User authentication manager
    let loginManager: LoginManager
    
    /// MCP connection manager
    let connectionManager: ConnectionManager
    
    /// Automation scheduling manager
    let automationManager: AutomationManager
    
    /// Internal tool provider for native tools
    let internalToolProvider: InternalToolProvider
}

// MARK: - Validation Contexts

/// Context containing dependencies for Firebase config validation.
struct ValidationContext {
    /// Firestore manager for fetching config values
    let firestoreManager: FirestoreManager
    
    /// Callback to update the thinking state
    let setIsThinking: (Bool) -> Void
    
    /// Callback to animate output messages
    let animateOutput: (String) async -> Void
}

/// Context containing dependencies for login validation.
struct LoginValidationContext {
    /// Authentication manager for checking login state
    let loginManager: LoginManager
    
    /// Firestore manager for fetching user profile
    let firestoreManager: FirestoreManager
    
    /// Callback to update the thinking state
    let setIsThinking: (Bool) -> Void
    
    /// Callback to animate output messages
    let animateOutput: (String) async -> Void
}

// MARK: - Title Generation Context

/// Context containing all parameters needed for title generation.
struct TitleGenerationContext {
    /// The user's query text
    let query: String
    
    /// The AI's response text
    let response: String
    
    /// The model identifier to use for generation
    let model: String
    
    /// The API key for authentication
    let apiKey: String
    
    /// The current tab title (used as fallback)
    let tabTitle: String
    
    /// Firestore manager for config checks
    let firestoreManager: FirestoreManager
    
    /// The AI provider for the model
    let provider: AIProvider
}

