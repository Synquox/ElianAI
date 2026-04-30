import SwiftUI
import SwiftData
import PDFKit
import UniformTypeIdentifiers

struct TextbookView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Textbook.createdAt, order: .reverse) private var textbooks: [Textbook]
    
    @State private var showFilePicker = false
    @State private var selectedTextbook: Textbook?
    @State private var extractedPageNumber: Int?
    @State private var extractedPageImage: UIImage?
    @State private var pageNumberInput = ""
    @State private var solverPrompt = ""
    @State private var showSolverPrompt = false
    @State private var isExtractingPage = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Textbook list
                if textbooks.isEmpty {
                    emptyState
                } else {
                    textbookList
                }
                
                // Page extraction (if textbook selected)
                if let textbook = selectedTextbook, textbook.pdfData != nil {
                    pageExtractionSection(textbook)
                }
                
                // Solver prompt
                if showSolverPrompt && !solverPrompt.isEmpty {
                    solverPromptSection
                }
            }
            .padding(24)
        }
        .background(Color.elianBackground)
        .navigationTitle("Textbooks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showFilePicker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.elianBlue)
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.pdf]
        ) { result in
            handlePDFImport(result)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.book.closed.fill")
                .font(.system(size: 48))
                .foregroundStyle(.elianBlue.opacity(0.5))
            
            Text("No Textbooks")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.elianTextPrimary)
            
            Text("Upload a textbook PDF to enable page extraction and solver prompts.")
                .font(.system(size: 15))
                .foregroundStyle(.elianTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            
            Button {
                showFilePicker = true
            } label: {
                Text("Upload Textbook")
                    .elianButton(color: .elianBlue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Textbook List
    
    private var textbookList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your Textbooks")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.elianTextPrimary)
            
            ForEach(textbooks) { textbook in
                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        selectedTextbook = textbook
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "text.book.closed.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.elianBlue)
                            .frame(width: 44, height: 44)
                            .background(Color.elianBlue.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(textbook.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.elianTextPrimary)
                            
                            HStack(spacing: 8) {
                                Text("\(textbook.pageCount) pages")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.elianTextTertiary)
                                
                                if let subject = textbook.subject {
                                    HStack(spacing: 3) {
                                        Image(systemName: "link")
                                            .font(.system(size: 9))
                                        Text(subject.name)
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundStyle(Color(hex: subject.colorHex))
                                }
                            }
                        }
                        
                        Spacer()
                        
                        if selectedTextbook?.id == textbook.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.elianBlue)
                        }
                    }
                    .padding(14)
                    .background(
                        selectedTextbook?.id == textbook.id
                            ? Color.elianBlue.opacity(0.08)
                            : Color.elianSurface
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                selectedTextbook?.id == textbook.id
                                    ? Color.elianBlue.opacity(0.3)
                                    : Color.elianBorder,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        if selectedTextbook?.id == textbook.id {
                            selectedTextbook = nil
                        }
                        modelContext.delete(textbook)
                    } label: {
                        Label("Delete Textbook", systemImage: "trash")
                    }
                }
            }
        }
    }
    
    // MARK: - Page Extraction
    
    private func pageExtractionSection(_ textbook: Textbook) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Extract Page")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.elianTextPrimary)
            
            HStack(spacing: 12) {
                TextField("Page number (e.g. 45)", text: $pageNumberInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .keyboardType(.numberPad)
                    .padding(14)
                    .background(Color.elianSurfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Button {
                    extractPage(from: textbook)
                } label: {
                    if isExtractingPage {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Extract")
                    }
                }
                .elianButton(color: .elianBlue)
                .disabled(pageNumberInput.isEmpty || isExtractingPage)
            }
            
            // Extracted page preview
            if let image = extractedPageImage {
                VStack(spacing: 12) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                    
                    HStack(spacing: 12) {
                        // Download button
                        ShareLink(
                            item: Image(uiImage: image),
                            preview: SharePreview("Page \(extractedPageNumber ?? 0)", image: Image(uiImage: image))
                        ) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.down")
                                Text("Save Page")
                            }
                            .elianOutlineButton(color: .elianBlue)
                        }
                        
                        // Solver prompt button
                        Button {
                            generateSolverPrompt(textbook: textbook)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "brain.head.profile.fill")
                                Text("Solver Prompt")
                            }
                            .elianOutlineButton(color: .elianPurple)
                        }
                    }
                }
            }
        }
        .elianCard()
    }
    
    // MARK: - Solver Prompt Section
    
    private var solverPromptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Solver Prompt")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.elianTextPrimary)
                
                Spacer()
                
                Button {
                    UIPasteboard.general.string = solverPrompt
                    HapticEngine.notification(.success)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.elianPurple)
                }
            }
            
            Text(solverPrompt)
                .font(.system(size: 14))
                .foregroundStyle(.elianTextSecondary)
                .padding(14)
                .background(Color.elianSurfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .textSelection(.enabled)
        }
        .elianCard()
    }
    
    // MARK: - Actions
    
    private func handlePDFImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            
            guard let data = try? Data(contentsOf: url) else { return }
            let document = PDFDocument(data: data)
            let pageCount = document?.pageCount ?? 0
            let title = url.deletingPathExtension().lastPathComponent
            
            let textbook = Textbook(
                title: title,
                pdfData: data,
                pageCount: pageCount
            )
            modelContext.insert(textbook)
            try? modelContext.save()
            selectedTextbook = textbook
            HapticEngine.notification(.success)
            
        case .failure:
            break
        }
    }
    
    private func extractPage(from textbook: Textbook) {
        guard let pageNum = Int(pageNumberInput),
              let pdfData = textbook.pdfData else { return }
        
        isExtractingPage = true
        
        Task {
            let image = TextbookService.shared.extractPageAsImage(from: pdfData, pageNumber: pageNum)
            await MainActor.run {
                extractedPageImage = image
                extractedPageNumber = pageNum
                isExtractingPage = false
                HapticEngine.selection()
            }
        }
    }
    
    private func generateSolverPrompt(textbook: Textbook) {
        guard let pageNum = extractedPageNumber,
              let pdfData = textbook.pdfData else { return }
        
        let pageText = TextbookService.shared.extractPageText(from: pdfData, pageNumber: pageNum) ?? "Could not extract text from page."
        let subjectName = textbook.subject?.name ?? "Unknown Subject"
        
        solverPrompt = TextbookService.shared.generateSolverPrompt(
            pageContent: pageText,
            taskDescription: "Exercise from page \(pageNum)",
            subjectName: subjectName
        )
        
        withAnimation(.spring(duration: 0.3)) {
            showSolverPrompt = true
        }
    }
}
