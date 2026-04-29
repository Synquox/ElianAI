import Foundation
import SwiftData

@Model
final class QuizAttempt {
    var id: UUID = UUID()
    var score: Int
    var totalQuestions: Int
    var timestamp: Date
    
    var note: NoteModel?
    
    init(score: Int, totalQuestions: Int) {
        self.score = score
        self.totalQuestions = totalQuestions
        self.timestamp = Date()
    }
}
