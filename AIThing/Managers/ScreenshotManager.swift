//
//  ScreenshotManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 7/26/25.
//

import AppKit
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
