//
//  ScreenshotManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 11/19/25.
//

import AppKit

/// Capture a screenshot of a window belonging to an app name + window title.
/// This uses `.optionIncludingWindow`, so overlapping windows are removed.
/// - Parameters:
///   - appName: The app's visible name (e.g. "Safari").
///   - windowTitle: The exact window title. If nil, the first matching window is chosen.
/// - Returns: An NSImage containing the window’s image, or nil if not found.
func captureWindow(appName: String, windowTitle: String? = nil) -> NSImage? {

    // Get visible on-screen windows
    guard
        let windowInfoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]]
    else {
        return nil
    }

    // Find the window that matches the app + title
    let matches = windowInfoList.compactMap { info -> (id: CGWindowID, layer: Int, num: Int)? in
        guard
            let owner = info[kCGWindowOwnerName as String] as? String,
            owner == appName,
            let windowID = info[kCGWindowNumber as String] as? UInt32,
            let layer = info[kCGWindowLayer as String] as? Int
        else { return nil }

        if let title = windowTitle, !title.isEmpty {
            let name = (info[kCGWindowName as String] as? String) ?? ""
            if name != title { return nil }
        }

        return (id: windowID, layer: layer, num: Int(windowID))
    }

    guard
        let best = matches.sorted(by: { a, b in
            if a.layer == b.layer { return a.num > b.num }
            return a.layer < b.layer
        }).first
    else {
        return nil
    }

    // Capture the window image only (ignores overlapping windows)
    guard
        let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            best.id,
            [.boundsIgnoreFraming, .bestResolution, .shouldBeOpaque]
        )
    else {
        return nil
    }

    return NSImage(cgImage: cgImage, size: .zero)
}
