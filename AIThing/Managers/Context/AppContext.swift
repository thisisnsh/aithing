//
//  AppContext.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import AppKit
import ApplicationServices
import Foundation

// MARK: - App Context

/// Manages the current application context including the frontmost app and window information.
///
/// This observable object tracks:
/// - The name of the currently focused application
/// - The title of the current window
/// - The application icon
class AppContext: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The name of the frontmost application
    @Published var appName: String = ""
    
    /// The title of the frontmost window
    @Published var windowName: String = ""
    
    /// The icon of the frontmost application
    @Published var appIcon: NSImage?
    
    // MARK: - Public Methods
    
    /// Refreshes the context with the current frontmost application information.
    ///
    /// Updates `appName`, `windowName`, and `appIcon` with the current state.
    func refresh() {
        let context = getAppContext()
        
        self.appName = context.appName
        self.windowName = context.windowTitle
        self.appIcon = context.appIcon
    }
    
    // MARK: - Private Methods
    
    /// Retrieves the current application context.
    ///
    /// - Returns: Tuple containing app name, window title, and app icon
    private func getAppContext() -> (appName: String, windowTitle: String, appIcon: NSImage?) {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return ("", "", nil)
        }
        
        let appName = app.localizedName ?? ""
        let icon = app.icon
        
        // Get the app's frontmost window by matching process ID
        let pid = app.processIdentifier
        
        // Skip if the frontmost app is our own app
        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            return ("", "", nil)
        }
        
        let windowTitle = getWindowTitle(for: pid)
        
        return (appName, windowTitle, icon)
    }
    
    /// Gets the window title for a process by its PID.
    ///
    /// - Parameter pid: The process identifier
    /// - Returns: The window title, or empty string if not found
    private func getWindowTitle(for pid: pid_t) -> String {
        guard let infoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return ""
        }
        
        // Find the topmost window matching the PID
        let window = infoList.first { window in
            guard let windowPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  windowPID == pid,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0  // real window layer
            else { return false }
            return true
        }
        
        return window?[kCGWindowName as String] as? String ?? ""
    }
}
