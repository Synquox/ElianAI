import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct NoteListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(GeminiService.self) private var geminiService
    
    let folder: FolderModel
    @Binding var selectedNote: NoteModel?
    
    @State private var showNewNoteSheet = false
    @State private var showPDFPicker = false
    @State private var inputText = ""
    @State private var isGenerating = false
    @State private var errorMessage: String?
    
    private var sortedNotes: [NoteModel] {
        folder.notes.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    var body: some View {
        ZStack {
            List(selection: $selectedNote) {
                if sortedNotes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.elianTextTertiary)
                        Text("No notes yet")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.elianTextSecondary)
                        Text("Create a note by pasting text or uploading a PDF")
                            .font(.system(size: 13))
                            .foregroundStyle(.elianTextTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(sortedNotes) { note in
                        NavigationLink(value: note) {
                            NoteRowView(note: note, folderColor: folder.accentColorHex)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteNote(note)
                            } label: {
                                Label("Delete Note", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.elianBackground)
            .navigationTitle(folder.name)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    NavigationLink {
                        AnalyticsDashboardView(folder: folder)
                    } label: {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 20))
                            .foregroundStyle(Color(hex: folder.accentColorHex))
                    }
                    
                    Menu {
                        Button {
                            showNewNoteSheet = true
                        } label: {
                            Label("From Text", systemImage: "text.cursor")
                        }
                        
                        Button {
                            showPDFPicker = true
                        } label: {
                            Label("From PDF", systemImage: "doc.fill")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color(hex: folder.accentColorHex))
                    }
                }
            }
            .sheet(isPresented: $showNewNoteSheet) {
                textInputSheet
            }
            .fileImporter(
                isPresented: $showPDFPicker,
                allowedContentTypes: [UTType.pdf]
            ) { result in
                handlePDFImport(result)
            }
            
            // Loading overlay
            if isGenerating {
                GeneratingOverlay(message: "This may take a moment...")
                    .transition(.opacity)
            }
        }
    }
    
    // MARK: - Text Input Sheet
    
    private var textInputSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paste or type your study content")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.elianTextPrimary)
                    
                    Text("ElianAI will generate rich notes, quizzes, and flashcards from this content.")
                        .font(.system(size: 13))
                        .foregroundStyle(.elianTextTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                TextEditor(text: $inputText)
                    .font(.system(size: 15))
                    .scrollContentBackground(.hidden)
                    .padding(14)
                    .background(Color.elianSurfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.elianBorder, lineWidth: 1)
                    )
                    .frame(minHeight: 200)
                
                if let error = errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.elianError)
                }
                
                Button(action: { generateFromText() }) {
                    HStack(spacing: 8) {
                        if isGenerating {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        }
                        Text(isGenerating ? "Generating Study Materials..." : "✨ Generate Study Materials")
                    }
                    .elianButton(color: Color(hex: folder.accentColorHex), fullWidth: true)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
                .opacity(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            }
            .padding(24)
            .background(Color.elianBackground)
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showNewNoteSheet = false
                        inputText = ""
                        errorMessage = nil
                    }
                    .disabled(isGenerating)
                }
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(isGenerating)
    }
    
    // MARK: - Actions
    
    private func generateFromText() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        isGenerating = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await geminiService.generateStudyContent(from: text)
                
                await MainActor.run {
                    let note = NoteModel(
                        title: response.noteTitle,
                        rawContent: text,
                        generatedMarkdown: response.noteMarkdown,
                        sourceType: .text,
                        folder: folder
                    )
                    modelContext.insert(note)
                    
                    // Insert quiz questions
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
                    
                    // Insert flashcards
                    for f in response.flashcards {
                        let card = Flashcard(front: f.front, back: f.back)
                        card.note = note
                        modelContext.insert(card)
                    }
                    
                    selectedNote = note
                    isGenerating = false
                    showNewNoteSheet = false
                    inputText = ""
                    try? modelContext.save()
                    HapticEngine.notification(.success)
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func handlePDFImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            
            guard let data = try? Data(contentsOf: url),
                  let text = geminiService.extractTextFromPDF(data: data) else {
                errorMessage = "Could not extract text from PDF."
                return
            }
            
            inputText = text
            showNewNoteSheet = true
            
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
    
    private func deleteNote(_ note: NoteModel) {
        if selectedNote == note { selectedNote = nil }
        modelContext.delete(note)
    }
}

// MARK: - Note Row

struct NoteRowView: View {
    let note: NoteModel
    let folderColor: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: note.sourceType == .pdf ? "doc.fill" : "text.cursor")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: folderColor))
                
                Text(note.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.elianTextPrimary)
                    .lineLimit(1)
            }
            
            Text(note.generatedMarkdown.prefix(120).replacingOccurrences(of: "\n", with: " "))
                .font(.system(size: 13))
                .foregroundStyle(.elianTextTertiary)
                .lineLimit(2)
            
            HStack(spacing: 12) {
                StatPill(icon: "questionmark.circle", count: note.quizQuestions.count, label: "Quiz")
                StatPill(icon: "rectangle.on.rectangle", count: note.flashcards.count, label: "Cards")
                
                Spacer()
                
                Text(note.updatedAt.formatted(.relative(presentation: .named)))
                    .font(.system(size: 11))
                    .foregroundStyle(.elianTextTertiary)
            }
        }
        .padding(.vertical, 6)
    }
}

struct StatPill: View {
    let icon: String
    let count: Int
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text("\(count) \(label)")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(.elianTextSecondary)
    }
}
