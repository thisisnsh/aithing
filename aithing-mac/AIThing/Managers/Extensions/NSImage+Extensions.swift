//
//  NSImage+Extensions.swift
//  AIThing
//
//  Created by Nishant Singh Hada.
//

import AppKit
import Foundation

extension NSImage {
    /// Returns JPEG-encoded data for this image.
    func jpegData(compression: CGFloat = 0.9) -> Data? {
        guard let tiff = tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff)
        else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: compression])
    }

    /// Resizes the image so the longest side equals `maxDimension` (keeping aspect ratio).
    func resized(maxDimension: CGFloat) -> NSImage {
        // Find the longest side of the image
        let longestSide = max(size.width, size.height)

        // If it's already within bounds, just return self (no upscaling)
        if longestSide <= maxDimension {
            return self
        }

        // Otherwise, scale down proportionally
        let scale = maxDimension / longestSide
        let target = NSSize(width: size.width * scale, height: size.height * scale)

        let img = NSImage(size: target)
        img.lockFocus()
        draw(
            in: NSRect(origin: .zero, size: target),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        img.unlockFocus()
        return img
    }
}

