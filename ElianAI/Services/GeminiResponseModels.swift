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

// MARK: - Gemini Model Selection

enum GeminiModelOption: String, CaseIterable, Identifiable {
    case flash = "gemini-2.5-flash"
    case pro = "gemini-2.5-pro"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .flash: return "Gemini 2.5 Flash"
        case .pro: return "Gemini 2.5 Pro (Deep Reasoning)"
        }
    }
    
    var description: String {
        switch self {
        case .flash: return "Fast & efficient — great for daily study"
        case .pro: return "Deeper analysis — best for complex topics"
        }
    }
}
