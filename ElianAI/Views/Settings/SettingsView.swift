import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(GeminiService.self) private var geminiService
    
    @State private var selectedModel: GeminiModelOption = GeminiService.shared.currentModel
    @State private var apiKey: String = ""
    @State private var showAPIKey = false
    @State private var isValidating = false
    @State private var showDeleteConfirm = false
    @State private var showSavedToast = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Model Selection
                    settingsSection(title: "AI Model", icon: "cpu.fill", color: .elianPurple) {
                        VStack(spacing: 12) {
                            ForEach(GeminiModelOption.allCases) { model in
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
                                
                                Button {
                                    showAPIKey.toggle()
                                } label: {
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
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(0.7)
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
                            Text("API Key updated successfully")
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
                        withAnimation {
                            showSavedToast = false
                        }
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
}
