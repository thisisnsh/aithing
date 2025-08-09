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
            config.showsCursor = true

            let output = FrameCaptureHandler()
            let stream = SCStream(filter: filter, configuration: config, delegate: nil)
            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .main)

            try await stream.startCapture()

            // Wait for a frame to arrive (you could add a better signaling mechanism)
            try await Task.sleep(nanoseconds: 300_000_000)

            try await stream.stopCapture()

            guard let image = output.capturedImage else {
                return nil
            }

            if let jpegData = image.jpegData(),
                let base64 = jpegData.base64EncodedString() as String?
            {
                return (image, base64)
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }

    /// Darkens the entire desktop and lets the user drag a rectangle to capture.
    /// Returns (NSImage, base64) of the selected region, or nil if cancelled.
    @MainActor
    func captureSelectedScreenUnderMouse() async -> (NSImage, String)? {
        // 1) Ask user to drag a selection (overlay spans all screens; ESC cancels)
        guard let selectionGlobal = await SelectionOverlay.presentAndSelect() else {
            return nil
        }

        // 2) Find the NSScreen that contains the selection center; clamp the rect to that screen
        guard let targetScreen = screenContainingCenter(of: selectionGlobal) else {
            return nil
        }
        let clamped = selectionGlobal.intersection(targetScreen.frame)
        guard clamped.width >= 2, clamped.height >= 2 else { return nil }

        // 3) Find the SCDisplay matching that NSScreen
        guard
            let screenNumber = targetScreen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? CGDirectDisplayID
        else { return nil }
        let content = try? await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        guard let scDisplay = content?.displays.first(where: { $0.displayID == screenNumber })
        else {
            return nil
        }

        // 4) Create a display stream (full display) and capture a single frame
        let filter = SCContentFilter(display: scDisplay, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = scDisplay.width
        config.height = scDisplay.height
        config.showsCursor = true
        // NOTE: We could also try config.sourceRect, but cropping after capture is simplest/robust across scale/coords.

        let output = FrameCaptureHandler()
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try? stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .main)

        do {
            try await stream.startCapture()
            // Wait briefly for the first frame. You can replace this with a semaphore in FrameCaptureHandler if you prefer.
            try await Task.sleep(nanoseconds: 250_000_000)
            try await stream.stopCapture()
        } catch {
            try? await stream.stopCapture()
            return nil
        }

        guard let fullImage = output.capturedImage else { return nil }

        // 5) Crop to the clamped selection rect (convert points→pixels, flip Y for image space)
        guard
            let cropped = crop(
                image: fullImage,
                toGlobalRectInPoints: clamped,
                on: targetScreen,
                capturedDisplayPixelSize: CGSize(width: scDisplay.width, height: scDisplay.height)
            )
        else {
            return nil
        }

        // 6) Encode
        guard let data = cropped.jpegData(),
            let b64 = Optional(data.base64EncodedString())
        else { return nil }

        return (cropped, b64)
    }

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

    /// Returns the screen whose frame contains the center of the rect.
    private func screenContainingCenter(of rect: CGRect) -> NSScreen? {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return NSScreen.screens.first(where: { $0.frame.contains(center) })
    }

    /// Crop an NSImage of a *full display* to a global Cocoa rect (points) on a given screen.
    /// - Parameters:
    ///   - image: NSImage whose pixel size equals the display’s pixel size.
    ///   - toGlobalRectInPoints: Selection in global *Cocoa* coords (origin bottom-left).
    ///   - on: The NSScreen that was captured.
    ///   - capturedDisplayPixelSize: (width, height) in pixels for the captured display (from SCDisplay).
    @MainActor
    private func crop(
        image: NSImage,
        toGlobalRectInPoints rectPts: CGRect,
        on screen: NSScreen,
        capturedDisplayPixelSize: CGSize
    ) -> NSImage? {

        // Convert the selection rect from *global points* → *display-local points*
        let localPts = CGRect(
            x: rectPts.minX - screen.frame.minX,
            y: rectPts.minY - screen.frame.minY,
            width: rectPts.width,
            height: rectPts.height
        )

        // Convert points → pixels using the screen’s backing scale
        let scale = screen.backingScaleFactor
        var cropPx = CGRect(
            x: localPts.minX * scale,
            y: localPts.minY * scale,
            width: localPts.width * scale,
            height: localPts.height * scale
        )

        // Flip Y to image space (CGImage origin is top-left for bitmap data)
        let displayH = capturedDisplayPixelSize.height
        cropPx.origin.y = displayH - cropPx.maxY

        // Obtain a CGImage from the NSImage
        guard
            let tiff = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff),
            let cg = rep.cgImage
        else { return nil }

        // Clamp to image bounds just in case
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

// MARK: - Selection Overlay (overlay window + view)

private final class SelectionOverlay: NSWindow, NSWindowDelegate {

    private let selectionView = SelectionView()

    /// Presents a single giant borderless window covering the union of all screens.
    /// Waits async until the user drags a selection or cancels with ESC. Returns the selected rect in *global Cocoa* coords.
    @MainActor
    static func presentAndSelect() async -> CGRect? {
        let union = unionOfAllScreens()
        let overlay = SelectionOverlay(
            contentRect: union,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        overlay.level = .screenSaver
        overlay.isOpaque = false
        overlay.backgroundColor = .clear
        overlay.ignoresMouseEvents = false
        overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        overlay.setFrame(union, display: true)

        overlay.contentView = overlay.selectionView
        overlay.makeKeyAndOrderFront(nil)

        // Ensure we capture ESC to cancel
        overlay.selectionView.windowRef = overlay

        return await withCheckedContinuation { cont in
            overlay.selectionView.onComplete = { rect in
                overlay.orderOut(nil)
                cont.resume(returning: rect)
            }
        }
    }

    // Helpers

    /// Union of all screens in *Cocoa global* coords (origin bottom-left).
    @MainActor
    private static func unionOfAllScreens() -> CGRect {
        NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
    }

    /// Convert a Cocoa-global rect (origin bottom-left, possibly spanning multi-display)
    /// to the CGWindowListCreateImage expected global space (origin top-left of primary-space union).
    @MainActor
    static func cocoaToGlobalCG(_ cocoaRect: CGRect) -> CGRect {
        // Compute the global union height to flip Y
        let union = unionOfAllScreens()
        // CG global origin is top-left of the union; flip Y
        let flippedY = union.maxY - cocoaRect.maxY
        return CGRect(
            x: cocoaRect.minX,
            y: flippedY,
            width: cocoaRect.width,
            height: cocoaRect.height
        )
    }
}

private final class SelectionView: NSView {

    // Callback with the selected rect in *Cocoa global* coordinates (same space as NSScreen frames)
    var onComplete: ((CGRect?) -> Void)?
    weak var windowRef: NSWindow?

    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var isDragging = false

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    // MARK: - Input handling

    override func keyDown(with event: NSEvent) {
        // ESC cancels
        if event.keyCode == 53 {  // kVK_Escape
            onComplete?(nil)
        } else {
            super.keyDown(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, to: nil)
        startPoint = windowToGlobalCocoa(p)
        currentPoint = startPoint
        isDragging = true
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let p = convert(event.locationInWindow, to: nil)
        currentPoint = windowToGlobalCocoa(p)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging, let s = startPoint, let c = currentPoint else {
            onComplete?(nil)
            return
        }
        isDragging = false
        let rect = rectFromPoints(s, c)
        // If very small, treat as cancel
        if rect.width < 2 || rect.height < 2 {
            onComplete?(nil)
        } else {
            onComplete?(rect)
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Fill whole union with semi-transparent black
        NSColor.black.withAlphaComponent(0.45).setFill()
        dirtyRect.fill()

        // If dragging, cut out the selection area and draw a border + size HUD
        if let s = startPoint, let c = currentPoint {
            let sel = rectFromPoints(s, c)

            // Convert global Cocoa rect into this view's local coordinates for drawing
            let localMin = globalCocoaToLocal(sel.origin)
            let localRect = CGRect(origin: localMin, size: sel.size)

            // Punch a clear hole for the selection
            NSGraphicsContext.current?.saveGraphicsState()
            NSColor.clear.setFill()
            localRect.fill(using: .clear)
            NSGraphicsContext.current?.restoreGraphicsState()

            // Stroke border
            let path = NSBezierPath(rect: localRect)
            path.lineWidth = 2
            NSColor.white.setStroke()
            path.stroke()

            // Size label (px)
            let text = "\(Int(sel.width)) × \(Int(sel.height))"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.white,
            ]
            let size = (text as NSString).size(withAttributes: attrs)
            let labelRect = NSRect(
                x: localRect.minX + 6,
                y: localRect.minY + 6,
                width: size.width + 8,
                height: size.height + 4
            )

            NSColor.black.withAlphaComponent(0.6).setFill()
            NSBezierPath(roundedRect: labelRect, xRadius: 6, yRadius: 6).fill()

            (text as NSString).draw(
                in: labelRect.insetBy(dx: 4, dy: 2),
                withAttributes: attrs
            )
        }
    }

    // MARK: - Coordinate helpers

    /// Convert a point from window local coords to *global Cocoa* coords.
    private func windowToGlobalCocoa(_ p: CGPoint) -> CGPoint {
        guard let win = windowRef else { return p }
        // Convert to screen coords (origin bottom-left, same as NSScreen frames)
        var screenRect = win.convertToScreen(NSRect(origin: p, size: .zero))
        return screenRect.origin
    }

    /// Convert a *global Cocoa* point back into this view's local coords for drawing.
    private func globalCocoaToLocal(_ p: CGPoint) -> CGPoint {
        guard let win = windowRef else { return p }
        // Convert a zero-size rect whose origin is in global Cocoa space into window coords
        // by using the inverse of convertToScreen.
        // convertFromScreen uses window coords; then convert to view coords.
        let windowPt = win.convertFromScreen(NSRect(origin: p, size: .zero)).origin
        return convert(windowPt, from: nil)
    }

    private func rectFromPoints(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(a.x - b.x),
            height: abs(a.y - b.y)
        )
    }
}
