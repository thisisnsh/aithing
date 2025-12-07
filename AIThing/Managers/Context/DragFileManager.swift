//
//  DragFileManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/23/25.
//

import AppKit
import CoreXLSX
import Foundation
import PDFKit
import QuickLookThumbnailing
import UniformTypeIdentifiers

// MARK: - Drag File Manager

/// Processes dropped files and converts them to content that can be sent to the AI model.
///
/// Supports:
/// - Images (JPEG, PNG, etc.)
/// - PDF documents
/// - Spreadsheets (XLSX, CSV, TSV)
/// - Plain text and code files
class DragFileManager {
    
    // MARK: - Public API
    
    /// Processes multiple file URLs concurrently.
    ///
    /// - Parameter urls: Array of file URLs to process
    /// - Returns: Array of successfully processed content
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
    
    /// Processes a single file URL and returns appropriate content.
    ///
    /// - Parameter url: The file URL to process
    /// - Returns: Processed content, or nil if the file cannot be processed
    static func processFileURL(_ url: URL) async -> DroppedContent? {
        let fileURL = url.isFileURL ? url.standardizedFileURL : url
        guard fileURL.isFileURL else { return nil }
        
        let ext = fileURL.pathExtension.lowercased()
        let type = UTType(filenameExtension: ext)
        
        // 1) IMAGES
        if type?.conforms(to: .image) == true {
            return await processImageFile(fileURL)
        }
        
        // 2) PDF
        if type?.conforms(to: .pdf) == true || ext == "pdf" {
            return processPDFFile(fileURL)
        }
        
        // 3) SPREADSHEETS
        if isSpreadsheet(type: type, extension: ext) {
            return await processSpreadsheetFile(fileURL, extension: ext)
        }
        
        // 4) EVERYTHING ELSE (plain text, code, markdown, json, etc.)
        return await processTextFile(fileURL)
    }
    
    // MARK: - File Type Processing
    
    /// Processes an image file.
    ///
    /// - Parameter url: The image file URL
    /// - Returns: Image content, or nil if processing fails
    private static func processImageFile(_ url: URL) async -> DroppedContent? {
        guard let nsimg = NSImage(contentsOf: url) else { return nil }
        let thumb = nsimg.resized(maxDimension: 1024)
        guard let data = thumb.jpegData() else { return nil }
        return .image(url.pathComponents.last ?? "", nsimg, data.base64EncodedString())
    }
    
    /// Processes a PDF file.
    ///
    /// - Parameter url: The PDF file URL
    /// - Returns: PDF content with thumbnails, or nil if processing fails
    private static func processPDFFile(_ url: URL) -> DroppedContent? {
        guard let doc = PDFDocument(url: url) else { return nil }
        
        var thumbnails: [NSImage] = []
        var thumbnailsBase64: [String] = []
        
        for i in 0..<doc.pageCount {
            guard let image = doc.thumbnail(at: i),
                  let data = image.jpegData() else { continue }
            
            thumbnails.append(image)
            thumbnailsBase64.append(data.base64EncodedString())
        }
        
        guard !thumbnails.isEmpty else { return nil }
        
        return .pdf(url.pathComponents.last ?? "", doc, thumbnails, thumbnailsBase64)
    }
    
    /// Checks if a file type is a spreadsheet.
    ///
    /// - Parameters:
    ///   - type: The UTType of the file
    ///   - extension: The file extension
    /// - Returns: `true` if the file is a spreadsheet
    private static func isSpreadsheet(type: UTType?, extension ext: String) -> Bool {
        type?.conforms(to: .spreadsheet) == true || ext == "xlsx" || ext == "xls"
    }
    
    /// Processes a spreadsheet file.
    ///
    /// - Parameters:
    ///   - url: The spreadsheet file URL
    ///   - ext: The file extension
    /// - Returns: Text content with spreadsheet data, or nil if processing fails
    private static func processSpreadsheetFile(_ url: URL, extension ext: String) async -> DroppedContent? {
        let thumbnail = await quickLookThumbnail(for: url, maxDimension: 1024)
        
        if ext == "xlsx", let tsv = try? extractTSV(from: url) {
            return .text(url.lastPathComponent, tsv, thumbnail)
        } else if ext == "csv" || ext == "tsv" {
            if let txt = readPlainText(url) {
                return .text(url.lastPathComponent, txt, thumbnail)
            }
        } else {
            // .xls or anything we don't natively parse
            let fallback = """
            Preview not available for \(ext.uppercased()) files.
            Open the file to view it, or save as .xlsx/.csv to enable previews.
            """
            return .text(url.lastPathComponent, fallback, thumbnail)
        }
        
        return nil
    }
    
    /// Processes a text-based file.
    ///
    /// - Parameter url: The text file URL
    /// - Returns: Text content, or nil if the file cannot be read
    private static func processTextFile(_ url: URL) async -> DroppedContent? {
        guard let txt = readPlainText(url) else { return nil }
        let thumbnail = await quickLookThumbnail(for: url, maxDimension: 1024)
        return .text(url.pathComponents.last ?? "", txt, thumbnail)
    }
    
    // MARK: - Text Reading
    
    /// Reads plain text from a file with multiple encoding fallbacks.
    ///
    /// Tries UTF-8 first, then UTF-16 variants, then ISO Latin 1.
    ///
    /// - Parameter url: The file URL to read
    /// - Returns: The text content, or nil if reading fails
    private static func readPlainText(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            return nil
        }
        
        let encodings: [String.Encoding] = [
            .utf8,
            .utf16LittleEndian,
            .utf16BigEndian,
            .isoLatin1
        ]
        
        for encoding in encodings {
            if let s = String(data: data, encoding: encoding) {
                return s
            }
        }
        
        return nil
    }
    
    // MARK: - Thumbnails
    
    /// Creates a thumbnail image for a file using Quick Look.
    ///
    /// Falls back to the system file icon if Quick Look cannot generate a thumbnail.
    ///
    /// - Parameters:
    ///   - url: The file URL
    ///   - maxDimension: Maximum width/height for the thumbnail
    /// - Returns: The thumbnail image, or nil if unavailable
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
                    continuation.resume(returning: fallbackIcon(for: url, maxDimension: maxDimension))
                }
            }
        }
    }
    
    /// Gets the system file icon as a fallback thumbnail.
    ///
    /// - Parameters:
    ///   - url: The file URL
    ///   - maxDimension: Maximum dimension for the icon
    /// - Returns: The resized file icon
    private static func fallbackIcon(for url: URL, maxDimension: CGFloat) -> NSImage? {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        return icon.resized(maxDimension: maxDimension)
    }
    
    // MARK: - Spreadsheet Parsing
    
    /// Extracts TSV (tab-separated values) data from an XLSX file.
    ///
    /// - Parameter url: The XLSX file URL
    /// - Returns: TSV string representation of the first sheet
    /// - Throws: Error if the file cannot be opened or parsed
    private static func extractTSV(from url: URL) throws -> String {
        guard let xlsx = XLSXFile(filepath: url.path) else {
            throw NSError(
                domain: "ProcessFile",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to open XLSX"]
            )
        }
        
        let sharedStrings = try xlsx.parseSharedStrings()
        let worksheetPaths = try xlsx.parseWorksheetPaths()
        
        guard let firstSheetPath = worksheetPaths.first else {
            return ""
        }
        
        let ws = try xlsx.parseWorksheet(at: firstSheetPath)
        
        var lines: [String] = []
        let rows = ws.data?.rows ?? []
        
        for row in rows {
            var cols: [String] = []
            for cell in row.cells {
                if let sharedStrings = sharedStrings {
                    let value = cell.stringValue(sharedStrings) ?? ""
                    cols.append(value)
                }
            }
            lines.append(cols.joined(separator: "\t"))
        }
        
        return lines.joined(separator: "\n")
    }
}
