import Foundation

// MARK: - Logineo / Moodle Data Models

struct MoodleCourse: Identifiable, Codable, Hashable {
    let id: Int
    let fullName: String
    let shortName: String
    
    var displayName: String {
        shortName.isEmpty ? fullName : shortName
    }
}

struct MoodleFile: Identifiable, Codable {
    var id: String { url }
    let name: String
    let url: String
    let fileType: String
    let modifiedDate: Date?
    let courseId: Int
}

struct MoodleMessage: Identifiable, Codable {
    let id: UUID
    let sender: String
    let content: String
    let timestamp: Date
    let courseContext: String?
    var isRead: Bool
    
    init(
        sender: String,
        content: String,
        timestamp: Date = .now,
        courseContext: String? = nil,
        isRead: Bool = false
    ) {
        self.id = UUID()
        self.sender = sender
        self.content = content
        self.timestamp = timestamp
        self.courseContext = courseContext
        self.isRead = isRead
    }
}

struct HomeworkScrapeResult {
    let title: String
    let description: String
    let courseId: Int
    let courseName: String
    let dueDate: Date?
    let attachmentURLs: [String]
    let pageReferences: [Int] // Parsed page numbers like "S. 45"
}

enum LogineoError: LocalizedError {
    case invalidURL
    case loginFailed
    case sessionExpired
    case networkError(String)
    case parsingError(String)
    case noCredentials
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid school URL. Please check and try again."
        case .loginFailed:
            return "Login failed. Please check your username and password."
        case .sessionExpired:
            return "Your session has expired. Please log in again."
        case .networkError(let detail):
            return "Network error: \(detail)"
        case .parsingError(let detail):
            return "Could not parse response: \(detail)"
        case .noCredentials:
            return "No Logineo credentials stored. Configure them in Settings."
        }
    }
}
