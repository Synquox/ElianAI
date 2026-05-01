import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import GoogleGenerativeAI

struct UploadMaterialView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(GeminiService.self) private var geminiService
    
    let folder: FolderModel
    @Binding var selectedNote: NoteModel?
    
    init(folder: FolderModel, selectedNote: Binding<NoteModel?>) {
        self.folder = folder
        self._selectedNote = selectedNote
    }
    
    @State private var items: [MaterialItem] = []
    @State private var isGenerating = false
    @State private var errorMessage: String?
    
    // Pickers
    @State private var showFilePicker = false
    @State private var filePickerMode: FilePickerMode = .pdf
    @State private var showImagePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showTextEditor = false
    @State private var draftText = ""
    
    // Recording
    @State private var isRecording = false
    private var audioRecorder = AudioRecorderService.shared
    
    enum FilePickerMode {
        case pdf, docx, ppt, audio
    }
    
    struct MaterialItem: Identifiable {
        let id = UUID()
        let type: SourceType
        let name: String
        let data: Data?
        let text: String?
        
        var icon: String {
            switch type {
            case .pdf: return "doc.fill"
            case .image: return "photo.fill"
            case .docx: return "doc.richtext.fill"
            case .ppt: return "rectangle.stack.fill"
            case .audio: return "waveform"
            case .text: return "text.alignleft"
            default: return "doc"
            }
        }
        
        var color: Color {
            switch type {
            case .pdf: return .red
            case .image: return .green
            case .docx: return .blue
            case .ppt: return .orange
            case .audio: return .purple
            case .text: return .gray
            default: return .blue
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if items.isEmpty {
                    emptyState
                } else {
                    itemList
                }
                
                bottomActions
            }
            .background(Color.elianBackground)
            .navigationTitle("Materialien hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .disabled(isGenerating)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        generateNote()
                    } label: {
                        if isGenerating {
                            ProgressView().tint(.elianBlue)
                        } else {
                            Text("Generieren")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(items.isEmpty || isGenerating)
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: allowedContentTypes(for: filePickerMode),
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result)
            }
            .photosPicker(isPresented: $showImagePicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, newValue in
                handleImageImport(newValue)
            }
            .sheet(isPresented: $showTextEditor) {
                textEditorSheet
            }
            .overlay {
                if isGenerating {
                    GeneratingOverlay(message: "Lerne alles aus deinen Materialien...")
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.on.doc.fill")
                .font(.system(size: 64))
                .foregroundStyle(.elianTextTertiary.opacity(0.3))
            
            Text("Noch keine Materialien")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.elianTextPrimary)
            
            Text("Füge Bilder, PDFs, Dokumente oder Audio-Aufnahmen hinzu, um eine zusammenhängende Notiz zu erstellen.")
                .font(.system(size: 14))
                .foregroundStyle(.elianTextTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var itemList: some View {
        List {
            ForEach(items) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(item.color)
                        .frame(width: 32, height: 32)
                        .background(item.color.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.elianTextPrimary)
                        
                        Text(item.type.rawValue.capitalized)
                            .font(.system(size: 12))
                            .foregroundStyle(.elianTextTertiary)
                    }
                    
                    Spacer()
                    
                    Button {
                        items.removeAll { $0.id == item.id }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.elianTextTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
            .onDelete { indexSet in
                items.remove(atOffsets: indexSet)
            }
        }
        .listStyle(.plain)
    }
    
    private var bottomActions: some View {
        VStack(spacing: 16) {
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.elianError)
                    .padding(.horizontal)
            }
            
            HStack(spacing: 12) {
                actionButton(icon: "photo.fill", color: .green, label: "Bild") {
                    showImagePicker = true
                }
                
                actionButton(icon: "doc.fill", color: .red, label: "PDF") {
                    filePickerMode = .pdf
                    showFilePicker = true
                }
                
                actionButton(icon: "doc.richtext.fill", color: .blue, label: "Doc") {
                    filePickerMode = .docx
                    showFilePicker = true
                }
                
                actionButton(icon: "waveform", color: .purple, label: audioRecorder.isRecording ? "Stopp" : "Audio") {
                    if audioRecorder.isRecording {
                        audioRecorder.stopRecording()
                        if let data = audioRecorder.getRecordingData() {
                            items.append(MaterialItem(type: .audio, name: "Aufnahme \(items.count + 1)", data: data, text: nil))
                        }
                    } else {
                        Task {
                            do {
                                try await audioRecorder.startRecording()
                            } catch {
                                await MainActor.run {
                                    errorMessage = "Aufnahme konnte nicht gestartet werden"
                                }
                            }
                        }
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if audioRecorder.isRecording {
                        Circle()
                            .fill(.red)
                            .frame(width: 10, height: 10)
                            .padding(4)
                    }
                }
                
                actionButton(icon: "text.alignleft", color: .gray, label: "Text") {
                    showTextEditor = true
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .padding(.top, 16)
        .background(Color.elianSurface)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
        .shadow(color: .black.opacity(0.05), radius: 10, y: -5)
    }
    
    private func actionButton(icon: String, color: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
                    .frame(width: 50, height: 50)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.elianTextSecondary)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var textEditorSheet: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $draftText)
                    .padding()
                    .background(Color.elianSurfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
            }
            .navigationTitle("Text hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { showTextEditor = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") {
                        if !draftText.trimmingCharacters(in: .whitespaces).isEmpty {
                            items.append(MaterialItem(type: .text, name: "Text Snippet", data: nil, text: draftText))
                            draftText = ""
                            showTextEditor = false
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Handlers
    
    private func allowedContentTypes(for mode: FilePickerMode) -> [UTType] {
        switch mode {
        case .pdf: return [.pdf]
        case .docx: return [UTType(filenameExtension: "docx")].compactMap { $0 }
        case .ppt: return [UTType(filenameExtension: "pptx")].compactMap { $0 }
        case .audio: return [.audio]
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                
                if let data = try? Data(contentsOf: url) {
                    let type: SourceType = {
                        if url.pathExtension.lowercased() == "pdf" { return .pdf }
                        if url.pathExtension.lowercased() == "docx" { return .docx }
                        if url.pathExtension.lowercased() == "pptx" { return .ppt }
                        return .text
                    }()
                    items.append(MaterialItem(type: type, name: url.lastPathComponent, data: data, text: nil))
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
    
    private func handleImageImport(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                items.append(MaterialItem(type: .image, name: "Bild \(items.count + 1)", data: data, text: nil))
            }
            selectedPhotoItem = nil
        }
    }
    
    private func generateNote() {
        isGenerating = true
        errorMessage = nil
        
        Task {
            do {
                var parts: [ModelContent.Part] = []
                
                for item in items {
                    switch item.type {
                    case .text:
                        if let text = item.text {
                            parts.append(.text(text))
                        }
                    case .pdf:
                        if let data = item.data, let text = geminiService.extractTextFromPDF(data: data) {
                            parts.append(.text(text))
                        }
                    case .image:
                        if let data = item.data {
                            parts.append(.data(mimetype: "image/jpeg", data))
                        }
                    case .audio:
                        if let data = item.data {
                            parts.append(.data(mimetype: "audio/mpeg", data))
                        }
                    case .docx:
                        if let data = item.data, let text = TextbookService.shared.extractTextFromDOCX(data: data) {
                            parts.append(.text(text))
                        }
                    case .ppt:
                        if let data = item.data, let text = TextbookService.shared.extractTextFromPPTX(data: data) {
                            parts.append(.text(text))
                        }
                    default: break
                    }
                }
                
                let response = try await geminiService.generateStudyContent(from: parts)
                
                await MainActor.run {
                    let note = NoteModel(
                        title: response.noteTitle,
                        rawContent: "Combined Material Note",
                        generatedMarkdown: response.noteMarkdown,
                        sourceType: .multiple,
                        folder: folder
                    )
                    modelContext.insert(note)
                    
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
                    
                    selectedNote = note
                    isGenerating = false
                    try? modelContext.save()
                    HapticEngine.notification(.success)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }
}
