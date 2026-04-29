import Foundation
import SwiftData

@Model
final class QuizQuestion {
    var id: UUID
    var questionText: String
    var options: [String]
    var correctAnswerIndex: Int
    var explanation: String
    var userAnswerIndex: Int?
    var createdAt: Date
    
    var note: NoteModel?
    
    var isCorrect: Bool? {
        guard let userAnswer = userAnswerIndex else { return nil }
        return userAnswer == correctAnswerIndex
    }
    
    init(
        questionText: String,
        options: [String],
        correctAnswerIndex: Int,
        explanation: String
    ) {
        self.id = UUID()
        self.questionText = questionText
        self.options = options
        self.correctAnswerIndex = correctAnswerIndex
        self.explanation = explanation
        self.createdAt = .now
    }
}
