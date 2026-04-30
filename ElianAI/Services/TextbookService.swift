import Foundation
import PDFKit
import UIKit
import ZIPFoundation

/// Service for textbook page extraction, deep-link parsing, and solver prompt generation
final class TextbookService {
    static let shared = TextbookService()
    
    private init() {}
    
    // MARK: - Page Extraction
    
    /// Extract a single page from a PDF as image data
    func extractPageAsImage(from pdfData: Data, pageNumber: Int, scale: CGFloat = 2.0) -> UIImage? {
        guard let document = PDFDocument(data: pdfData),
              pageNumber > 0,
              pageNumber <= document.pageCount,
              let page = document.page(at: pageNumber - 1) else {
            return nil
        }
        
        let bounds = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: bounds.width * scale, height: bounds.height * scale)
        )
        
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: renderer.format.bounds.size))
            
            context.cgContext.translateBy(x: 0, y: bounds.height * scale)
            context.cgContext.scaleBy(x: scale, y: -scale)
            
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        
        return image
    }
    
    /// Extract a single page from a PDF as a new PDF document
    func extractPageAsPDF(from pdfData: Data, pageNumber: Int) -> Data? {
        guard let document = PDFDocument(data: pdfData),
              pageNumber > 0,
              pageNumber <= document.pageCount,
              let page = document.page(at: pageNumber - 1) else {
            return nil
        }
        
        let newDoc = PDFDocument()
        newDoc.insert(page, at: 0)
        return newDoc.dataRepresentation()
    }
    
    /// Extract text from a specific page
    func extractPageText(from pdfData: Data, pageNumber: Int) -> String? {
        guard let document = PDFDocument(data: pdfData),
              pageNumber > 0,
              pageNumber <= document.pageCount,
              let page = document.page(at: pageNumber - 1) else {
            return nil
        }
        
        return page.string
    }
    
    // MARK: - Page Reference Parsing
    
    /// Parse page references from homework description text
    func parsePageReferences(from text: String) -> [Int] {
        LogineoService.shared.parsePageReferences(from: text)
    }
    
    // MARK: - Solver Prompt Generation
    
    /// Generate a pre-written prompt for solving a task from a textbook page
    func generateSolverPrompt(pageContent: String, taskDescription: String, subjectName: String) -> String {
        return """
        I need help solving a task from my \(subjectName) textbook.
        
        **Task Description:**
        \(taskDescription)
        
        **Textbook Page Content:**
        \(pageContent)
        
        Please:
        1. Identify the specific task/exercise on this page
        2. Explain the approach step by step
        3. Show the full solution with detailed explanations
        4. Highlight any important formulas or concepts used
        """
    }
    
    // MARK: - DOCX/PPT Text Extraction
    
    /// Extract text from a DOCX file (ZIP-based XML format)
    func extractTextFromDOCX(data: Data) -> String? {
        // DOCX is a ZIP containing word/document.xml
        guard let archive = try? extractZIPEntry(from: data, entryName: "word/document.xml") else {
            return nil
        }
        
        return stripXMLTags(from: archive)
    }
    
    /// Extract text from a PPTX file (ZIP-based XML format)  
    func extractTextFromPPTX(data: Data) -> String? {
        var allText = ""
        
        // PPTX contains ppt/slides/slide1.xml, slide2.xml, etc.
        for i in 1...100 {
            guard let slideData = try? extractZIPEntry(from: data, entryName: "ppt/slides/slide\(i).xml") else {
                break
            }
            let slideText = stripXMLTags(from: slideData)
            if !slideText.isEmpty {
                allText += "--- Slide \(i) ---\n\(slideText)\n\n"
            }
        }
        
        return allText.isEmpty ? nil : allText
    }
    
    // MARK: - Helpers
    
    private func extractZIPEntry(from zipData: Data, entryName: String) throws -> String {
        guard let tempDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "TextbookService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot access cache directory"])
        }
        
        let zipURL = tempDir.appendingPathComponent(UUID().uuidString + ".zip")
        let extractDir = tempDir.appendingPathComponent(UUID().uuidString)
        
        defer {
            try? FileManager.default.removeItem(at: zipURL)
            try? FileManager.default.removeItem(at: extractDir)
        }
        
        try zipData.write(to: zipURL)
        
        // Use ZIPFoundation for reliable extraction
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: zipURL, to: extractDir)
        
        let entryURL = extractDir.appendingPathComponent(entryName)
        return try String(contentsOf: entryURL, encoding: .utf8)
    }
    
    private func stripXMLTags(from xml: String) -> String {
        // Remove XML tags, keeping text content
        var result = xml
        
        // Replace common XML paragraph/line break elements with newlines
        result = result.replacingOccurrences(of: "</w:p>", with: "\n")
        result = result.replacingOccurrences(of: "</a:p>", with: "\n")
        result = result.replacingOccurrences(of: "<w:br/>", with: "\n")
        
        // Strip all remaining XML tags
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>") {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        
        // Clean up whitespace
        let lines = result.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        return lines.joined(separator: "\n")
    }
}

