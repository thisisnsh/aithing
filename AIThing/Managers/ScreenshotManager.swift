//
//  ScreenshotManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/26/25.
//

import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

// MARK: - ScreenshotManager

class ScreenshotManager: ObservableObject {

    func cancelScreenshot() {
        SelectionOverlay.cancelActive()
    }

    /// Captures the screen under the mouse pointer and returns (NSImage, base64 string).
    func captureScreenUnderMouse() async -> (NSImage, String)? {
        do {
            guard let display = try await getDisplayUnderMouse() else {
                print("No display under mouse")
                return nil
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = display.width
            config.height = display.height
            config.showsCursor = false

            let output = FrameCaptureHandler()
            let stream = SCStream(filter: filter, configuration: config, delegate: nil)
            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .main)

            // Wait for a frame to arrive (basic signaling)
            try await stream.startCapture()
            try await Task.sleep(nanoseconds: 300_000_000)
            try await stream.stopCapture()

            guard let image = output.capturedImage else {
                return nil
            }

            if let jpegData = image.jpegData() {
                let base64 = jpegData.base64EncodedString()
                return (image, base64)
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }

    /// Darkens only the screen under the mouse, lets the user drag a rect *or click*, then captures using ScreenCaptureKit.
    /// - Drag: returns cropped region
    /// - Click: captures the app window at the click point; if none, captures whole screen
    /// Reuses `getDisplayUnderMouse()` to choose the display. Returns (NSImage, base64) or nil if cancelled.
    func captureSelectedScreenUnderMouse() async -> (NSImage, String)? {
        do {
            guard let display = try await getDisplayUnderMouse() else {
                print("No display under mouse")
                return nil
            }
            guard let screen = nsscreen(for: display) else { return nil }

            // Overlay can return a region selection or a simple click
            guard let outcome = await SelectionOverlay.presentAndSelect(on: screen) else {
                return nil
            }

            // Capture one frame from that display
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = display.width
            config.height = display.height
            config.showsCursor = false

            let output = FrameCaptureHandler()
            let stream = SCStream(filter: filter, configuration: config, delegate: nil)
            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .main)

            try await stream.startCapture()
            try await Task.sleep(nanoseconds: 300_000_000)
            try await stream.stopCapture()

            guard let fullImage = output.capturedImage else { return nil }

            switch outcome {
            case .region(let selectionLocal):
                guard selectionLocal.width >= 2, selectionLocal.height >= 2 else { return nil }
                guard
                    let cropped = crop(
                        image: fullImage,
                        selectionLocalPoints: selectionLocal,
                        on: screen,
                        capturedDisplayPixelSize: CGSize(
                            width: display.width,
                            height: display.height
                        )
                    )
                else { return nil }

                guard let data = cropped.jpegData() else { return nil }
                return (cropped, data.base64EncodedString())

            case .click(let clickLocal):
                // Try to find the topmost window under the click on this display
                if let win = try await topmostWindow(
                    at: clickLocal,
                    on: display,
                    screen: screen
                ), win.isOnScreen {
                    // Convert window frame (global pixels) → this screen's local *points* for cropping
                    let sx = CGFloat(display.width) / screen.frame.width
                    let sy = CGFloat(display.height) / screen.frame.height

                    // Display’s global pixel bounds (CoreGraphics)
                    let displayBoundsPx = CGDisplayBounds(display.displayID)

                    // Convert window frame (global pixels) -> display-local pixels
                    let winPxLocal = CGRect(
                        x: win.frame.minX - displayBoundsPx.origin.x,
                        y: win.frame.minY - displayBoundsPx.origin.y,
                        width: win.frame.width,
                        height: win.frame.height
                    )

                    // Flip Y back to bottom-left origin *within the display*, then to screen-local points
                    let winLocalPoints = CGRect(
                        x: winPxLocal.minX / sx,
                        y: (CGFloat(display.height) - winPxLocal.maxY) / sy,
                        width: winPxLocal.width / sx,
                        height: winPxLocal.height / sy
                    ).integral

                    let targetRect = winLocalPoints.intersection(
                        CGRect(origin: .zero, size: screen.frame.size)
                    )

                    if let cropped = crop(
                        image: fullImage,
                        selectionLocalPoints: targetRect,
                        on: screen,
                        capturedDisplayPixelSize: CGSize(
                            width: display.width,
                            height: display.height
                        )
                    ),
                        let data = cropped.jpegData()
                    {
                        return (cropped, data.base64EncodedString())
                    } else if let data = fullImage.jpegData() {
                        // Fallback: whole screen
                        return (fullImage, data.base64EncodedString())
                    }
                    return nil
                } else {
                    // No window under click → full screen
                    if let data = fullImage.jpegData() {
                        return (fullImage, data.base64EncodedString())
                    }
                    return nil
                }
            }
        } catch {
            return nil
        }
    }

    /// Finds the SCDisplay under the current mouse pointer.
    private func getDisplayUnderMouse() async throws -> SCDisplay? {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
        else {
            return nil
        }

        guard
            let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                as? CGDirectDisplayID
        else {
            return nil
        }

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        return content.displays.first(where: { $0.displayID == screenNumber })
    }

    /// Map SCDisplay → NSScreen
    private func nsscreen(for display: SCDisplay) -> NSScreen? {
        NSScreen.screens.first { screen in
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                as? CGDirectDisplayID) == display.displayID
        }
    }

    /// Find the topmost shareable window at a click on a specific display.
    /// - Parameters:
    ///   - clickLocalOnScreen: Click point in *that screen's local points* (SelectionOverlay coordinates)
    ///   - display: SCDisplay you are capturing from
    ///   - screen: NSScreen corresponding to `display`
    private func topmostWindow(
        at clickLocalOnScreen: CGPoint,
        on display: SCDisplay,
        screen: NSScreen
    ) async throws -> SCWindow? {

        // Per-display point→pixel scale
        let sx = CGFloat(display.width) / screen.frame.width
        let sy = CGFloat(display.height) / screen.frame.height

        // Display’s global pixel bounds (CoreGraphics global space, origin = top-left of main display)
        let displayBoundsPx = CGDisplayBounds(display.displayID)  // in pixels

        // Convert click: screen-local points -> display-local pixels (flip Y within the display)
        let clickPxLocal = CGPoint(
            x: clickLocalOnScreen.x * sx,
            y: (CGFloat(display.height) - (clickLocalOnScreen.y * sy))
        )

        // To global pixels (CoreGraphics space)
        let clickGlobalPx = CGPoint(
            x: displayBoundsPx.origin.x + clickPxLocal.x,
            y: displayBoundsPx.origin.y + clickPxLocal.y
        )

        // Fetch shareable windows (on-screen only)
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        // Filter windows that contain the click (all in global pixel space)
        let candidates = content.windows.filter { w in
            w.isOnScreen && w.frame.contains(clickGlobalPx)
        }

        // Topmost by layer; tie-breaker: larger area
        return candidates.sorted {
            if $0.windowLayer != $1.windowLayer { return $0.windowLayer > $1.windowLayer }
            let a0 = $0.frame.width * $0.frame.height
            let a1 = $1.frame.width * $1.frame.height
            return a0 > a1
        }.first
    }

    /// Crop an NSImage of a full display to a rect in that display’s *local points*.
    private func crop(
        image: NSImage,
        selectionLocalPoints rectPts: CGRect,
        on screen: NSScreen,
        capturedDisplayPixelSize: CGSize
    ) -> NSImage? {
        // Get a CGImage and use its dimensions to compute the true scale
        guard
            let tiff = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff),
            let cg = rep.cgImage
        else { return nil }

        let sx = CGFloat(cg.width) / screen.frame.width
        let sy = CGFloat(cg.height) / screen.frame.height

        var cropPx = CGRect(
            x: rectPts.minX * sx,
            y: rectPts.minY * sy,
            width: rectPts.width * sx,
            height: rectPts.height * sy
        )

        // Flip Y for image space (bitmap origin at top-left)
        let displayH = capturedDisplayPixelSize.height
        cropPx.origin.y = displayH - cropPx.maxY

        // Reconfirm bounds against the image's true pixel bounds
        let bounds = CGRect(x: 0, y: 0, width: cg.width, height: cg.height)
        cropPx = bounds.intersection(cropPx)
        guard cropPx.width >= 1, cropPx.height >= 1 else { return nil }

        guard let croppedCG = cg.cropping(to: cropPx) else { return nil }
        return NSImage(
            cgImage: croppedCG,
            size: NSSize(width: rectPts.width, height: rectPts.height)
        )
    }
}

// MARK: - FrameCaptureHandler

class FrameCaptureHandler: NSObject, SCStreamOutput {
    var capturedImage: NSImage?

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvImageBuffer: buffer)
        let rep = NSCIImageRep(ciImage: ciImage)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        capturedImage = image
    }
}

// MARK: - NSImage helper

extension NSImage {
    func jpegData(compression: CGFloat = 0.9) -> Data? {
        guard let tiffData = self.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let jpeg = bitmap.representation(
                using: .jpeg,
                properties: [.compressionFactor: compression]
            )
        else {
            return nil
        }
        return jpeg
    }
}

// MARK: - Selection Overlay (single-screen)

private enum SelectionOutcome {
    case region(CGRect)
    case click(CGPoint)
}

private final class SelectionOverlay: NSWindow {

    // NEW: Track the active overlay (so we can cancel from elsewhere)
    private static weak var current: SelectionOverlay?
    // NEW: Keep the continuation so we can resume it on cancel
    private var continuation: CheckedContinuation<SelectionOutcome?, Never>?
    private var hasCompleted = false

    private let selectionView = SelectionView()

    /// Present on a single screen; returns either a region (screen-local points) or a click point.
    static func presentAndSelect(on screen: NSScreen) async -> SelectionOutcome? {
        let win = SelectionOverlay(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        current = win

        win.level = .screenSaver
        win.isOpaque = false
        win.backgroundColor = .clear
        win.ignoresMouseEvents = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.hasShadow = false
        win.sharingType = getPreferencesShowInScreenshot() ? .readOnly : .none

        win.contentView = win.selectionView
        win.selectionView.configureForSingleScreen(screen: screen)
        win.makeKeyAndOrderFront(nil)
        NSCursor.crosshair.set()

        return await withCheckedContinuation {
            (cont: CheckedContinuation<SelectionOutcome?, Never>) in
            win.continuation = cont
            win.selectionView.onComplete = { outcome in
                win.finish(outcome)
            }
        }
    }

    static func cancelActive() {
        current?.cancel()
    }

    private func cancel() {
        finish(nil)
    }

    private func finish(_ outcome: SelectionOutcome?) {
        guard !hasCompleted else { return }
        hasCompleted = true
        orderOut(nil)
        SelectionOverlay.current = nil
        continuation?.resume(returning: outcome)
        continuation = nil
    }
}

private final class SelectionView: NSView {

    // Returns either a region (drag) or a click point (no drag)
    var onComplete: ((SelectionOutcome?) -> Void)?

    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var isDragging = false
    private weak var hostScreen: NSScreen?

    func configureForSingleScreen(screen: NSScreen) {
        self.hostScreen = screen
        // The window’s contentRect == screen.frame; inside the window, (0,0) maps to the screen’s minX/minY.
        self.frame = NSRect(origin: .zero, size: screen.frame.size)
        self.wantsLayer = true
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    // MARK: - Input handling

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {  // ESC
            onComplete?(nil)
        } else {
            super.keyDown(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let p = event.locationInWindow  // window-local == screen-local here
        startPoint = p
        currentPoint = p
        isDragging = true
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        currentPoint = event.locationInWindow
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let s = startPoint else {
            onComplete?(nil)
            return
        }
        let c = currentPoint ?? s
        isDragging = false
        let rect = rectFromPoints(s, c)

        // Threshold to detect "click" vs "drag"
        if rect.width < 2 && rect.height < 2 {
            // Click: return the click point (screen-local)
            onComplete?(.click(s))
        } else {
            // Region
            onComplete?(.region(rect))
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Dim whole screen (this window covers only one screen)
        NSColor.black.withAlphaComponent(0.45).setFill()
        dirtyRect.fill()

        if let s = startPoint, let c = currentPoint {
            let sel = rectFromPoints(s, c)

            // Clear the selected area
            NSGraphicsContext.current?.saveGraphicsState()
            NSColor.clear.setFill()
            sel.fill(using: .clear)
            NSGraphicsContext.current?.restoreGraphicsState()

            // Border
            let path = NSBezierPath(rect: sel)
            path.lineWidth = 2
            NSColor.white.setStroke()
            path.stroke()
        }
    }

    // MARK: - Helpers

    private func rectFromPoints(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(a.x - b.x),
            height: abs(a.y - b.y)
        )
    }
}
