import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedFolder: FolderModel?
    @State private var selectedNote: NoteModel?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showSearch = false
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedFolder: $selectedFolder)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } content: {
            if showSearch {
                SearchView(selectedNote: $selectedNote)
                    .navigationSplitViewColumnWidth(min: 280, ideal: 320)
            } else if let folder = selectedFolder {
                NoteListView(folder: folder, selectedNote: $selectedNote)
                    .navigationSplitViewColumnWidth(min: 280, ideal: 320)
            } else {
                EmptyColumnView(
                    icon: "folder.fill",
                    title: "Select a Folder",
                    subtitle: "Choose a folder from the sidebar to view your notes"
                )
            }
        } detail: {
            if let note = selectedNote {
                NoteDetailView(note: note)
            } else {
                EmptyColumnView(
                    icon: "doc.text.fill",
                    title: "Select a Note",
                    subtitle: "Choose a note to start studying"
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(.elianBlue)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        showSearch.toggle()
                        if showSearch {
                            selectedFolder = nil
                        }
                    }
                } label: {
                    Image(systemName: showSearch ? "xmark.circle.fill" : "magnifyingglass")
                        .font(.system(size: 18))
                        .foregroundStyle(showSearch ? .elianOrange : .elianTextSecondary)
                }
            }
        }
    }
}

// MARK: - Empty Column Placeholder

struct EmptyColumnView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    @State private var animateIcon = false
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.elianTextTertiary, .elianTextTertiary.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(animateIcon ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animateIcon)
            
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.elianTextSecondary)
            
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(.elianTextTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.elianBackground)
        .onAppear { animateIcon = true }
    }
}
