import SwiftUI
import SwiftData

// MARK: - Navigation Destination Enum

enum SidebarDestination: Hashable {
    case timetable
    case homework
    case substitutionPlan
    case messages
    case textbooks
    case folder(FolderModel)
}

struct ContentView: View {
    @State private var selectedDestination: SidebarDestination?
    @State private var selectedNote: NoteModel?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showSearch = false
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedDestination: $selectedDestination)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } content: {
            if showSearch {
                SearchView(selectedNote: $selectedNote)
                    .navigationSplitViewColumnWidth(min: 280, ideal: 320)
            } else {
                contentColumn
                    .navigationSplitViewColumnWidth(min: 280, ideal: 320)
            }
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        .tint(.elianBlue)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        showSearch.toggle()
                        if showSearch {
                            selectedDestination = nil
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
    
    // MARK: - Content Column
    
    @ViewBuilder
    private var contentColumn: some View {
        switch selectedDestination {
        case .timetable:
            TimetableView()
        case .homework:
            HomeworkView()
        case .substitutionPlan:
            SubstitutionPlanView()
        case .messages:
            MessageCenterView()
        case .textbooks:
            TextbookView()
        case .folder(let folder):
            NoteListView(folder: folder, selectedNote: $selectedNote)
        case nil:
            EmptyColumnView(
                icon: "sidebar.left",
                title: "ElianAI",
                subtitle: "Choose an item from the sidebar to get started"
            )
        }
    }
    
    // MARK: - Detail Column
    
    @ViewBuilder
    private var detailColumn: some View {
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
