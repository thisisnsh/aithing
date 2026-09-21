//
//  ScreenshotMonitor.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 10/12/25.
//

import AppKit
import SwiftUI

// MARK: - Screenshot Monitor

/// Monitors the file system for newly captured screenshots.
///
/// Watches the user's configured screenshot directory (typically Desktop)
/// for new screenshot files and publishes them as they appear.
class ScreenshotMonitor: ObservableObject {
    /// The most recently captured screenshot, if any
    @Published var latestScreenshot: ScreenshotData?

    private var timer: Timer?
    private var screenshotDirectory: URL?
    private var lastKnownFiles: Set<String> = []
    private var initialized: Bool = false
    private var canCheckScreenshot: Bool = false

    /// Container for screenshot data
    struct ScreenshotData: Identifiable {
        let id = UUID()
        let image: NSImage
        let url: URL
        let timestamp: Date
    }

    init() {
        initialize()
    }

    deinit {
        deinitialize()
    }

    /// Enables screenshot monitoring.
    ///
    /// Call this when the user opens the window/panel to start checking for screenshots.
    func open() {
        canCheckScreenshot = true
    }

    /// Disables screenshot monitoring.
    ///
    /// Call this when the user closes the window/panel to pause screenshot detection.
    func close() {
        canCheckScreenshot = false
    }

    /// Initializes the screenshot monitoring system.
    ///
    /// Sets up the screenshot directory and starts the monitoring timer.
    /// Only runs if the feature is enabled in user preferences.
    func initialize() {
        if initialized { return }
        if getUseCapturedScreenshots() {
            // Get the screenshot directory from system preferences
            screenshotDirectory = Self.getScreenshotDirectory()

            // Initialize with current files
            updateKnownFiles()

            // Start monitoring
            startMonitoring()

            initialized = true
        }
    }

    /// Stops the screenshot monitoring and cleans up resources.
    func deinitialize() {
        if !initialized { return }
        timer?.invalidate()
        initialized = false
    }

    /// Gets the user's configured screenshot save directory.
    ///
    /// Checks multiple sources in order:
    /// 1. UserDefaults for com.apple.screencapture.location
    /// 2. The screencapture plist file
    /// 3. The `defaults` command via shell
    /// 4. Falls back to Desktop if none found
    ///
    /// - Returns: The URL of the screenshot directory
    private static func getScreenshotDirectory() -> URL {
        // Try to get the screenshot location from defaults
        if let screenshotPath = UserDefaults.standard.string(
            forKey: "com.apple.screencapture.location"
        ),
            !screenshotPath.isEmpty
        {
            let url = URL(fileURLWithPath: screenshotPath)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        // Try reading from screencapture plist
        let plistPath = NSHomeDirectory() + "/Library/Preferences/com.apple.screencapture.plist"
        if let plistData = NSDictionary(contentsOfFile: plistPath),
            let location = plistData["location"] as? String
        {
            let url = URL(fileURLWithPath: location)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        // Try using defaults command via shell
        let task = Process()
        task.launchPath = "/usr/bin/defaults"
        task.arguments = ["read", "com.apple.screencapture", "location"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                    !output.isEmpty
                {
                    let url = URL(fileURLWithPath: output)
                    if FileManager.default.fileExists(atPath: url.path) {
                        return url
                    }
                }
            }
        } catch { }

        // Fallback to Desktop
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
    }

    /// Starts the monitoring timer.
    ///
    /// Checks for new screenshots every second when monitoring is enabled.
    private func startMonitoring() {
        // Check for new screenshots every 1 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            if self?.canCheckScreenshot ?? false {
                self?.checkForNewScreenshots()
            }
        }
    }

    /// Updates the baseline of known files to the current directory state.
    ///
    /// Call this to reset what files are considered "new" - typically when
    /// the user dismisses the latest screenshot notification.
    func updateKnownFiles() {
        guard let screenshotDirectory = screenshotDirectory else { return }
        guard
            let contents = try? FileManager.default.contentsOfDirectory(
                at: screenshotDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        else { return }

        lastKnownFiles = Set(contents.map { $0.lastPathComponent })
        latestScreenshot = nil
    }

    /// Checks for new screenshot files in the monitored directory.
    ///
    /// Compares the current directory contents against the last known state
    /// and processes any new files that match the screenshot naming pattern.
    private func checkForNewScreenshots() {
        guard let screenshotDirectory = screenshotDirectory else { return }
        guard
            let contents = try? FileManager.default.contentsOfDirectory(
                at: screenshotDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )
        else { return }

        let currentFiles = Set(contents.map { $0.lastPathComponent })
        let newFiles = currentFiles.subtracting(lastKnownFiles)

        // Filter for screenshot files
        let newScreenshots = contents.filter { url in
            let name = url.lastPathComponent
            return newFiles.contains(name)
                && (name.hasPrefix("Screenshot") || name.hasPrefix("Screen Shot"))
                && (url.pathExtension.lowercased() == "png"
                    || url.pathExtension.lowercased() == "jpg"
                    || url.pathExtension.lowercased() == "jpeg")
        }

        // Process the newest screenshot
        if let newestScreenshot = newScreenshots.sorted(by: { url1, url2 in
            let date1 =
                (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate
                ?? Date.distantPast
            let date2 =
                (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate
                ?? Date.distantPast
            return date1 > date2
        }).first {
            processScreenshot(url: newestScreenshot)
        }

        // Update known files
        lastKnownFiles = currentFiles
    }

    /// Processes a new screenshot file and publishes it.
    ///
    /// Loads the image and metadata, then updates `latestScreenshot`.
    /// Includes a small delay to ensure the file is fully written to disk.
    ///
    /// - Parameter url: The URL of the screenshot file
    private func processScreenshot(url: URL) {
        // Small delay to ensure file is fully written
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            if let image = NSImage(contentsOf: url),
                let creationDate = (try? url.resourceValues(forKeys: [.creationDateKey]))?
                    .creationDate
            {

                self?.latestScreenshot = ScreenshotData(
                    image: image,
                    url: url,
                    timestamp: creationDate
                )
            }
        }
    }
}
