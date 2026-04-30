import SwiftUI

struct OnboardingView: View {
    @Binding var hasAPIKey: Bool
    @State private var apiKey = ""
    @State private var isValidating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var animateGradient = false
    @State private var currentStep = 0  // 0 = API Key, 1 = Logineo (optional)
    
    // Logineo optional setup
    @State private var logineoURL = "169080.logineonrw-lms.de"
    @State private var logineoUsername = ""
    @State private var logineoPassword = ""
    
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
                    FeaturePill(icon: "calendar", text: "Timetable", color: .elianBlue)
                    FeaturePill(icon: "checklist", text: "Homework", color: .elianGreen)
                    FeaturePill(icon: "brain.head.profile.fill", text: "AI Study", color: .elianPurple)
                    FeaturePill(icon: "envelope.fill", text: "Messages", color: .elianOrange)
                }
                
                // Step Content
                if currentStep == 0 {
                    apiKeyStep
                } else {
                    logineoStep
                }
                
                Spacer()
            }
            .padding(40)
        }
    }
    
    // MARK: - Step 1: API Key
    
    private var apiKeyStep: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("1")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.elianBlue)
                        .clipShape(Circle())
                    Text("Enter your Gemini API Key")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.elianTextPrimary)
                }
                
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
            
            Button(action: validateAndContinue) {
                HStack(spacing: 8) {
                    if isValidating {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    }
                    Text(isValidating ? "Validating..." : "Continue")
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
    }
    
    // MARK: - Step 2: Logineo (Optional)
    
    private var logineoStep: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("2")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.elianPurple)
                        .clipShape(Circle())
                    Text("Connect Logineo (Optional)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.elianTextPrimary)
                }
                
                Text("Connect your school's Logineo LMS to sync homework and messages automatically.")
                    .font(.system(size: 13))
                    .foregroundStyle(.elianTextTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            TextField("School URL (e.g. 169080.logineonrw-lms.de)", text: $logineoURL)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(14)
                .background(Color.elianSurfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            
            TextField("Username", text: $logineoUsername)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(14)
                .background(Color.elianSurfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            
            SecureField("Password", text: $logineoPassword)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(14)
                .background(Color.elianSurfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            HStack(spacing: 12) {
                Button {
                    // Skip Logineo setup
                    completeOnboarding()
                } label: {
                    Text("Skip for Now")
                        .elianOutlineButton(color: .elianTextSecondary)
                }
                
                Button {
                    saveLogineoAndComplete()
                } label: {
                    Text("Connect & Start")
                        .elianButton(color: .elianPurple, fullWidth: false)
                }
            }
        }
        .padding(28)
        .background(Color.elianSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.elianBorder, lineWidth: 0.5)
        )
        .frame(maxWidth: 480)
    }
    
    // MARK: - Actions
    
    private func validateAndContinue() {
        isValidating = true
        showError = false
        
        Task {
            let isValid = await GeminiService.shared.validateAPIKey(apiKey.trimmingCharacters(in: .whitespaces))
            
            await MainActor.run {
                isValidating = false
                if isValid {
                    KeychainService.shared.apiKey = apiKey.trimmingCharacters(in: .whitespaces)
                    withAnimation(.spring(duration: 0.5)) {
                        currentStep = 1
                    }
                } else {
                    showError = true
                    errorMessage = "Invalid API key. Please check and try again."
                }
            }
        }
    }
    
    private func saveLogineoAndComplete() {
        let url = logineoURL.trimmingCharacters(in: .whitespaces)
        let user = logineoUsername.trimmingCharacters(in: .whitespaces)
        let pass = logineoPassword
        
        if !url.isEmpty { KeychainService.shared.logineoURL = url }
        if !user.isEmpty { KeychainService.shared.logineoUsername = user }
        if !pass.isEmpty { KeychainService.shared.logineoPassword = pass }
        
        completeOnboarding()
    }
    
    private func completeOnboarding() {
        // Schedule initial background sync
        BackgroundSyncService.shared.scheduleSync()
        
        withAnimation(.spring(duration: 0.5)) {
            hasAPIKey = true
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
