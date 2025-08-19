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

final class ScreenshotManager: ObservableObject {

    /// Cancels any active selection overlay and removes the dim.
    func cancelScreenshot() {
        SelectionOverlay.cancelActive()
    }

    /// Captures a single frame from the display currently under the mouse and returns `(NSImage, base64)`.
    func captureScreenUnderMouse() async -> (NSImage, String)? {
        do {
            guard let display = try await getDisplayUnderMouse() else { return nil }
            guard let image = try await captureFrame(from: display, showsCursor: false) else {
                return nil
            }
            guard let data = image.jpegData() else { return nil }
            return (image, data.base64EncodedString())
        } catch {
            return nil
        }
    }

    /// Shows a dim overlay on the display under the mouse and lets the user drag-select a region or single-click.
    /// - Drag: crops to the selected region.
    /// - Click: captures the topmost app window at the click point; falls back to full screen if none.
    /// - Returns: `(NSImage, base64)` or `nil` if cancelled.
    func captureSelectedScreenUnderMouse() async -> (NSImage, String)? {
        do {
            guard let display = try await getDisplayUnderMouse() else { return nil }
            guard let screen = nsscreen(for: display) else { return nil }
            guard let outcome = await SelectionOverlay.presentAndSelect(on: screen) else {
                return nil
            }

            guard let fullImage = try await captureFrame(from: display, showsCursor: false) else {
                return nil
            }

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
                if let win = try await topmostWindow(at: clickLocal, on: display, screen: screen),
                    win.isOnScreen
                {
                    let sx = CGFloat(display.width) / screen.frame.width
                    let sy = CGFloat(display.height) / screen.frame.height
                    let displayBoundsPx = CGDisplayBounds(display.displayID)

                    let winPxLocal = CGRect(
                        x: win.frame.minX - displayBoundsPx.origin.x,
                        y: win.frame.minY - displayBoundsPx.origin.y,
                        width: win.frame.width,
                        height: win.frame.height
                    )

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
                        return (fullImage, data.base64EncodedString())
                    }
                    return nil
                } else {
                    guard let data = fullImage.jpegData() else { return nil }
                    return (fullImage, data.base64EncodedString())
                }
            }
        } catch {
            return nil
        }
    }

    /// Returns the `SCDisplay` currently under the mouse cursor.
    private func getDisplayUnderMouse() async throws -> SCDisplay? {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) else {
            return nil
        }
        guard
            let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                as? CGDirectDisplayID
        else { return nil }
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        return content.displays.first(where: { $0.displayID == id })
    }

    /// Maps an `SCDisplay` to its corresponding `NSScreen`.
    private func nsscreen(for display: SCDisplay) -> NSScreen? {
        NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID)
                == display.displayID
        }
    }

    /// Captures a single frame from a display via ScreenCaptureKit.
    private func captureFrame(from display: SCDisplay, showsCursor: Bool) async throws -> NSImage? {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = display.width
        config.height = display.height
        config.showsCursor = showsCursor

        let output = FrameCaptureHandler()
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .main)

        try await stream.startCapture()
        try await Task.sleep(nanoseconds: 300_000_000)
        try await stream.stopCapture()

        return output.capturedImage
    }

    /// Returns the topmost shareable window under a click on a specific display.
    /// - Parameters:
    ///   - clickLocalOnScreen: Click in the overlay's screen-local points.
    ///   - display: `SCDisplay` being captured.
    ///   - screen: `NSScreen` mapped to `display`.
    private func topmostWindow(
        at clickLocalOnScreen: CGPoint,
        on display: SCDisplay,
        screen: NSScreen
    ) async throws -> SCWindow? {
        let sx = CGFloat(display.width) / screen.frame.width
        let sy = CGFloat(display.height) / screen.frame.height

        let displayBoundsPx = CGDisplayBounds(display.displayID)
        let clickPxLocal = CGPoint(
            x: clickLocalOnScreen.x * sx,
            y: (CGFloat(display.height) - (clickLocalOnScreen.y * sy))
        )
        let clickGlobalPx = CGPoint(
            x: displayBoundsPx.origin.x + clickPxLocal.x,
            y: displayBoundsPx.origin.y + clickPxLocal.y
        )

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        let ownPID = NSRunningApplication.current.processIdentifier

        // Build front-to-back z-order map from CoreGraphics window list.
        // This list is already ordered: index 0 is the frontmost window.
        var zIndexByWindowID: [CGWindowID: Int] = [:]
        if let infoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] {
            for (idx, info) in infoList.enumerated() {
                if let num = info[kCGWindowNumber as String] as? NSNumber {
                    zIndexByWindowID[CGWindowID(num.uint32Value)] = idx
                }
            }
        }

        let candidates = content.windows.filter { w in
            guard w.isOnScreen else { return false }
            guard w.owningApplication?.processID != ownPID else { return false }

            // Ignore cursor/compositor surfaces (tiny size or suspicious titles)
            let minSize: CGFloat = 5
            if w.frame.width < minSize || w.frame.height < minSize { return false }
            if let title = w.title?.lowercased() {
                if title.contains("cursor") { return false }
                if title.contains("loom control menu") { return false }
                if title.contains("loom cropping") { return false }
                if title.contains("mouse highlight overlay") { return false }
                if title == "desktop" { return false }
                if title.isEmpty { return false }
                if title.hasPrefix("wallpaper-") { return false }
            }

            return w.frame.contains(clickGlobalPx)
        }

        // Prefer true z-order (front-most first). If two windows aren’t in the CG list,
        // break ties by layer, then (last resort) by area just to have a deterministic order.
        let sorted = candidates.sorted { a, b in
            let za = zIndexByWindowID[a.windowID]
            let zb = zIndexByWindowID[b.windowID]
            switch (za, zb) {
            case let (ia?, ib?):
                return ia < ib  // lower index == more frontmost
            case (nil, nil):
                if a.windowLayer != b.windowLayer {  // higher layer usually above
                    return a.windowLayer > b.windowLayer
                }
                let aa = a.frame.width * a.frame.height
                let ab = b.frame.width * b.frame.height
                return aa > ab
            case (_?, nil):
                return true  // a is known front-to-back; prefer it
            case (nil, _?):
                return false
            }
        }

        return sorted.first
    }

    /// Crops a full-display image to a rectangle expressed in the screen's local points.
    private func crop(
        image: NSImage,
        selectionLocalPoints rect: CGRect,
        on screen: NSScreen,
        capturedDisplayPixelSize: CGSize
    ) -> NSImage? {
        guard
            let tiff = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff),
            let cg = rep.cgImage
        else { return nil }

        let sx = CGFloat(cg.width) / screen.frame.width
        let sy = CGFloat(cg.height) / screen.frame.height

        var cropPx = CGRect(
            x: rect.minX * sx,
            y: rect.minY * sy,
            width: rect.width * sx,
            height: rect.height * sy
        )

        let displayH = capturedDisplayPixelSize.height
        cropPx.origin.y = displayH - cropPx.maxY

        let bounds = CGRect(x: 0, y: 0, width: cg.width, height: cg.height)
        cropPx = bounds.intersection(cropPx)
        guard cropPx.width >= 1, cropPx.height >= 1 else { return nil }

        guard let croppedCG = cg.cropping(to: cropPx) else { return nil }
        return NSImage(cgImage: croppedCG, size: NSSize(width: rect.width, height: rect.height))
    }
}

final class FrameCaptureHandler: NSObject, SCStreamOutput {
    var capturedImage: NSImage?

    /// Receives a sample frame from ScreenCaptureKit and stores it as an `NSImage`.
    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ci = CIImage(cvImageBuffer: buffer)
        let rep = NSCIImageRep(ciImage: ci)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        capturedImage = image
    }
}

extension NSImage {
    /// Encodes the image to JPEG with the given compression factor.
    func jpegData(compression: CGFloat = 0.9) -> Data? {
        guard
            let tiff = tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff),
            let jpg = rep.representation(
                using: .jpeg,
                properties: [.compressionFactor: compression]
            )
        else { return nil }
        return jpg
    }
}

private enum SelectionOutcome {
    case region(CGRect)
    case click(CGPoint)
}

private final class SelectionOverlay: NSWindow {

    // Active overlay tracking for global cancellation.
    private static weak var current: SelectionOverlay?
    private var continuation: CheckedContinuation<SelectionOutcome?, Never>?
    private var finished = false

    private let selectionView = SelectionView()

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Presents a borderless overlay on a single screen and returns either a region (drag) or a click point.
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

        // Ensure the app/window can receive key events
        NSApp.activate(ignoringOtherApps: true)
        win.initialFirstResponder = win.selectionView
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

    /// Cancels the active overlay, if any.
    static func cancelActive() {
        guard let current = current else { return }
        current.cancel()
    }

    private func cancel() {
        finish(nil)
    }

    private func finish(_ outcome: SelectionOutcome?) {
        guard !finished else { return }
        finished = true
        orderOut(nil)
        SelectionOverlay.current = nil
        continuation?.resume(returning: outcome)
        continuation = nil
    }
}

private final class SelectionView: NSView {

    /// Called with a region (drag) or click point when the interaction completes.
    var onComplete: ((SelectionOutcome?) -> Void)?

    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var isDragging = false
    private weak var hostScreen: NSScreen?

    /// Configures the view to use the provided screen's coordinate space (origin at bottom-left).
    func configureForSingleScreen(screen: NSScreen) {
        hostScreen = screen
        frame = NSRect(origin: .zero, size: screen.frame.size)
        wantsLayer = true
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    // ESC triggers cancelOperation on the first responder
    override func cancelOperation(_ sender: Any?) {
        onComplete?(nil)
    }

    /// Begins a drag or click.
    override func mouseDown(with event: NSEvent) {
        let p = event.locationInWindow
        startPoint = p
        currentPoint = p
        isDragging = true
        needsDisplay = true
    }

    /// Updates the selection rectangle during drag.
    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        currentPoint = event.locationInWindow
        needsDisplay = true
    }

    /// Completes the interaction and reports either a click or a region.
    override func mouseUp(with event: NSEvent) {
        guard let s = startPoint else {
            onComplete?(nil)
            return
        }
        let c = currentPoint ?? s
        isDragging = false
        let rect = CGRect(
            x: min(s.x, c.x),
            y: min(s.y, c.y),
            width: abs(s.x - c.x),
            height: abs(s.y - c.y)
        )
        if rect.width < 2 && rect.height < 2 {
            onComplete?(.click(s))
        } else {
            onComplete?(.region(rect))
        }
    }

    /// Draws the dimming overlay and the selection border.
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.black.withAlphaComponent(0.45).setFill()
        dirtyRect.fill()
        if let s = startPoint, let c = currentPoint {
            let sel = CGRect(
                x: min(s.x, c.x),
                y: min(s.y, c.y),
                width: abs(s.x - c.x),
                height: abs(s.y - c.y)
            )
            NSGraphicsContext.current?.saveGraphicsState()
            NSColor.clear.setFill()
            sel.fill(using: .clear)
            NSGraphicsContext.current?.restoreGraphicsState()
            let path = NSBezierPath(rect: sel)
            path.lineWidth = 2
            NSColor.white.setStroke()
            path.stroke()
        }
    }
}
