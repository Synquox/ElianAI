import Foundation
import SwiftData

@Model
final class HomeworkEntry {
    var id: UUID
    var title: String
    var descriptionText: String
    var isCheckedOff: Bool
    var source: HomeworkSource
    var dueDate: Date?
    var pageReferences: [Int]
    var attachmentURLs: [String]
    var createdAt: Date
    
    var subject: Subject?
    
    @Relationship(deleteRule: .cascade, inverse: \HomeworkAttachment.homework)
    var attachments: [HomeworkAttachment] = []
    
    init(
        title: String,
        descriptionText: String = "",
        source: HomeworkSource = .manual,
        dueDate: Date? = nil,
        pageReferences: [Int] = [],
        attachmentURLs: [String] = [],
        subject: Subject? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.descriptionText = descriptionText
        self.isCheckedOff = false
        self.source = source
        self.dueDate = dueDate
        self.pageReferences = pageReferences
        self.attachmentURLs = attachmentURLs
        self.createdAt = .now
        self.subject = subject
    }
}

enum HomeworkSource: String, Codable {
    case auto      // Scraped from Logineo
    case manual    // Added manually by user
    case message   // Extracted from Logineo message
}

// MARK: - Homework Attachment (downloaded worksheet/file)

@Model
final class HomeworkAttachment {
    var id: UUID
    var fileName: String
    var fileType: String       // pdf, docx, ppt, image, unknown
    var fileData: Data?        // Cached binary data
    var sourceURL: String      // Original Logineo URL
    var downloadedAt: Date
    
    var homework: HomeworkEntry?
    
    init(
        fileName: String,
        fileType: String,
        fileData: Data? = nil,
        sourceURL: String
    ) {
        self.id = UUID()
        self.fileName = fileName
        self.fileType = fileType
        self.fileData = fileData
        self.sourceURL = sourceURL
        self.downloadedAt = .now
    }
    
    var iconName: String {
        switch fileType {
        case "pdf": return "doc.fill"
        case "docx", "doc": return "doc.richtext.fill"
        case "ppt", "pptx": return "rectangle.stack.fill"
        case "image", "png", "jpg", "jpeg": return "photo.fill"
        case "assignment": return "pencil.and.list.clipboard"
        default: return "paperclip"
        }
    }
    
    var iconColor: String {
        switch fileType {
        case "pdf": return "#EF4444"
        case "docx", "doc": return "#4A9EFF"
        case "ppt", "pptx": return "#FB923C"
        case "image", "png", "jpg", "jpeg": return "#34D399"
        default: return "#9090A8"
        }
    }
}
