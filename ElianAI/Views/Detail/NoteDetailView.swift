import SwiftUI
import MarkdownUI

struct NoteDetailView: View {
    let note: NoteModel
    @State private var selectedTool: StudyToolBadge.Tool = .notes
    
    @Environment(\.modelContext) private var modelContext
    @Environment(GeminiService.self) private var geminiService
    @State private var isRegenerating = false
    @State private var ttsService = TTSService()
    @State private var regenerationError: String?
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Tool selection bar
                toolBar
                
                // Active tool view
                switch selectedTool {
                case .notes:
                    noteContentView
                case .quiz:
                    QuizView(note: note)
                case .flashcards:
                    FlashcardView(note: note)
                case .chat:
                    ChatView(note: note)
                }
            }
            .background(Color.elianBackground)
            .navigationTitle(note.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    // Export / Share
                    ShareLink(item: note.generatedMarkdown, preview: SharePreview(note.title)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    
                    // TTS Audio
                    Button {
                        ttsService.togglePlayPause(text: note.generatedMarkdown)
                    } label: {
                        Image(systemName: ttsService.isSpeaking ? "pause.circle.fill" : "speaker.wave.2.fill")
                    }
                    
                    // Options Menu
                    Menu {
                        Button(role: .destructive) {
                            regenerateNote()
                        } label: {
                            Label("Regenerate Note", systemImage: "arrow.triangle.2.circlepath")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(isRegenerating)
                }
            }
            
            if isRegenerating {
                GeneratingOverlay(message: "Re-analyzing and generating new materials...")
                    .transition(.opacity)
            }
        }
        .onDisappear {
            ttsService.stop()
        }
        .alert("Regeneration Failed", isPresented: Binding(
            get: { regenerationError != nil },
            set: { if !$0 { regenerationError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(regenerationError ?? "An unknown error occurred.")
        }
    }
    
    // MARK: - Actions
    
    private func regenerateNote() {
        guard !isRegenerating else { return }
        isRegenerating = true
        HapticEngine.selection()
        
        Task {
            do {
                let response = try await geminiService.generateStudyContent(from: note.rawContent)
                
                await MainActor.run {
                    // Update note
                    note.title = response.noteTitle
                    note.generatedMarkdown = response.noteMarkdown
                    note.updatedAt = .now
                    
                    // Clear old and insert new quizzes/flashcards
                    for q in note.quizQuestions { modelContext.delete(q) }
                    for f in note.flashcards { modelContext.delete(f) }
                    
                    for q in response.quizQuestions {
                        let question = QuizQuestion(
                            questionText: q.question,
                            options: q.options,
                            correctAnswerIndex: q.correctAnswerIndex,
                            explanation: q.explanation
                        )
                        question.note = note
                        modelContext.insert(question)
                    }
                    
                    for f in response.flashcards {
                        let card = Flashcard(front: f.front, back: f.back)
                        card.note = note
                        modelContext.insert(card)
                    }
                    
                    try? modelContext.save()
                    isRegenerating = false
                    HapticEngine.notification(.success)
                }
            } catch {
                await MainActor.run {
                    isRegenerating = false
                    regenerationError = error.localizedDescription
                    HapticEngine.notification(.error)
                }
            }
        }
    }
    
    private var toolBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach([StudyToolBadge.Tool.notes, .quiz, .flashcards, .chat], id: \.label) { tool in
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            selectedTool = tool
                        }
                        HapticEngine.selection()
                    } label: {
                        StudyToolBadge(tool: tool, isSelected: selectedTool == tool)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color.elianSurface)
        .overlay(alignment: .bottom) {
            Divider().background(Color.elianBorder)
        }
    }
    
    private var noteContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: note.sourceType == .pdf ? "doc.fill" : "text.cursor")
                        .font(.system(size: 18))
                        .foregroundStyle(.elianBlue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.elianTextPrimary)
                        
                        Text("Generated \(note.createdAt.formatted(.relative(presentation: .named)))")
                            .font(.system(size: 13))
                            .foregroundStyle(.elianTextTertiary)
                    }
                }
                .padding(.bottom, 8)
                
                Divider().background(Color.elianBorder)
                
                // Rich Text + LaTeX Rendered Content
                RichTextView(text: note.generatedMarkdown)
            }
            .padding(24)
        }
    }
}

// MARK: - Custom MarkdownUI Theme

extension MarkdownUI.Theme {
    static var elianAI: Theme {
        let base = Theme()
            .text {
                ForegroundColor(.elianTextPrimary)
                FontSize(16)
            }
            .heading1 { configuration in
                configuration.label
                    .markdownMargin(top: 24, bottom: 12)
                    .markdownTextStyle {
                        FontWeight(.bold)
                        FontSize(28)
                        ForegroundColor(.elianTextPrimary)
                    }
            }
            .heading2 { configuration in
                configuration.label
                    .markdownMargin(top: 20, bottom: 10)
                    .markdownTextStyle {
                        FontWeight(.bold)
                        FontSize(22)
                        ForegroundColor(.elianBlue)
                    }
            }
            
        let step1 = base
            .heading3 { configuration in
                configuration.label
                    .markdownMargin(top: 16, bottom: 8)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(18)
                        ForegroundColor(.elianPurple)
                    }
            }
            .strong {
                FontWeight(.bold)
                ForegroundColor(.elianTextPrimary)
            }
            .emphasis {
                FontStyle(.italic)
                ForegroundColor(.elianTextSecondary)
            }
            
        let step2 = step1
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(14)
                ForegroundColor(.elianGreen)
                BackgroundColor(Color.elianSurfaceSecondary)
            }
            .codeBlock { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(14)
                        ForegroundColor(.elianTextPrimary)
                    }
                    .padding(16)
                    .background(Color.elianSurfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .markdownMargin(top: 8, bottom: 8)
            }
            
        let step3 = step2
            .table { configuration in
                configuration.label
                    .markdownTableBorderStyle(TableBorderStyle(color: Color.elianBorder))
                    .markdownMargin(top: 8, bottom: 8)
            }
            .tableCell { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontSize(14)
                        ForegroundColor(.elianTextPrimary)
                    }
                    .padding(Edge.Set.horizontal, 12)
                    .padding(Edge.Set.vertical, 8)
            }
            
        return step3
            .listItem { configuration in
                configuration.label
                    .markdownMargin(top: 4, bottom: 4)
            }
            .blockquote { configuration in
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.elianBlue)
                        .frame(width: 4)
                    configuration.label
                        .markdownTextStyle {
                            ForegroundColor(.elianTextSecondary)
                            FontStyle(.italic)
                        }
                        .padding(Edge.Set.leading, 12)
                }
                .padding(Edge.Set.vertical, 4)
            }
    }
}
