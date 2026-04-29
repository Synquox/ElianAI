import SwiftUI
import SwiftData
import MarkdownUI

struct ChatView: View {
    let note: NoteModel
    
    @Environment(\.modelContext) private var modelContext
    @Environment(GeminiService.self) private var geminiService
    
    @State private var messageText = ""
    @State private var isLoading = false
    @State private var scrollProxy: ScrollViewProxy?
    
    private var sortedMessages: [ChatMessage] {
        note.chatMessages.sorted { $0.timestamp < $1.timestamp }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if sortedMessages.isEmpty {
                            welcomeBanner
                        }
                        
                        ForEach(sortedMessages) { message in
                            ChatBubbleView(message: message)
                                .id(message.id)
                        }
                        
                        if isLoading {
                            HStack(spacing: 8) {
                                TypingIndicator()
                                Text("Thinking...")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.elianTextTertiary)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .id("loading")
                        }
                    }
                    .padding(20)
                }
                .onAppear { scrollProxy = proxy }
            }
            
            Divider().background(Color.elianBorder)
            
            // Input bar
            inputBar
        }
        .background(Color.elianBackground)
    }
    
    // MARK: - Welcome Banner
    
    private var welcomeBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.elianOrange, .elianPink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Chat with your Notes")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.elianTextPrimary)
            
            Text("Ask any question about \"\(note.title)\" and get AI-powered answers based on your study notes.")
                .font(.system(size: 14))
                .foregroundStyle(.elianTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            
            // Suggested questions
            VStack(spacing: 8) {
                SuggestedQuestion(text: "Explain the key concepts", action: { sendSuggested("Explain the key concepts from these notes in simple terms.") })
                SuggestedQuestion(text: "Give me a summary", action: { sendSuggested("Provide a brief summary of the main points.") })
                SuggestedQuestion(text: "What are the most important takeaways?", action: { sendSuggested("What are the most important takeaways from this material?") })
            }
            .padding(.top, 8)
        }
        .padding(24)
    }
    
    // MARK: - Input Bar
    
    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask about your notes...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .lineLimit(1...5)
                .padding(14)
                .background(Color.elianSurfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? .elianTextTertiary
                            : .elianOrange
                    )
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.elianSurface)
    }
    
    // MARK: - Actions
    
    private func sendSuggested(_ text: String) {
        messageText = text
        sendMessage()
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Add user message
        let userMsg = ChatMessage(role: .user, content: text, note: note)
        modelContext.insert(userMsg)
        messageText = ""
        
        isLoading = true
        
        // Scroll to bottom
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation {
                scrollProxy?.scrollTo("loading", anchor: .bottom)
            }
        }
        
        Task {
            do {
                let history = sortedMessages.map { (role: $0.role.rawValue, content: $0.content) }
                let response = try await geminiService.chatWithNotes(
                    noteContent: note.generatedMarkdown,
                    history: history,
                    userMessage: text
                )
                
                await MainActor.run {
                    let assistantMsg = ChatMessage(role: .assistant, content: response, note: note)
                    modelContext.insert(assistantMsg)
                    isLoading = false
                    try? modelContext.save()
                    
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(100))
                        withAnimation {
                            scrollProxy?.scrollTo(assistantMsg.id, anchor: .bottom)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    let errorMsg = ChatMessage(
                        role: .assistant,
                        content: "⚠️ Error: \(error.localizedDescription)",
                        note: note
                    )
                    modelContext.insert(errorMsg)
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubbleView: View {
    let message: ChatMessage
    
    private var isUser: Bool { message.role == .user }
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isUser { Spacer(minLength: 60) }
            
            if !isUser {
                // AI avatar
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.elianOrange)
                    .frame(width: 32, height: 32)
                    .background(Color.elianOrange.opacity(0.15))
                    .clipShape(Circle())
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if isUser {
                    Text(message.content)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(
                            LinearGradient(
                                colors: [.elianBlue, .elianPurple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                } else {
                    Markdown(message.content)
                        .markdownTheme(.elianAI)
                        .textSelection(.enabled)
                        .padding(14)
                        .background(Color.elianSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.elianBorder, lineWidth: 0.5)
                        )
                }
                
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundStyle(.elianTextTertiary)
            }
            
            if !isUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animationPhase = 0.0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.elianOrange.opacity(0.6))
                    .frame(width: 7, height: 7)
                    .offset(y: sin(animationPhase + Double(index) * .pi / 1.5) * 4)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                animationPhase = .pi * 2
            }
        }
    }
}

// MARK: - Suggested Question

struct SuggestedQuestion: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(.elianOrange)
                
                Text(text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.elianTextPrimary)
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.elianTextTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.elianSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.elianBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
