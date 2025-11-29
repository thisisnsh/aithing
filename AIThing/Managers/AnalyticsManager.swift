//
//  AnalyticsManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/16/25.
//

import FirebaseAnalytics
import FirebaseCore
import Foundation

final class AnalyticsManager {
    static let shared = AnalyticsManager()
    private init() {}

    // Keep our local copy (also set in Firebase)
    private var currentUserId: String?

    /// Call this once early in app launch (e.g., in your App.init).
    func configureIfNeeded() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    /// Set/clear the user ID. This sets Firebase's userID and also gets sent with every event as a param.
    func setUserId(_ userId: String?) {
        currentUserId = userId
        Analytics.setUserID(userId)
    }

    private func baseParams(_ extra: [String: Any]? = nil) -> [String: Any] {
        var params = extra ?? [:]
        if let uid = currentUserId {
            // Send alongside the event. (Firebase already knows userID from setUserID.)
            params["user_id"] = uid
        } else {
            params["user_id"] = "undefined"
        }
        return params
    }

    private func log(_ name: String, params: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: baseParams(params))
    }

    enum CustomEventView: String {
        case ToolsView
        case SettingsView
        case NotchView
        case IntelligenceView
        case ChatView

        case SettingsAccountsTab
        case SettingsModelTab
        case SettingsAgentsTab
        case SettingsPreferencesTab
        case SettingsAutomationsTab

        case ScreenshotMonitor
        case GithubOAuthManager
        case GoogleOAuthManager
        case McpOAuthManager
        case McpManager
        case FirebaseManager
        case IntelligenceManager
        case AutomationManager
    }

    /// screen_view (manual)
    /// - Parameters:
    ///   - screenName: Name you want to appear in GA4
    ///   - screenClass: Typically the SwiftUI wrapper or host class name
    func screenView(screenName: CustomEventView, screenClass: String = "SwiftUIView") {
        log(
            AnalyticsEventScreenView,
            params: [
                AnalyticsParameterScreenName: screenName.rawValue,
                AnalyticsParameterScreenClass: screenClass,
            ]
        )
    }

    enum CustomEventPrimary: String {
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

        case useCapturedScreenshots
        case showInScreenshot
        case outputToken
        case cacheEnabled
        case bugReport

        case firebase

        case mcpInit
        case mcpStdio
        case mcpHTTP
        case mcpStart
        case mcpStop
        case mcpReconnect
        case mcpTools
        case mcpCallTools

        case agentAdd
        case agentLoad

        case moveUp
        case moveDown
        case dragLeft
        case dragDown

        case createTab
        case activateTab
        case removeTabs

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

    enum CustomEventSev: String {
        case debug
        case info
        case error
        case exception
    }

    /// custom_event
    /// - Parameters:
    ///   - primary: primary value
    ///   - secondary: secondary value
    ///   - type: type [ model, agent, tab, tool, cost, firebase, error]
    ///
    func customEvent(
        view: CustomEventView,
        primary: CustomEventPrimary,
        secondary: String,
        sev: CustomEventSev,
    ) {
        log(
            "custom_\(view)",
            params: [
                "primary": primary.rawValue,
                "secondary": secondary,
                "severity": sev.rawValue,
            ]
        )
    }

    /// app_open
    func appOpen() {
        log(AnalyticsEventAppOpen, params: nil)
    }

    enum LoginMethod: String {
        case google
    }

    /// login
    /// - Parameter method: e.g., "email", "apple", "google"
    func login(method: LoginMethod) {
        log(
            AnalyticsEventLogin,
            params: [
                AnalyticsParameterMethod: method.rawValue
            ]
        )
    }
}
