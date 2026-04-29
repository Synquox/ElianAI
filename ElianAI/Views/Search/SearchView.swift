import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NoteModel.updatedAt, order: .reverse) private var allNotes: [NoteModel]
    
    @Binding var selectedNote: NoteModel?
    @State private var searchText = ""
    @State private var isSearching = false
    
    private var filteredNotes: [NoteModel] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return []
        }
        let query = searchText.lowercased()
        return allNotes.filter { note in
            note.title.lowercased().contains(query) ||
            note.generatedMarkdown.lowercased().contains(query) ||
            note.rawContent.lowercased().contains(query)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.elianTextTertiary)
                
                TextField("Search all notes...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .onSubmit { isSearching = true }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.elianTextTertiary)
                    }
                }
            }
            .padding(14)
            .background(Color.elianSurfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider().background(Color.elianBorder)
            
            // Results
            if searchText.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.elianTextTertiary)
                    Text("Search your notes")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.elianTextSecondary)
                    Text("Find notes by title or content across all folders")
                        .font(.system(size: 14))
                        .foregroundStyle(.elianTextTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredNotes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.elianTextTertiary)
                    Text("No results for \"\(searchText)\"")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.elianTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredNotes) { note in
                        Button {
                            selectedNote = note
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    if let folder = note.folder {
                                        Image(systemName: folder.icon)
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color(hex: folder.accentColorHex))
                                        
                                        Text(folder.name)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(Color(hex: folder.accentColorHex))
                                    }
                                    
                                    Spacer()
                                    
                                    Text(note.updatedAt.formatted(.relative(presentation: .named)))
                                        .font(.system(size: 11))
                                        .foregroundStyle(.elianTextTertiary)
                                }
                                
                                Text(note.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.elianTextPrimary)
                                
                                Text(highlightedPreview(for: note))
                                    .font(.system(size: 13))
                                    .foregroundStyle(.elianTextSecondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.elianBackground)
    }
    
    private func highlightedPreview(for note: NoteModel) -> String {
        let content = note.generatedMarkdown.replacingOccurrences(of: "\n", with: " ")
        let query = searchText.lowercased()
        
        if let range = content.lowercased().range(of: query) {
            let start = content.index(range.lowerBound, offsetBy: -40, limitedBy: content.startIndex) ?? content.startIndex
            let end = content.index(range.upperBound, offsetBy: 60, limitedBy: content.endIndex) ?? content.endIndex
            let snippet = content[start..<end]
            return (start == content.startIndex ? "" : "...") + snippet + (end == content.endIndex ? "" : "...")
        }
        
        return String(content.prefix(120))
    }
}
