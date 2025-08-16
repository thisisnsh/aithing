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

    /// select_item (GA4)
    /// - Parameters:
    ///   - itemID: your internal ID
    ///   - itemName: human readable name
    ///   - itemCategory: optional category
    ///   - listName: optional list context (e.g., "Search Results")
    func selectItem(
        itemID: String,
        itemName: String,
        itemCategory: String? = nil,
        listName: String? = nil
    ) {
        var params: [String: Any] = [
            AnalyticsParameterItemID: itemID,
            AnalyticsParameterItemName: itemName,
        ]
        if let cat = itemCategory { params[AnalyticsParameterItemCategory] = cat }
        if let listName { params[AnalyticsParameterItemListName] = listName }
        log(AnalyticsEventSelectItem, params: params)
    }

    /// select_content (legacy but still accepted by GA4 backends)
    /// - Parameters:
    ///   - contentType: e.g., "article", "video"
    ///   - itemID: ID of the content
    func selectContent(contentType: String, itemID: String) {
        log(
            AnalyticsEventSelectContent,
            params: [
                AnalyticsParameterContentType: contentType,
                AnalyticsParameterItemID: itemID,
            ]
        )
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

    /// app_open
    func appOpen() {
        log(AnalyticsEventAppOpen, params: nil)
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

    /// custom_app_quit
    func customAppQuit() {
        log(
            "custom_app_quit",
            params: [:]
        )
    }

    /// custom_event_model
    /// - Parameters:
    ///   - name: model name
    ///   - type: model type
    func customEventModel(name: String, type: String) {
        log(
            "custom_event_model",
            params: [
                "model_name": name,
                "model_type": type,
            ]
        )
    }

    /// custom_event_agent
    /// - Parameter agent: agent name
    func customEventAgent(agent: String) {
        log(
            "custom_event_agent",
            params: [
                "agent_name": agent
            ]
        )
    }

    /// custom_event_tab
    /// - Parameter action: e.g., "open", "close", "switch"
    func customEventTab(action: String) {
        log(
            "custom_event_tab",
            params: [
                "action": action
            ]
        )
    }

    /// custom_error
    /// - Parameters:
    ///   - type: e.g., "network", "api", "validation"
    ///   - severity: e.g., "info", "warning", "error", "critical"
    ///   - location: where in the app it happened, e.g., "LoginView"
    func customError(type: String, severity: String, location: String) {
        log(
            "custom_error",
            params: [
                "type": type,
                "severity": severity,
                "location": location,
            ]
        )
    }
}
