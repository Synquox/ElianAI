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
    
    /// Calculates next review date based on a 3-tier grade (0=Didn't Know, 1=Partially, 2=Knew It)
    func applySM2(grade: Int) {
        // Map 0-2 to standard SM-2 0-5 range
        let sm2Grade: Int
        switch grade {
        case 0: sm2Grade = 0 // Blackout
        case 1: sm2Grade = 3 // Difficult
        case 2: sm2Grade = 5 // Perfect
        default: sm2Grade = 3
        }
        
        if sm2Grade >= 3 {
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
        
        easeFactor = max(1.3, easeFactor + (0.1 - (5.0 - Double(sm2Grade)) * (0.08 + (5.0 - Double(sm2Grade)) * 0.02)))
        
        if let newDate = Calendar.current.date(byAdding: .day, value: interval, to: Date()) {
            nextReviewDate = newDate
        }
        
        // Mark as known after 3+ successful repetitions
        isKnown = repetitions >= 3
    }
}
