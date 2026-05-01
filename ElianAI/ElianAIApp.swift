import SwiftUI
import SwiftData

@main
struct ElianAIApp: App {
    @State private var geminiService = GeminiService.shared
    @State private var supabaseService = SupabaseService.shared
    @State private var logineoService = LogineoService.shared
    
    init() {
        BackgroundSyncService.shared.registerBackgroundTasks()
        BackgroundSyncService.shared.requestNotificationPermission()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(geminiService)
                .environment(supabaseService)
                .environment(logineoService)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    // Handle Supabase OAuth callback
                    Task {
                        try? await supabaseService.handleAuthCallback(url: url)
                    }
                }
        }
        .modelContainer(for: [
            FolderModel.self,
            NoteModel.self,
            QuizQuestion.self,
            QuizAttempt.self,
            Flashcard.self,
            ChatMessage.self,
            Subject.self,
            TimetablePeriod.self,
            TimetableConfig.self,
            HomeworkEntry.self,
            HomeworkAttachment.self,
            SeenCourseFile.self,
            Textbook.self,
            MoodleMessageEntry.self
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

