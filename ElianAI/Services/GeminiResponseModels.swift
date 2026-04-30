import Foundation

// MARK: - Gemini JSON Response Structures

/// Top-level response from Gemini containing all study content
struct StudyContentResponse: Codable {
    let noteTitle: String
    let noteMarkdown: String
    let quizQuestions: [QuizQuestionDTO]
    let flashcards: [FlashcardDTO]
}

struct QuizQuestionDTO: Codable {
    let question: String
    let options: [String]
    let correctAnswerIndex: Int
    let explanation: String
}

struct FlashcardDTO: Codable {
    let front: String
    let back: String
}

/// Parsed timetable entry from AI image recognition
struct TimetableParseEntry: Codable {
    let day: Int      // 1=Monday ... 5=Friday
    let period: Int   // 1-based period index
    let subject: String
}

// MARK: - Gemini Model Selection

enum GeminiModelOption: String, CaseIterable, Identifiable {
    case flash = "gemini-1.5-flash"
    case flashLite = "gemini-1.5-flash-lite"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .flash: return "Gemini 1.5 Flash"
        case .flashLite: return "Gemini 1.5 Flash-Lite"
        }
    }
    
    var description: String {
        switch self {
        case .flash: return "Smart & efficient — great for daily study"
        case .flashLite: return "Ultra-fast — best for quick tasks"
        }
    }
}
