//
//  DragFileManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/23/25.
//

import AppKit
import Foundation
import PDFKit
import UniformTypeIdentifiers

enum DroppedContent: Hashable {
    // name, doc, image, base64
    case image(String, NSImage, String)
    // name, doc, image[], base64[]
    case pdf(String, PDFDocument, [NSImage], [String])
    // name, text
    case text(String, String)
}

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

class DragFileManager {

    // Entry point if you receive Strings from dropDestination
    static func processPaths(_ items: [String]) -> [DroppedContent] {
        items.compactMap { str in
            if let url = urlFromDroppedString(str) {
                return processFileURL(url)
            }
            return nil
        }
    }

    // MARK: - Core logic

    static func processFileURL(_ url: URL) -> DroppedContent? {
        let fileURL = url.isFileURL ? url.standardizedFileURL : url
        guard fileURL.isFileURL else { return nil }

        let ext = fileURL.pathExtension.lowercased()
        let type = UTType(filenameExtension: ext)

        // 1) IMAGES
        if type?.conforms(to: .image) == true {
            guard let nsimg = NSImage(contentsOf: fileURL) else { return nil }
            guard let data = nsimg.jpegData() else { return nil }
            return .image(fileURL.pathComponents.last ?? "", nsimg, data.base64EncodedString())
        }

        // 2) PDF
        if type?.conforms(to: .pdf) == true || ext == "pdf" {
            guard let doc = PDFDocument(url: fileURL) else { return nil }

            var thumbnails: [NSImage] = []
            var thumbnailsBase64: [String] = []
            for i in 0..<doc.pageCount {
                guard let image = doc.thumbnail(at: i) else { continue }
                guard let data = image.jpegData() else { continue }

                thumbnails.append(image)
                thumbnailsBase64.append(data.base64EncodedString())
            }

            if thumbnails.isEmpty {
                return nil
            }

            return .pdf(fileURL.pathComponents.last ?? "", doc, thumbnails, thumbnailsBase64)
        }

        // 3) EVERYTHING ELSE → text
        if let txt = readPlainText(fileURL) {
            return .text(fileURL.pathComponents.last ?? "", txt)
        }
        return nil
    }

    // MARK: - Helpers

    private static func urlFromDroppedString(_ s: String) -> URL? {
        if s.hasPrefix("file://") {
            return URL(string: s)?.standardizedFileURL
        }
        return URL(fileURLWithPath: s).standardizedFileURL
    }

    private static func renderFirstPage(of pdf: PDFDocument, maxDimension: CGFloat) -> NSImage? {
        guard let page = pdf.page(at: 0) else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        let scale = maxDimension / max(bounds.width, bounds.height)
        let size = NSSize(width: bounds.width * scale, height: bounds.height * scale)

        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.clear.set()
        NSRect(origin: .zero, size: size).fill()

        let ctx = NSGraphicsContext.current!.cgContext
        ctx.saveGState()
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1, y: -1)
        page.draw(with: .mediaBox, to: ctx)
        ctx.restoreGState()

        img.unlockFocus()
        return img
    }

    private static func readPlainText(_ url: URL) -> String? {
        if let data = try? Data(contentsOf: url), !data.isEmpty {
            if let s = String(data: data, encoding: .utf8) { return s }
            if let s = String(data: data, encoding: .utf16LittleEndian) { return s }
            if let s = String(data: data, encoding: .utf16BigEndian) { return s }
            if let s = String(data: data, encoding: .isoLatin1) { return s }
        }
        return nil
    }

}
