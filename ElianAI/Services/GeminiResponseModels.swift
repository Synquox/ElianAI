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
    case flashPreview = "gemini-3-flash-preview"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .flashPreview: return "Gemini 3 Flash Preview"
        }
    }
    
    var description: String {
        switch self {
        case .flashPreview: return "Advanced logic and multimodal capabilities"
        }
    }
}
