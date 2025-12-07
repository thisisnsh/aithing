//
//  PDFDocument+Extensions.swift
//  AIThing
//
//  Created by Nishant Singh Hada.
//

import Foundation
import PDFKit

extension PDFDocument {
    /// Fast thumbnail using PDFKit's built-in renderer.
    /// - Parameters:
    ///   - pageIndex: Zero-based page index.
    ///   - maxDimension: Max width/height (points). Aspect-ratio preserved.
    ///   - box: Which PDF box to use (.mediaBox by default).
    /// - Returns: NSImage or nil if index is out of range.
    func thumbnail(
        at pageIndex: Int,
        maxDimension: CGFloat = 1024,
        box: PDFDisplayBox = .mediaBox
    ) -> NSImage? {
        guard let page = page(at: pageIndex) else { return nil }
        let bounds = page.bounds(for: box)
        let scale = maxDimension / max(bounds.width, bounds.height)
        let size = NSSize(width: bounds.width * scale, height: bounds.height * scale)
        return page.thumbnail(of: size, for: box)
    }
}

