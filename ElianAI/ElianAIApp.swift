import SwiftUI
import SwiftData

@main
struct ElianAIApp: App {
    @State private var geminiService = GeminiService.shared
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(geminiService)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [
            FolderModel.self,
            NoteModel.self,
            QuizQuestion.self,
            QuizAttempt.self,
            Flashcard.self,
            ChatMessage.self
        ])
    }
}

/// Root view that shows onboarding or main content
struct RootView: View {
    @State private var hasAPIKey = KeychainService.shared.hasAPIKey
    
    var body: some View {
        if hasAPIKey {
            ContentView()
        } else {
            OnboardingView(hasAPIKey: $hasAPIKey)
        }
    }
}
