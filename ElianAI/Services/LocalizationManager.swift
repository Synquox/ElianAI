import Foundation

/// Manages app language with EN/DE support
@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()
    
    var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
        }
    }
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        currentLanguage = AppLanguage(rawValue: saved) ?? .english
    }
    
    func localized(_ key: String) -> String {
        Strings.get(key, language: currentLanguage)
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case german = "de"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .german: return "Deutsch"
        }
    }
    
    var flag: String {
        switch self {
        case .english: return "🇬🇧"
        case .german: return "🇩🇪"
        }
    }
    
    /// Language code for TTS
    var ttsCode: String {
        switch self {
        case .english: return "en-US"
        case .german: return "de-DE"
        }
    }
}
