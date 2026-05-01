import Foundation

/// Manages app language with EN/DE support
@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()
    
    var currentLanguage: AppLanguage = .german
    
    private init() {}
    
    func localized(_ key: String) -> String {
        Strings.get(key, language: currentLanguage)
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case german = "de"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .german: return "Deutsch"
        }
    }
    
    var flag: String {
        switch self {
        case .german: return "🇩🇪"
        }
    }
    
    /// Language code for TTS
    var ttsCode: String {
        switch self {
        case .german: return "de-DE"
        }
    }
}
