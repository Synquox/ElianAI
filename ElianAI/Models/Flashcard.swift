import Foundation
import SwiftData

@Model
final class Flashcard {
    var id: UUID
    var front: String
    var back: String
    var isKnown: Bool
    var createdAt: Date
    
    // Spaced Repetition (SM-2 Algorithm)
    var repetitions: Int = 0
    var interval: Int = 0
    var easeFactor: Double = 2.5
    var nextReviewDate: Date = Date()
    
    var note: NoteModel?
    
    init(
        front: String,
        back: String,
        isKnown: Bool = false
    ) {
        self.id = UUID()
        self.front = front
        self.back = back
        self.isKnown = isKnown
        self.createdAt = .now
        self.nextReviewDate = .now
    }
    
    /// Calculates next review date based on a 0-3 grade
    /// Grade: 0 = Again, 1 = Hard, 2 = Good, 3 = Easy
    func applySM2(grade: Int) {
        if grade >= 2 {
            if repetitions == 0 {
                interval = 1
            } else if repetitions == 1 {
                interval = 6
            } else {
                interval = Int(Double(interval) * easeFactor)
            }
            repetitions += 1
        } else {
            repetitions = 0
            interval = 1
        }
        
        easeFactor = max(1.3, easeFactor + (0.1 - (3.0 - Double(grade)) * (0.08 + (3.0 - Double(grade)) * 0.02)))
        
        if let newDate = Calendar.current.date(byAdding: .day, value: interval, to: Date()) {
            nextReviewDate = newDate
        }
        
        // Mark as known after 3+ successful repetitions
        isKnown = repetitions >= 3
    }
}
