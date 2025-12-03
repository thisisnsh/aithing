//
//  ScreenshotManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 11/19/25.
//

import AppKit
import CoreGraphics

// MARK: - Window Capture

/// Captures a screenshot of a window belonging to a specific application.
///
/// Uses `.optionIncludingWindow` to capture only the specified window,
/// excluding any overlapping windows.
///
/// - Parameters:
///   - appName: The application's visible name (e.g., "Safari")
///   - windowTitle: The exact window title. If nil, captures the first matching window
/// - Returns: Tuple containing the captured image (or nil) and an error message (or nil)
func captureWindow(appName: String, windowTitle: String? = nil) -> (NSImage?, String?) {
    // Check screen capture access
    guard hasScreenCaptureAccess() else {
        return (nil, "Allow screen capture access in Settings > Privacy > Screen Recording")
    }
    
    // Get visible windows
    guard let windowInfoList = getVisibleWindowList() else {
        return (nil, "Unable to get visible screen")
    }
    
    // Find matching window
    guard let windowInfo = findMatchingWindow(
        appName: appName,
        windowTitle: windowTitle,
        windowList: windowInfoList
    ) else {
        return (nil, "Unable to get selected screen")
    }
    
    // Capture the window
    guard let image = captureWindowImage(windowID: windowInfo.id) else {
        return (nil, "Unable to capture screen")
    }
    
    return (image, nil)
}

// MARK: - Private Helpers

/// Checks if the app has screen capture access.
///
/// Prompts the user for access if not already granted.
///
/// - Returns: `true` if access is granted
private func hasScreenCaptureAccess() -> Bool {
    CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess()
}

/// Gets the list of visible on-screen windows.
///
/// - Returns: Array of window info dictionaries, or nil if unavailable
private func getVisibleWindowList() -> [[String: Any]]? {
    CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements],
        kCGNullWindowID
    ) as? [[String: Any]]
}

/// Window information for capture selection.
private struct WindowInfo {
    let id: CGWindowID
    let layer: Int
    let number: Int
}

/// Finds the best matching window for the given criteria.
///
/// - Parameters:
///   - appName: The application name to match
///   - windowTitle: Optional window title to match
///   - windowList: List of window info dictionaries
/// - Returns: Window info for the best match, or nil if not found
private func findMatchingWindow(
    appName: String,
    windowTitle: String?,
    windowList: [[String: Any]]
) -> WindowInfo? {
    let matches = windowList.compactMap { info -> WindowInfo? in
        guard let owner = info[kCGWindowOwnerName as String] as? String,
              owner == appName,
              let windowID = info[kCGWindowNumber as String] as? UInt32,
              let layer = info[kCGWindowLayer as String] as? Int
        else { return nil }
        
        // If a title is specified, filter by it
        if let title = windowTitle, !title.isEmpty {
            let name = (info[kCGWindowName as String] as? String) ?? ""
            if name != title { return nil }
        }
        
        return WindowInfo(id: windowID, layer: layer, number: Int(windowID))
    }
    
    // Sort to get the topmost window (lowest layer, then highest window number)
    return matches.sorted { a, b in
        if a.layer == b.layer { return a.number > b.number }
        return a.layer < b.layer
    }.first
}

/// Captures an image of a specific window.
///
/// - Parameter windowID: The window ID to capture
/// - Returns: The captured image, or nil if capture fails
private func captureWindowImage(windowID: CGWindowID) -> NSImage? {
    guard let cgImage = CGWindowListCreateImage(
        .null,
        .optionIncludingWindow,
        windowID,
        [.boundsIgnoreFraming, .bestResolution, .shouldBeOpaque]
    ) else {
        return nil
    }
    
    return NSImage(cgImage: cgImage, size: .zero)
}
