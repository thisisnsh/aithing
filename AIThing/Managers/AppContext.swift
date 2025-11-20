//
//  AppContext.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/12/25.
//

import AppKit
import ApplicationServices
import Foundation

struct AppContextModel {
    let appName: String
    let windowName: String
    let base64: String
}

class AppContext: ObservableObject {
    @Published var appName: String = ""
    @Published var windowName: String = ""
    @Published var appIcon: NSImage?

    func refresh() {
        let context = getAppContext()

        self.appName = context.appName
        if context.windowTitle.count > 32 {
            self.windowName = String(context.windowTitle.prefix(32) + "...")
        } else {
            self.windowName = context.windowTitle
        }
        self.appIcon = context.appIcon
    }

    private func getAppContext() -> (appName: String, windowTitle: String, appIcon: NSImage?) {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return ("", "", nil)
        }

        let appName = app.localizedName ?? ""
        let icon = app.icon

        // Get the app’s frontmost window by matching process ID
        let pid = app.processIdentifier

        guard
            let infoList = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]]
        else { return (appName, "", icon) }

        // Find the *topmost* window matching the PID
        let window = infoList.first { window in
            guard
                let windowPID = window[kCGWindowOwnerPID as String] as? pid_t,
                windowPID == pid,
                let layer = window[kCGWindowLayer as String] as? Int,
                layer == 0  // real window layer
            else { return false }
            return true
        }

        let windowTitle = window?[kCGWindowName as String] as? String

        return (appName, windowTitle ?? "", icon)
    }
}
