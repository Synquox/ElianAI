import SwiftUI

struct OnboardingView: View {
    @Binding var hasAPIKey: Bool
    @State private var apiKey = ""
    @State private var isValidating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var animateGradient = false
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [
                    Color.elianBackground,
                    Color.elianPurple.opacity(0.15),
                    Color.elianBlue.opacity(0.1),
                    Color.elianBackground
                ],
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                    animateGradient.toggle()
                }
            }
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo & Title
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.elianBlue, .elianPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .shadow(color: .elianBlue.opacity(0.4), radius: 20)
                        
                        Image(systemName: "brain.head.profile.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.white)
                    }
                    
                    Text("ElianAI")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.elianTextPrimary, .elianBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Your AI-Powered Study Companion")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.elianTextSecondary)
                }
                
                // Feature pills
                HStack(spacing: 12) {
                    FeaturePill(icon: "doc.text.fill", text: "Notes", color: .elianBlue)
                    FeaturePill(icon: "questionmark.circle.fill", text: "Quizzes", color: .elianPurple)
                    FeaturePill(icon: "rectangle.on.rectangle.fill", text: "Flashcards", color: .elianGreen)
                    FeaturePill(icon: "bubble.left.fill", text: "Chat", color: .elianOrange)
                }
                
                // API Key Input
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter your Gemini API Key")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.elianTextPrimary)
                        
                        Text("Get your free API key from Google AI Studio")
                            .font(.system(size: 13))
                            .foregroundStyle(.elianTextTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    SecureField("API Key", text: $apiKey)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, design: .monospaced))
                        .padding(16)
                        .background(Color.elianSurfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.elianBorder, lineWidth: 1)
                        )
                    
                    if showError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(errorMessage)
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.elianError)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    Button(action: validateAndSave) {
                        HStack(spacing: 8) {
                            if isValidating {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            }
                            Text(isValidating ? "Validating..." : "Get Started")
                        }
                        .elianButton(color: .elianBlue, fullWidth: true)
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty || isValidating)
                    .opacity(apiKey.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                }
                .padding(28)
                .background(Color.elianSurface)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.elianBorder, lineWidth: 0.5)
                )
                .frame(maxWidth: 480)
                
                Spacer()
            }
            .padding(40)
        }
    }
    
    private func validateAndSave() {
        isValidating = true
        showError = false
        
        Task {
            let isValid = await GeminiService.shared.validateAPIKey(apiKey.trimmingCharacters(in: .whitespaces))
            
            await MainActor.run {
                isValidating = false
                if isValid {
                    KeychainService.shared.apiKey = apiKey.trimmingCharacters(in: .whitespaces)
                    withAnimation(.spring(duration: 0.5)) {
                        hasAPIKey = true
                    }
                } else {
                    showError = true
                    errorMessage = "Invalid API key. Please check and try again."
                }
            }
        }
    }
}

struct FeaturePill: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}
