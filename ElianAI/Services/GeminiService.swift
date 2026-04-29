import Foundation
import GoogleGenerativeAI
import PDFKit

@Observable
final class GeminiService {
    static let shared = GeminiService()
    
    private(set) var isLoading = false
    private(set) var currentModel: GeminiModelOption = .flash
    
    private var _cachedModel: GenerativeModel?
    private var _cachedModelKey: String?
    
    private var generativeModel: GenerativeModel? {
        guard let apiKey = KeychainService.shared.apiKey, !apiKey.isEmpty else {
            _cachedModel = nil
            _cachedModelKey = nil
            return nil
        }
        let cacheKey = "\(currentModel.rawValue):\(apiKey)"
        if _cachedModelKey == cacheKey, let model = _cachedModel {
            return model
        }
        let model = GenerativeModel(name: currentModel.rawValue, apiKey: apiKey)
        _cachedModel = model
        _cachedModelKey = cacheKey
        return model
    }
    
    private init() {
        // Load saved model preference
        if let saved = UserDefaults.standard.string(forKey: "selectedGeminiModel"),
           let model = GeminiModelOption(rawValue: saved) {
            currentModel = model
        }
    }
    
    // MARK: - Model Selection
    
    func setModel(_ model: GeminiModelOption) {
        currentModel = model
        _cachedModel = nil
        _cachedModelKey = nil
        UserDefaults.standard.set(model.rawValue, forKey: "selectedGeminiModel")
    }
    
    // MARK: - Study Content Generation
    
    /// Generates notes, quizzes, and flashcards from input text in a single API call
    func generateStudyContent(from text: String) async throws -> StudyContentResponse {
        guard let model = generativeModel else {
            throw GeminiError.noAPIKey
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let prompt = """
        You are an expert study assistant. Analyze the following content and generate comprehensive study materials.
        
        IMPORTANT: Respond ONLY with valid JSON matching the exact schema below. No markdown fences, no extra text.
        
        JSON Schema:
        {
            "noteTitle": "A concise, descriptive title for the notes",
            "noteMarkdown": "Rich study notes in Markdown format. Include: structured headings (##, ###), bullet points, **bold** key terms, relevant emojis (📌, 🔬, 📊, etc.), LaTeX equations wrapped in $...$ for inline and $$...$$ for block equations, and markdown tables where comparisons are useful.",
            "quizQuestions": [
                {
                    "question": "The question text",
                    "options": ["Option A", "Option B", "Option C", "Option D"],
                    "correctAnswerIndex": 0,
                    "explanation": "Why this answer is correct"
                }
            ],
            "flashcards": [
                {
                    "front": "Term or concept question",
                    "back": "Definition or detailed answer"
                }
            ]
        }
        
        Guidelines:
        - Generate 5-10 quiz questions with 4 options each
        - Generate 8-15 flashcards covering key concepts
        - Notes should be thorough, well-structured, and visually rich
        - Use emojis to make notes engaging (but not excessive)
        - Include LaTeX for any mathematical or scientific formulas
        - Use tables for comparing related concepts
        
        CONTENT TO ANALYZE:
        \(text)
        """
        
        let response = try await model.generateContent(prompt)
        
        guard let responseText = response.text else {
            throw GeminiError.emptyResponse
        }
        
        // Clean the response — strip markdown code fences if present
        let cleaned = responseText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleaned.data(using: .utf8) else {
            throw GeminiError.invalidJSON
        }
        
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(StudyContentResponse.self, from: jsonData)
        } catch {
            throw GeminiError.decodingFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Chat with Notes
    
    func chatWithNotes(
        noteContent: String,
        history: [(role: String, content: String)],
        userMessage: String
    ) async throws -> String {
        guard let model = generativeModel else {
            throw GeminiError.noAPIKey
        }
        
        isLoading = true
        defer { isLoading = false }
        
        var conversationParts = """
        You are a knowledgeable study assistant. The student has study notes and wants to ask questions about them.
        Be helpful, clear, and use examples where appropriate. Format your responses in Markdown.
        Use emojis sparingly to keep things engaging. If the question involves math or science, use LaTeX notation.
        
        STUDY NOTES CONTEXT:
        \(noteContent)
        
        CONVERSATION HISTORY:
        """
        
        for message in history {
            conversationParts += "\n\(message.role.uppercased()): \(message.content)"
        }
        
        conversationParts += "\nUSER: \(userMessage)\nASSISTANT:"
        
        let response = try await model.generateContent(conversationParts)
        
        guard let text = response.text else {
            throw GeminiError.emptyResponse
        }
        
        return text
    }
    
    // MARK: - PDF Text Extraction
    
    func extractTextFromPDF(data: Data) -> String? {
        guard let document = PDFDocument(data: data) else { return nil }
        
        var fullText = ""
        for i in 0..<document.pageCount {
            if let page = document.page(at: i),
               let pageText = page.string {
                fullText += pageText + "\n\n"
            }
        }
        
        return fullText.isEmpty ? nil : fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Validate API Key
    
    func validateAPIKey(_ key: String) async -> Bool {
        let testModel = GenerativeModel(name: "gemini-2.5-flash", apiKey: key)
        do {
            let _ = try await testModel.generateContent("Say 'ok'")
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Errors

enum GeminiError: LocalizedError {
    case noAPIKey
    case emptyResponse
    case invalidJSON
    case decodingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Please add your Gemini API key in Settings."
        case .emptyResponse:
            return "Gemini returned an empty response. Please try again."
        case .invalidJSON:
            return "Failed to parse the AI response. Please try again."
        case .decodingFailed(let detail):
            return "Response decoding failed: \(detail)"
        }
    }
}
