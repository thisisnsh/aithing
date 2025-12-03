//
//  FileModels.swift
//  AIThing
//
//  Models for file handling.
//

import AppKit
import Foundation
import PDFKit

enum DroppedContent: Hashable {
    // name, image, base64
    case image(String, NSImage, String)
    // name, doc, image[], base64[]
    case pdf(String, PDFDocument, [NSImage], [String])
    // name, text, image
    case text(String, String, NSImage?)
}

