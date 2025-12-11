//
//  FileModels.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/23/25.
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

