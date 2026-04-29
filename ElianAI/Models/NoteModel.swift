import Foundation
import SwiftData

enum SourceType: String, Codable {
    case text
    case pdf
}

@Model
final class NoteModel {
    var id: UUID
    var title: String
    var rawContent: String
    var generatedMarkdown: String
    var sourceType: SourceType
    var createdAt: Date
    var updatedAt: Date
    
    var folder: FolderModel?
    
    @Relationship(deleteRule: .cascade, inverse: \QuizQuestion.note)
    var quizQuestions: [QuizQuestion] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Flashcard.note)
    var flashcards: [Flashcard] = []
    
    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.note)
    var chatMessages: [ChatMessage] = []
    
    @Relationship(deleteRule: .cascade, inverse: \QuizAttempt.note)
    var quizAttempts: [QuizAttempt] = []
    
    init(
        title: String,
        rawContent: String,
        generatedMarkdown: String = "",
        sourceType: SourceType = .text,
        folder: FolderModel? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.rawContent = rawContent
        self.generatedMarkdown = generatedMarkdown
        self.sourceType = sourceType
        self.folder = folder
        self.createdAt = .now
        self.updatedAt = .now
    }
}
