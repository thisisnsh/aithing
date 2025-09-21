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

    /// screen_view (manual)
    /// - Parameters:
    ///   - screenName: Name you want to appear in GA4
    ///   - screenClass: Typically the SwiftUI wrapper or host class name
    func screenView(screenName: String, screenClass: String = "SwiftUIView") {
        log(
            AnalyticsEventScreenView,
            params: [
                AnalyticsParameterScreenName: screenName,
                AnalyticsParameterScreenClass: screenClass,
            ]
        )
    }

    enum CustomEventType: String {
        case model
        case agent
        case tab
        case tool
        case cost
        case firebase
        case error
        case action
    }

    enum CustomEventSecondary: String {
        case status_failure_high
        case status_failure_med
        case status_failure_low
        case status_success
        
        case value_true
        case value_false
        
        case reconnect_attempt
        case reconnect_success
        
        case byok_model
        case managed_model
    }

    /// custom_event
    /// - Parameters:
    ///   - primary: primary value
    ///   - secondary: secondary value
    ///   - type: type [ model, agent, tab, tool, cost, firebase, error]
    ///
    func customEvent(
        type: CustomEventType,
        primary: String,
        secondary: CustomEventSecondary = .status_success
    ) {
        log(
            "custom_event",
            params: [
                "type": type.rawValue,
                "primary": primary,
                "secondary": secondary,
            ]
        )
    }

    /// app_open
    func appOpen() {
        log(AnalyticsEventAppOpen, params: nil)
    }

    /// login
    /// - Parameter method: e.g., "email", "apple", "google"
    func login(method: String) {
        log(
            AnalyticsEventLogin,
            params: [
                AnalyticsParameterMethod: method
            ]
        )
    }

    /// custom_app_quit
    func customAppQuit() {
        log(
            "custom_app_quit",
            params: [:]
        )
    }
}
