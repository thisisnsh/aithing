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

class ScreenshotManager {

    /// Captures the screen under the mouse pointer and returns (NSImage, base64 string).
    @MainActor
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

    /// Darkens only the screen under the mouse, lets the user drag a rect, then captures that region using ScreenCaptureKit.
    /// Reuses `getDisplayUnderMouse()` to choose the display. Returns (NSImage, base64) or nil if cancelled.
    @MainActor
    func captureSelectedScreenUnderMouse() async -> (NSImage, String)? {
        do {
            guard let display = try await getDisplayUnderMouse() else {
                print("No display under mouse")
                return nil
            }
            guard let screen = nsscreen(for: display) else { return nil }

            guard let selectionLocal = await SelectionOverlay.presentAndSelect(on: screen),
                selectionLocal.width >= 2, selectionLocal.height >= 2
            else {
                // todo: capture the app on which the click was registered
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

            try await stream.startCapture()
            try await Task.sleep(nanoseconds: 300_000_000)
            try await stream.stopCapture()

            guard let fullImage = output.capturedImage else { return nil }

            guard
                let cropped = crop(
                    image: fullImage,
                    selectionLocalPoints: selectionLocal,
                    on: screen,
                    capturedDisplayPixelSize: CGSize(width: display.width, height: display.height)
                )
            else { return nil }

            guard let data = cropped.jpegData() else { return nil }
            return (cropped, data.base64EncodedString())
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

    /// Crop an NSImage of a full display to a rect in that display’s *local points*.
    @MainActor
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

        guard
            let tiff = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff),
            let cg = rep.cgImage
        else { return nil }

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

private final class SelectionOverlay: NSWindow {

    private let selectionView = SelectionView()

    /// Present on a single screen; returns rect in that screen’s local *points*.
    @MainActor
    static func presentAndSelect(on screen: NSScreen) async -> CGRect? {
        // Create a borderless window sized/positioned exactly over this screen
        let win = SelectionOverlay(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.level = .screenSaver
        win.isOpaque = false
        win.backgroundColor = .clear
        win.ignoresMouseEvents = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.hasShadow = false
        win.sharingType = getPreferencesShowInScreenshot() ? .readOnly : .none

        // Configure content view to be screen-local coordinates (origin at bottom-left)
        win.contentView = win.selectionView
        win.selectionView.configureForSingleScreen(screen: screen)
        win.makeKeyAndOrderFront(nil)

        // Crosshair cursor for the session
        NSCursor.crosshair.set()

        return await withCheckedContinuation { cont in
            win.selectionView.onComplete = { rect in
                win.orderOut(nil)
                cont.resume(returning: rect)
            }
        }
    }
}

private final class SelectionView: NSView {

    // Result in this screen’s local *points*
    var onComplete: ((CGRect?) -> Void)?

    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var isDragging = false

    // For cursor screen info (not strictly needed, but handy if you add HUDs)
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
        guard isDragging, let s = startPoint, let c = currentPoint else {
            onComplete?(nil)
            return
        }
        isDragging = false
        let rect = rectFromPoints(s, c)
        if rect.width < 2 || rect.height < 2 {
            onComplete?(nil)
        } else {
            onComplete?(rect)  // already in this screen’s local points
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
