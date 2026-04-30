import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(GeminiService.self) private var geminiService
    @Environment(SupabaseService.self) private var supabaseService
    
    @Query(sort: \Subject.name) private var subjects: [Subject]
    @Query(sort: \Textbook.title) private var textbooks: [Textbook]
    
    @State private var selectedModel: GeminiModelOption = GeminiService.shared.currentModel
    @State private var apiKey: String = ""
    @State private var showAPIKey = false
    @State private var isValidating = false
    @State private var showDeleteConfirm = false
    @State private var showSavedToast = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Logineo
    @State private var logineoURL: String = KeychainService.shared.logineoURL
    @State private var logineoUsername: String = KeychainService.shared.logineoUsername ?? ""
    @State private var logineoPassword: String = KeychainService.shared.logineoPassword ?? ""
    @State private var isTestingConnection = false
    @State private var connectionStatus: ConnectionTestResult?
    @State private var isSyncing = false
    
    // Textbooks
    @State private var showPDFPicker = false
    @State private var isAddingTextbook = false
    
    // Language
    @State private var selectedLanguage: AppLanguage = LocalizationManager.shared.currentLanguage
    
    // Account
    @State private var isSigningIn = false
    @State private var signInError: String?
    
    enum ConnectionTestResult {
        case success, failure(String)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Account (Supabase + Google)
                    accountSection
                    
                    // Language
                    settingsSection(title: "Language", icon: "globe", color: .elianGreen) {
                        HStack(spacing: 12) {
                            ForEach(AppLanguage.allCases) { lang in
                                Button {
                                    withAnimation(.spring(duration: 0.2)) {
                                        selectedLanguage = lang
                                        LocalizationManager.shared.currentLanguage = lang
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Text(lang.flag)
                                            .font(.system(size: 20))
                                        Text(lang.displayName)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.elianTextPrimary)
                                    }
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 12)
                                    .background(
                                        selectedLanguage == lang
                                            ? Color.elianGreen.opacity(0.12)
                                            : Color.elianSurfaceSecondary
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                selectedLanguage == lang ? Color.elianGreen.opacity(0.3) : Color.clear,
                                                lineWidth: 1
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Logineo
                    settingsSection(title: "Logineo LMS", icon: "network", color: .elianBlue) {
                        VStack(spacing: 14) {
                            // URL
                            VStack(alignment: .leading, spacing: 4) {
                                Text("School URL")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.elianTextTertiary)
                                TextField("169080.logineonrw-lms.de", text: $logineoURL)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14))
                                    .padding(12)
                                    .background(Color.elianSurfaceSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            }
                            
                            // Username
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Username")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.elianTextTertiary)
                                TextField("Your Logineo username", text: $logineoUsername)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14))
                                    .padding(12)
                                    .background(Color.elianSurfaceSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            }
                            
                            // Password
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Password")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.elianTextTertiary)
                                SecureField("Your Logineo password", text: $logineoPassword)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14))
                                    .padding(12)
                                    .background(Color.elianSurfaceSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            
                            // Save + Test
                            HStack(spacing: 12) {
                                Button {
                                    saveLogineoCredentials()
                                } label: {
                                    Text("Save")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.elianBlue)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                
                                Button {
                                    testLogineoConnection()
                                } label: {
                                    HStack(spacing: 6) {
                                        if isTestingConnection {
                                            ProgressView()
                                                .tint(.elianBlue)
                                                .scaleEffect(0.7)
                                        }
                                        Text(isTestingConnection ? "Testing..." : "Test Connection")
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.elianBlue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.elianBlue.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .disabled(isTestingConnection)
                            }
                            
                            // Connection Status
                            if let status = connectionStatus {
                                HStack(spacing: 8) {
                                    switch status {
                                    case .success:
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.elianSuccess)
                                        Text("Connected successfully")
                                            .foregroundStyle(.elianSuccess)
                                    case .failure(let msg):
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.elianError)
                                        Text(msg)
                                            .foregroundStyle(.elianError)
                                    }
                                }
                                .font(.system(size: 13, weight: .medium))
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                    
                    // Sync
                    settingsSection(title: "Background Sync", icon: "arrow.triangle.2.circlepath", color: .elianOrange) {
                        VStack(spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "clock.fill")
                                    .foregroundStyle(.elianOrange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("18:00 Daily Sync")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.elianTextPrimary)
                                    Text("Automatically scans for new homework and messages")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.elianTextTertiary)
                                }
                                Spacer()
                            }
                            
                            Button {
                                manualSync()
                            } label: {
                                HStack(spacing: 6) {
                                    if isSyncing {
                                        ProgressView().tint(.white).scaleEffect(0.7)
                                    }
                                    Text(isSyncing ? "Syncing..." : "Sync Now")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.elianOrange)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(isSyncing || !KeychainService.shared.hasLogineoCredentials)
                            .opacity(KeychainService.shared.hasLogineoCredentials ? 1 : 0.5)
                        }
                    }
                    
                    // AI Model Selection
                    settingsSection(title: "AI Model", icon: "cpu.fill", color: .elianPurple) {
                        VStack(spacing: 12) {
                            ForEach(GeminiModelOption.allCases) { model in
                                modelRow(model)
                            }
                        }
                    }
                    
                    // API Key Management
                    settingsSection(title: "API Key", icon: "key.fill", color: .elianOrange) {
                        VStack(spacing: 14) {
                            if KeychainService.shared.hasAPIKey {
                                HStack(spacing: 10) {
                                    Image(systemName: "checkmark.shield.fill")
                                        .foregroundStyle(.elianSuccess)
                                    Text("API key stored securely in Keychain")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.elianTextSecondary)
                                    Spacer()
                                }
                                .padding(14)
                                .background(Color.elianSuccess.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            HStack(spacing: 10) {
                                if showAPIKey {
                                    TextField("Enter new API key", text: $apiKey)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 14, design: .monospaced))
                                } else {
                                    SecureField("Enter new API key", text: $apiKey)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 14, design: .monospaced))
                                }
                                
                                Button { showAPIKey.toggle() } label: {
                                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                        .foregroundStyle(.elianTextTertiary)
                                }
                            }
                            .padding(14)
                            .background(Color.elianSurfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            if showError {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                    Text(errorMessage)
                                }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.elianError)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                            
                            Button(action: updateAPIKey) {
                                HStack(spacing: 6) {
                                    if isValidating {
                                        ProgressView().tint(.white).scaleEffect(0.7)
                                    }
                                    Text(isValidating ? "Validating..." : "Update API Key")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.elianOrange)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty || isValidating)
                            .opacity(apiKey.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                        }
                    }
                    
                    // Textbooks
                    settingsSection(title: "Textbooks", icon: "book.closed.fill", color: .elianPink) {
                        VStack(spacing: 16) {
                            if textbooks.isEmpty {
                                Text("No textbooks added yet.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.elianTextTertiary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                ForEach(textbooks) { textbook in
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Image(systemName: "doc.fill")
                                                .foregroundStyle(.elianPink)
                                            Text(textbook.title)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(.elianTextPrimary)
                                            Spacer()
                                            Button(role: .destructive) {
                                                modelContext.delete(textbook)
                                            } label: {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 14))
                                                    .foregroundStyle(.elianError)
                                            }
                                        }
                                        
                                        HStack {
                                            Text("Subject:")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.elianTextTertiary)
                                            
                                            Picker("Subject", selection: Binding(
                                                get: { textbook.subject },
                                                set: { textbook.subject = $0 }
                                            )) {
                                                Text("None").tag(nil as Subject?)
                                                ForEach(subjects) { subject in
                                                    Text(subject.name).tag(subject as Subject?)
                                                }
                                            }
                                            .pickerStyle(.menu)
                                            .labelsHidden()
                                            .font(.system(size: 12))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.elianSurfaceSecondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .padding(12)
                                    .background(Color.elianSurfaceSecondary.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            
                            Button {
                                showPDFPicker = true
                            } label: {
                                HStack(spacing: 8) {
                                    if isAddingTextbook {
                                        ProgressView().scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "plus")
                                    }
                                    Text("Add Textbook (PDF)")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.elianPink)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(isAddingTextbook)
                        }
                    }
                    .fileImporter(
                        isPresented: $showPDFPicker,
                        allowedContentTypes: [.pdf],
                        allowsMultipleSelection: false
                    ) { result in
                        handleTextbookImport(result)
                    }
                    
                    // About
                    settingsSection(title: "About", icon: "info.circle.fill", color: .elianBlue) {
                        VStack(spacing: 12) {
                            aboutRow(label: "App", value: "ElianAI")
                            aboutRow(label: "Version", value: "1.0.0")
                            aboutRow(label: "Powered by", value: "Google Gemini")
                            aboutRow(label: "Platform", value: "iPadOS")
                        }
                    }
                    
                    // Danger Zone
                    settingsSection(title: "Danger Zone", icon: "exclamationmark.triangle.fill", color: .elianError) {
                        VStack(spacing: 12) {
                            Button {
                                showDeleteConfirm = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash.fill")
                                    Text("Remove API Key")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.elianError)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.elianError.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.elianError.opacity(0.2), lineWidth: 1)
                                )
                            }
                            
                            Button {
                                KeychainService.shared.clearLogineoCredentials()
                                logineoUsername = ""
                                logineoPassword = ""
                                connectionStatus = nil
                                HapticEngine.notification(.warning)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.crop.circle.badge.xmark")
                                    Text("Remove Logineo Credentials")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.elianError)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.elianError.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.elianError.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
                .padding(24)
            }
            .background(Color.elianBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Remove API Key?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    KeychainService.shared.apiKey = nil
                }
            } message: {
                Text("This will remove your stored API key. You'll need to enter it again to use the app.")
            }
            .overlay {
                if showSavedToast {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Saved successfully")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.elianSuccess)
                        .clipShape(Capsule())
                        .shadow(color: .elianSuccess.opacity(0.3), radius: 10, y: 5)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }
    
    // MARK: - Model Row
    
    private func modelRow(_ model: GeminiModelOption) -> some View {
        Button {
            withAnimation(.spring(duration: 0.2)) {
                selectedModel = model
                geminiService.setModel(model)
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: selectedModel == model ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        selectedModel == model ? .elianPurple : .elianTextTertiary
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.elianTextPrimary)
                    Text(model.description)
                        .font(.system(size: 13))
                        .foregroundStyle(.elianTextTertiary)
                }
                
                Spacer()
            }
            .padding(14)
            .background(
                selectedModel == model
                    ? Color.elianPurple.opacity(0.08)
                    : Color.elianSurfaceSecondary
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        selectedModel == model
                            ? Color.elianPurple.opacity(0.3)
                            : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helpers
    
    private func settingsSection<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.elianTextPrimary)
            }
            
            content()
        }
        .padding(20)
        .background(Color.elianSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.elianBorder, lineWidth: 0.5)
        )
    }
    
    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.elianTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.elianTextPrimary)
        }
    }
    
    // MARK: - Actions
    
    private func saveLogineoCredentials() {
        KeychainService.shared.logineoURL = logineoURL
        KeychainService.shared.logineoUsername = logineoUsername
        KeychainService.shared.logineoPassword = logineoPassword
        
        withAnimation(.spring(duration: 0.3)) {
            showSavedToast = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { showSavedToast = false }
        }
        HapticEngine.notification(.success)
    }
    
    private func testLogineoConnection() {
        saveLogineoCredentials()
        isTestingConnection = true
        connectionStatus = nil
        
        Task {
            do {
                try await LogineoService.shared.login()
                await MainActor.run {
                    withAnimation(.spring(duration: 0.3)) {
                        connectionStatus = .success
                    }
                    isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    withAnimation(.spring(duration: 0.3)) {
                        connectionStatus = .failure(error.localizedDescription)
                    }
                    isTestingConnection = false
                }
            }
        }
    }
    
    private func manualSync() {
        isSyncing = true
        Task {
            await BackgroundSyncService.shared.performManualSync(modelContext: modelContext)
            await MainActor.run {
                isSyncing = false
                HapticEngine.notification(.success)
            }
        }
    }
    
    private func updateAPIKey() {
        let key = apiKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }
        
        isValidating = true
        showError = false
        Task {
            let isValid = await GeminiService.shared.validateAPIKey(key)
            await MainActor.run {
                isValidating = false
                if isValid {
                    KeychainService.shared.apiKey = key
                    apiKey = ""
                    withAnimation(.spring(duration: 0.3)) {
                        showSavedToast = true
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(2.5))
                        withAnimation { showSavedToast = false }
                    }
                } else {
                    withAnimation(.spring(duration: 0.3)) {
                        showError = true
                        errorMessage = "Invalid API key. Please check and try again."
                    }
                }
            }
        }
    }
    
    private func handleTextbookImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            
            isAddingTextbook = true
            
            do {
                let data = try Data(contentsOf: url)
                url.stopAccessingSecurityScopedResource()
                let title = url.deletingPathExtension().lastPathComponent
                
                Task {
                    await MainActor.run {
                        let newTextbook = Textbook(title: title, pdfData: data)
                        modelContext.insert(newTextbook)
                        isAddingTextbook = false
                        HapticEngine.notification(.success)
                    }
                }
            } catch {
                url.stopAccessingSecurityScopedResource()
                isAddingTextbook = false
                errorMessage = "Failed to load PDF: \(error.localizedDescription)"
                showError = true
            }
            
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        settingsSection(title: "Account", icon: "person.crop.circle.fill", color: .elianPurple) {
            if supabaseService.isSignedIn {
                // Signed in state
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        // Avatar
                        if let avatarURL = supabaseService.userAvatarURL {
                            AsyncImage(url: avatarURL) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.elianTextTertiary)
                            }
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.elianPurple)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(supabaseService.userDisplayName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.elianTextPrimary)
                            Text(supabaseService.userEmail)
                                .font(.system(size: 13))
                                .foregroundStyle(.elianTextTertiary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.elianSuccess)
                                .frame(width: 8, height: 8)
                            Text("Connected")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.elianSuccess)
                        }
                    }
                    
                    Divider().background(Color.elianBorder)
                    
                    Button {
                        Task {
                            try? await supabaseService.signOut()
                            HapticEngine.notification(.success)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 13))
                            Text("Sign Out")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(.elianError)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.elianError.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Signed out state
                VStack(spacing: 12) {
                    Text("Sign in to sync your data across devices")
                        .font(.system(size: 13))
                        .foregroundStyle(.elianTextTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let error = signInError {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                            Text(error)
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(.elianError)
                    }
                    
                    Button {
                        isSigningIn = true
                        signInError = nil
                        Task {
                            do {
                                try await supabaseService.signInWithGoogle()
                                await MainActor.run {
                                    isSigningIn = false
                                    HapticEngine.notification(.success)
                                }
                            } catch {
                                await MainActor.run {
                                    isSigningIn = false
                                    signInError = error.localizedDescription
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if isSigningIn {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "globe")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Text(isSigningIn ? "Signing in..." : "Sign in with Google")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#4285F4"), Color(hex: "#3367D6")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSigningIn)
                }
            }
        }
    }
}
