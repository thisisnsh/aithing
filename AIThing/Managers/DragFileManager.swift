//
//  DragFileManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/23/25.
//

import AppKit
import Foundation
import PDFKit
import QuickLookThumbnailing
import UniformTypeIdentifiers

enum DroppedContent: Hashable {
    // name, image, base64
    case image(String, NSImage, String)
    // name, doc, image[], base64[]
    case pdf(String, PDFDocument, [NSImage], [String])
    // name, text, image
    case text(String, String, NSImage?)
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
        let target: NSSize
        if size.width >= size.height {
            let h = size.height * (maxDimension / size.width)
            target = .init(width: maxDimension, height: h)
        } else {
            let w = size.width * (maxDimension / size.height)
            target = .init(width: w, height: maxDimension)
        }

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

class DragFileManager {

    // MARK: - Core logic

    static func processPaths(_ urls: [URL]) async -> [DroppedContent] {
        await withTaskGroup(of: DroppedContent?.self) { group in
            for url in urls {
                group.addTask {
                    await processFileURL(url.standardizedFileURL)
                }
            }

            var results: [DroppedContent] = []
            for await result in group {
                if let value = result {
                    results.append(value)
                }
            }
            return results
        }
    }

    static func processFileURL(_ url: URL) async -> DroppedContent? {
        let fileURL = url.isFileURL ? url.standardizedFileURL : url
        guard fileURL.isFileURL else { return nil }

        let ext = fileURL.pathExtension.lowercased()
        let type = UTType(filenameExtension: ext)

        // 1) IMAGES
        if type?.conforms(to: .image) == true {
            guard let nsimg = NSImage(contentsOf: fileURL) else { return nil }
            let thumb = nsimg.resized(maxDimension: 1024)
            guard let data = thumb.jpegData() else { return nil }
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

        // 3) EVERYTHING ELSE
        if let txt = readPlainText(fileURL) {
            var thumbnail: NSImage?
            if let thumb = await quickLookThumbnail(for: fileURL, maxDimension: 1024) {
                thumbnail = thumb
            }

            return .text(fileURL.pathComponents.last ?? "", txt, thumbnail)
        }

        return nil
    }

    // MARK: - Helpers

    private static func readPlainText(_ url: URL) -> String? {
        if let data = try? Data(contentsOf: url), !data.isEmpty {
            if let s = String(data: data, encoding: .utf8) { return s }
            if let s = String(data: data, encoding: .utf16LittleEndian) { return s }
            if let s = String(data: data, encoding: .utf16BigEndian) { return s }
            if let s = String(data: data, encoding: .isoLatin1) { return s }
        }
        return nil
    }

    // MARK: - Generic thumbnails via Quick Look

    /// Creates a thumbnail image for an arbitrary document using Quick Look.
    /// Works well for Word/PowerPoint/Pages/Keynote and many other formats.
    /// - Parameters:
    /// - url: The file URL.
    /// - maxDimension: Max width/height for the returned image in points.
    /// - Returns: NSImage thumbnail if available.
    static func quickLookThumbnail(
        for url: URL,
        maxDimension: CGFloat = 512
    ) async -> NSImage? {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: maxDimension, height: maxDimension),
            scale: scale,
            representationTypes: .all
        )

        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { rep, _ in
                if let cg = rep?.cgImage {
                    let img = NSImage(cgImage: cg, size: .zero).resized(maxDimension: maxDimension)
                    continuation.resume(returning: img)
                } else {
                    continuation.resume(
                        returning: fallbackIcon(for: url, maxDimension: maxDimension)
                    )
                }
            }
        }
    }

    /// Fallback to the system file icon when Quick Look can’t provide a thumbnail.
    private static func fallbackIcon(for url: URL, maxDimension: CGFloat) -> NSImage? {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        return icon.resized(maxDimension: maxDimension)
    }
}
