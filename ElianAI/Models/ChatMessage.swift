import Foundation
import SwiftData

enum MessageRole: String, Codable {
    case user
    case assistant
}

@Model
final class ChatMessage {
    var id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date
    
    var note: NoteModel?
    
    init(
        role: MessageRole,
        content: String,
        note: NoteModel? = nil
    ) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = .now
        self.note = note
    }
}
