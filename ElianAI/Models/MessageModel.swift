import Foundation
import SwiftData

@Model
final class MoodleMessageEntry {
    var id: UUID
    var sender: String
    var content: String
    var courseContext: String?
    var timestamp: Date
    var isRead: Bool
    var hasHomework: Bool
    var linkedHomeworkId: UUID?
    
    init(
        sender: String,
        content: String,
        courseContext: String? = nil,
        timestamp: Date = .now,
        isRead: Bool = false,
        hasHomework: Bool = false,
        linkedHomeworkId: UUID? = nil
    ) {
        self.id = UUID()
        self.sender = sender
        self.content = content
        self.courseContext = courseContext
        self.timestamp = timestamp
        self.isRead = isRead
        self.hasHomework = hasHomework
        self.linkedHomeworkId = linkedHomeworkId
    }
}
