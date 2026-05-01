import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PhotosUI

struct NoteListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(GeminiService.self) private var geminiService
    
    let folder: FolderModel
    @Binding var selectedNote: NoteModel?
    
    @State private var showUploadSheet = false
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
                    
                    Button {
                        showUploadSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Notiz erstellen")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: folder.accentColorHex))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showUploadSheet) {
                UploadMaterialView(folder: folder, selectedNote: $selectedNote)
            }
            
            // Loading overlay
            if isGenerating {
                GeneratingOverlay(message: "This may take a moment...")
                    .transition(.opacity)
            }
        }
    }
    
    private func deleteNote(_ note: NoteModel) {
        if selectedNote == note { selectedNote = nil }
        modelContext.delete(note)
    }
}

// MARK: - Helper

private func noteSourceIcon(_ type: SourceType) -> String {
    switch type {
    case .text: return "text.cursor"
    case .pdf: return "doc.fill"
    case .docx: return "doc.richtext.fill"
    case .ppt: return "rectangle.stack.fill"
    case .image: return "photo.fill"
    }
}

// MARK: - Note Row

struct NoteRowView: View {
    let note: NoteModel
    let folderColor: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: noteSourceIcon(note.sourceType))
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
