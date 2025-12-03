//
//  AnalyticsManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/16/25.
//

import FirebaseAnalytics
import FirebaseCore
import Foundation

// MARK: - Analytics Manager

/// Centralized analytics manager for Firebase Analytics events.
/// All analytics operations are no-op when Firebase is not configured.
final class AnalyticsManager {
    
    // MARK: - Singleton
    
    static let shared = AnalyticsManager()
    
    // MARK: - Properties
    
    private var currentUserId: String?
    
    private var isEnabled: Bool {
        FirebaseConfiguration.shared.isConfigured
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Configuration
    
    /// Configures Firebase if not already configured.
    /// Call this once early in app launch.
    func configureIfNeeded() {
        guard isEnabled else {
            FirebaseConfiguration.shared.logSkipped(operation: "configureIfNeeded")
            return
        }
        
        guard FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
    }
    
    // MARK: - User Management
    
    /// Sets or clears the current user ID for analytics tracking
    func setUserId(_ userId: String?) {
        currentUserId = userId
        
        guard isEnabled else {
            FirebaseConfiguration.shared.logSkipped(operation: "setUserId")
            return
        }
        
        Analytics.setUserID(userId)
    }
    
    // MARK: - Event Logging
    
    /// Logs a screen view event
    func screenView(screenName: EventView, screenClass: String = "SwiftUIView") {
        guard isEnabled else { return }
        
        logEvent(
            AnalyticsEventScreenView,
            parameters: [
                AnalyticsParameterScreenName: screenName.rawValue,
                AnalyticsParameterScreenClass: screenClass
            ]
        )
    }
    
    /// Logs a custom event with view context, primary/secondary categories, and severity
    func customEvent(
        view: EventView,
        primary: EventPrimary,
        secondary: String,
        sev: EventSeverity
    ) {
        guard isEnabled else { return }
        
        logEvent(
            "custom_\(view.rawValue)",
            parameters: [
                "primary": primary.rawValue,
                "secondary": secondary,
                "severity": sev.rawValue
            ]
        )
    }
    
    /// Logs an app open event
    func appOpen() {
        guard isEnabled else { return }
        logEvent(AnalyticsEventAppOpen)
    }
    
    /// Logs a login event with the specified method
    func login(method: LoginMethod) {
        guard isEnabled else { return }
        
        logEvent(
            AnalyticsEventLogin,
            parameters: [AnalyticsParameterMethod: method.rawValue]
        )
    }
    
    // MARK: - Private Methods
    
    private func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        guard isEnabled else { return }
        Analytics.logEvent(name, parameters: buildParameters(extra: parameters))
    }
    
    private func buildParameters(extra: [String: Any]? = nil) -> [String: Any] {
        var params = extra ?? [:]
        params["user_id"] = currentUserId ?? "undefined"
        return params
    }
}

// MARK: - Event Types

extension AnalyticsManager {
    
    /// Views/screens for analytics tracking
    enum EventView: String {
        // Views
        case ToolsView
        case SettingsView
        case NotchView
        case IntelligenceView
        case ChatView
        
        // Settings Tabs
        case SettingsAccountsTab
        case SettingsModelTab
        case SettingsAgentsTab
        case SettingsPreferencesTab
        case SettingsAutomationsTab
        
        // Managers
        case ScreenshotMonitor
        case GithubOAuthManager
        case GoogleOAuthManager
        case McpOAuthManager
        case McpManager
        case FirebaseManager
        case IntelligenceManager
        case AutomationManager
    }
    
    /// Primary event categories
    enum EventPrimary: String {
        // General
        case count
        case function
        case file
        case selection
        case query
        case model
        case tool
        case scope
        case url
        case quit
        case create
        
        // Features
        case useCapturedScreenshots
        case showInScreenshot
        case outputToken
        case cacheEnabled
        case bugReport
        
        // Firebase
        case firebase
        
        // MCP
        case mcpInit
        case mcpStdio
        case mcpHTTP
        case mcpStart
        case mcpStop
        case mcpReconnect
        case mcpTools
        case mcpCallTools
        
        // Agents
        case agentAdd
        case agentLoad
        
        // Navigation
        case moveUp
        case moveDown
        case dragLeft
        case dragDown
        
        // Tabs
        case createTab
        case activateTab
        case removeTabs
        
        // Performance
        case runTimeEnd
        case runTimeResponseParseEnd
        case runTimeResponseParseStart
        case runTimeResponse
        case runTimeContextBuild
        case runTimeValidations
        case runTimeDelta
        case runTimeTitle
        case runTimeTools
    }
    
    /// Event severity levels
    enum EventSeverity: String {
        case debug
        case info
        case error
        case exception
    }
    
    /// Supported login methods
    enum LoginMethod: String {
        case google
    }
}

