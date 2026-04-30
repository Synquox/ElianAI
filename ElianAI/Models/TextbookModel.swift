import Foundation
import SwiftData

@Model
final class Textbook {
    var id: UUID
    var title: String
    var pdfData: Data?
    var pageCount: Int
    var createdAt: Date
    
    var subject: Subject?
    
    init(
        title: String,
        pdfData: Data? = nil,
        pageCount: Int = 0,
        subject: Subject? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.pdfData = pdfData
        self.pageCount = pageCount
        self.subject = subject
        self.createdAt = .now
    }
}
