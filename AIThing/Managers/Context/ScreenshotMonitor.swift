//
//  ScreenshotMonitor.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 10/12/25.
//

import AppKit
import SwiftUI

// Screenshot Monitor that watches for new screenshots
class ScreenshotMonitor: ObservableObject {
    @Published var latestScreenshot: ScreenshotData?

    private var timer: Timer?
    private var screenshotDirectory: URL?
    private var lastKnownFiles: Set<String> = []
    private var initialized: Bool = false
    private var canCheckScreenshot: Bool = false

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

    func open() {
        canCheckScreenshot = true
    }

    func close() {
        canCheckScreenshot = false
    }

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

    func deinitialize() {
        if !initialized { return }
        timer?.invalidate()
        initialized = false
    }

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

    private func startMonitoring() {
        // Check for new screenshots every 1 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            if self?.canCheckScreenshot ?? false {
                self?.checkForNewScreenshots()
            }
        }
    }

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
