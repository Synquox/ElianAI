import Foundation
import GoogleGenerativeAI
import PDFKit
import UserNotifications

@MainActor @Observable
final class GeminiService {
    static let shared = GeminiService()
    
    private(set) var isLoading = false
    private(set) var currentModel: GeminiModelOption = .flashPreview
    
    /// Tracks current retry state for UI display
    private(set) var retryStatus: RetryStatus = .idle
    
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
    
    /// Generates notes, quizzes, and flashcards from multiple input parts (text, image, audio)
    func generateStudyContent(from parts: [ModelContent.Part]) async throws -> StudyContentResponse {
        guard let model = generativeModel else {
            throw GeminiError.noAPIKey
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let systemPrompt = """
        You are an expert study assistant. Analyze the provided materials (text, images, and/or audio) and generate comprehensive study materials.
        
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
        """
        
        var contentParts = parts
        contentParts.insert(.text(systemPrompt), at: 0)
        
        let response = try await withRetry(taskName: "Study Material Generation") {
            try await model.generateContent([ModelContent(role: "user", parts: contentParts)])
        }
        
        guard let responseText = response.text else {
            throw GeminiError.emptyResponse
        }
        
        // Clean the response — strip markdown code fences if present
        let cleaned = responseText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        guard let jsonData = cleaned.data(using: String.Encoding.utf8) else {
            throw GeminiError.invalidJSON
        }
        
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(StudyContentResponse.self, from: jsonData)
        } catch {
            throw GeminiError.decodingFailed(error.localizedDescription)
        }
    }
    
    /// Helper for simple text-only generation
    func generateStudyContent(from text: String) async throws -> StudyContentResponse {
        try await generateStudyContent(from: [.text(text)])
    }
    
    // MARK: - Generate Flashcards Only
    
    /// Generates flashcards with a specific count and optional instructions
    func generateFlashcards(from text: String, count: Int, instructions: String = "") async throws -> [FlashcardDTO] {
        guard let model = generativeModel else {
            throw GeminiError.noAPIKey
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let instructionPart = instructions.isEmpty ? "" : "\nSPECIAL INSTRUCTIONS: \(instructions)"
        
        let prompt = """
        You are an expert study assistant. Generate exactly \(count) flashcards from the following content.
        
        IMPORTANT: Respond ONLY with valid JSON matching the exact schema below. No markdown fences, no extra text.
        
        JSON Schema:
        {
            "flashcards": [
                {
                    "front": "Term or concept question",
                    "back": "Definition or detailed answer"
                }
            ]
        }
        
        Guidelines:
        - Generate EXACTLY \(count) flashcards
        - Cover the most important concepts, terms, and facts
        - Front should be a clear question or term
        - Back should be a concise but complete answer\(instructionPart)
        
        CONTENT TO ANALYZE:
        \(text)
        """
        
        let response = try await withRetry(taskName: "Flashcard Generation") {
            try await model.generateContent(prompt)
        }
        
        guard let responseText = response.text else {
            throw GeminiError.emptyResponse
        }
        
        let cleaned = responseText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleaned.data(using: .utf8) else {
            throw GeminiError.invalidJSON
        }
        
        struct FlashcardResponse: Codable {
            let flashcards: [FlashcardDTO]
        }
        
        do {
            let decoded = try JSONDecoder().decode(FlashcardResponse.self, from: jsonData)
            return decoded.flashcards
        } catch {
            throw GeminiError.decodingFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Parse Timetable Image
    
    /// Parses a photo of a timetable and returns structured entries
    func parseTimetableImage(imageData: Data) async throws -> [TimetableParseEntry] {
        guard let model = generativeModel else {
            throw GeminiError.noAPIKey
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let prompt = """
        Analyze this image of a school timetable / schedule. Extract every subject entry.
        
        IMPORTANT: Respond ONLY with valid JSON matching the exact schema below. No markdown fences, no extra text.
        
        JSON Schema:
        {
            "entries": [
                {
                    "day": 1,
                    "period": 1,
                    "subject": "Mathematics"
                }
            ]
        }
        
        Rules:
        - "day" is 1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday
        - "period" is the row number starting from 1 (first lesson of the day)
        - "subject" is the subject name as written on the timetable (keep original language)
        - If a cell is empty or has a break, skip it
        - Extract ALL entries visible in the timetable
        """
        
        let response = try await withRetry(taskName: "Timetable Parsing") {
            try await model.generateContent(prompt, ModelContent.Part.data(mimetype: "image/jpeg", imageData))
        }
        
        guard let responseText = response.text else {
            throw GeminiError.emptyResponse
        }
        
        let cleaned = responseText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleaned.data(using: .utf8) else {
            throw GeminiError.invalidJSON
        }
        
        struct TimetableResponse: Codable {
            let entries: [TimetableParseEntry]
        }
        
        do {
            let decoded = try JSONDecoder().decode(TimetableResponse.self, from: jsonData)
            return decoded.entries
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
        
        let response = try await withRetry(taskName: "Chat") {
            try await model.generateContent(conversationParts)
        }
        
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
    
    // MARK: - Image OCR
    
    /// Extract text from an image using Gemini's multimodal capabilities
    func extractTextFromImage(imageData: Data) async throws -> String {
        guard let model = generativeModel else {
            throw GeminiError.noAPIKey
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let prompt = "Extract all text from this image. Return only the raw text content, preserving the original structure and formatting as much as possible. If there are mathematical formulas, write them in LaTeX notation."
        
        let response = try await withRetry(taskName: "Image OCR") {
            try await model.generateContent(prompt, ModelContent.Part.data(mimetype: "image/jpeg", imageData))
        }
        
        guard let text = response.text, !text.isEmpty else {
            throw GeminiError.emptyResponse
        }
        
        return text
    }
    
    // MARK: - Validate API Key
    
    func validateAPIKey(_ key: String) async -> Bool {
        let testModel = GenerativeModel(name: "gemini-3-flash-preview", apiKey: key)
        do {
            let _ = try await testModel.generateContent("Say 'ok'")
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Retry Logic

extension GeminiService {
    /// Maximum number of retries before giving up
    private static let maxRetries = 3
    /// Base delay in seconds (doubles each retry: 30s, 60s, 120s)
    private static let baseDelay: TimeInterval = 30
    
    /// Execute an API call with automatic retry on rate-limit/quota errors
    private func withRetry<T>(
        taskName: String,
        attempt: Int = 1,
        operation: () async throws -> T
    ) async throws -> T {
        do {
            let result = try await operation()
            // Success — clear retry status
            retryStatus = .idle
            return result
        } catch {
            // Extract the actual error description from Google's SDK
            let detailedMessage = Self.extractDetailedError(error)
            let isRetryable = Self.isRetryableError(error)
            
            if isRetryable && attempt <= Self.maxRetries {
                let delay = Self.baseDelay * pow(2.0, Double(attempt - 1)) // 30s, 60s, 120s
                let retryAt = Date().addingTimeInterval(delay)
                
                // Update UI status
                retryStatus = .waiting(
                    attempt: attempt,
                    maxAttempts: Self.maxRetries,
                    retryAt: retryAt,
                    taskName: taskName
                )
                
                // Send local notification
                sendRetryNotification(
                    taskName: taskName,
                    attempt: attempt,
                    delaySeconds: Int(delay),
                    errorDescription: detailedMessage
                )
                
                // Wait
                try await Task.sleep(for: .seconds(delay))
                
                // Retry
                return try await withRetry(
                    taskName: taskName,
                    attempt: attempt + 1,
                    operation: operation
                )
            } else {
                retryStatus = .failed(detailedMessage)
                
                if isRetryable {
                    // All retries exhausted
                    sendFailureNotification(taskName: taskName)
                    throw GeminiError.rateLimitExhausted
                }
                // Re-throw with better message
                throw GeminiError.apiError(detailedMessage)
            }
        }
    }
    
    /// Detect if an error is a rate-limit, quota, or temporary server issue worth retrying
    private static func isRetryableError(_ error: Error) -> Bool {
        let desc = error.localizedDescription.lowercased()
        let retryableKeywords = [
            "rate limit", "quota", "resource exhausted",
            "429", "503", "500", "too many requests",
            "temporarily unavailable", "overloaded",
            "resourceexhausted", "internal"
        ]
        return retryableKeywords.contains { desc.contains($0) }
    }
    
    /// Extract a human-readable error message from Google's GenerateContentError
    private static func extractDetailedError(_ error: Error) -> String {
        // The GoogleGenerativeAI SDK wraps errors; try to extract the real message
        let mirror = Mirror(reflecting: error)
        for child in mirror.children {
            if let desc = child.value as? String, !desc.isEmpty {
                return desc
            }
        }
        
        // Fallback: check the full debug description for useful info
        let debugDesc = String(describing: error)
        if debugDesc.contains("RESOURCE_EXHAUSTED") || debugDesc.contains("429") {
            return "API rate limit reached. The free tier has limited requests per minute. Please wait a moment and try again."
        }
        if debugDesc.contains("INVALID_ARGUMENT") {
            return "Invalid request. The content may be too long or contain unsupported data."
        }
        if debugDesc.contains("PERMISSION_DENIED") || debugDesc.contains("API_KEY_INVALID") {
            return "Invalid API key. Please check your Gemini API key in Settings."
        }
        if debugDesc.contains("NOT_FOUND") {
            return "Model not found. The selected model may not be available on your API plan."
        }
        if debugDesc.contains("SAFETY") {
            return "Content was blocked by safety filters. Try with different content."
        }
        
        // Last resort: use localizedDescription but append debug info
        let localized = error.localizedDescription
        if localized.contains("error 1") || localized.contains("GenerateContentError") {
            return "API call failed. This usually means rate limiting or an invalid API key. Debug: \(debugDesc.prefix(200))"
        }
        return localized
    }
    
    // MARK: - Notifications
    
    private func sendRetryNotification(taskName: String, attempt: Int, delaySeconds: Int, errorDescription: String) {
        let content = UNMutableNotificationContent()
        content.title = "ElianAI — Retrying \(taskName)"
        content.body = "API limit hit. Retrying in \(delaySeconds/60) min (attempt \(attempt)/\(Self.maxRetries)). You can keep the app open or come back later."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "gemini-retry-\(attempt)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    private func sendFailureNotification(taskName: String) {
        let content = UNMutableNotificationContent()
        content.title = "ElianAI — \(taskName) Failed"
        content.body = "Could not complete after \(Self.maxRetries) retries. The API may be temporarily unavailable. Please try again later."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "gemini-failure",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Retry Status

enum RetryStatus: Equatable {
    case idle
    case waiting(attempt: Int, maxAttempts: Int, retryAt: Date, taskName: String)
    case failed(String)
    
    var isRetrying: Bool {
        if case .waiting = self { return true }
        return false
    }
}

// MARK: - Errors

enum GeminiError: LocalizedError {
    case noAPIKey
    case emptyResponse
    case invalidJSON
    case decodingFailed(String)
    case rateLimitExhausted
    case apiError(String)
    
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
        case .rateLimitExhausted:
            return "API rate limit exceeded after multiple retries. Please wait a few minutes and try again."
        case .apiError(let detail):
            return "Gemini API error: \(detail)"
        }
    }
}
