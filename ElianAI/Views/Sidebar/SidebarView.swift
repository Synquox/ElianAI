import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FolderModel.createdAt, order: .reverse) private var folders: [FolderModel]
    @Binding var selectedDestination: SidebarDestination?
    
    @State private var showAddFolder = false
    @State private var showEditFolder = false
    @State private var showSettings = false
    @State private var editingFolder: FolderModel?
    @State private var newFolderName = ""
    @State private var selectedColor = "#4A9EFF"
    @State private var selectedIcon = "folder.fill"
    
    private let folderColors = [
        "#4A9EFF", "#A855F7", "#34D399", "#FB923C",
        "#F472B6", "#EF4444", "#F59E0B", "#06B6D4"
    ]
    
    private let folderIcons = [
        "folder.fill", "book.fill", "flask.fill", "function",
        "globe.americas.fill", "paintpalette.fill", "music.note",
        "cpu.fill", "heart.fill", "star.fill"
    ]
    
    var body: some View {
        List(selection: $selectedDestination) {
            // MARK: - School Section
            Section {
                sidebarItem(
                    destination: .timetable,
                    icon: "calendar",
                    label: "Timetable",
                    color: .elianBlue
                )
                
                sidebarItem(
                    destination: .homework,
                    icon: "checklist",
                    label: "Homework",
                    color: .elianGreen
                )
                
                sidebarItem(
                    destination: .substitutionPlan,
                    icon: "doc.text.magnifyingglass",
                    label: "Vertretungsplan",
                    color: .elianPurple
                )
                
                sidebarItem(
                    destination: .messages,
                    icon: "envelope.fill",
                    label: "Messages",
                    color: .elianOrange
                )
                
                sidebarItem(
                    destination: .textbooks,
                    icon: "text.book.closed.fill",
                    label: "Textbooks",
                    color: .elianPink
                )
            } header: {
                Text("SCHOOL")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.elianTextTertiary)
            }
            
            // MARK: - Study Hub Section
            Section {
                ForEach(folders) { folder in
                    NavigationLink(value: SidebarDestination.folder(folder)) {
                        HStack(spacing: 12) {
                            Image(systemName: folder.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(hex: folder.accentColorHex))
                                .frame(width: 32, height: 32)
                                .background(Color(hex: folder.accentColorHex).opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(folder.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.elianTextPrimary)
                                
                                Text("\(folder.notes.count) note\(folder.notes.count == 1 ? "" : "s")")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.elianTextTertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .contextMenu {
                        Button {
                            editingFolder = folder
                            newFolderName = folder.name
                            selectedColor = folder.accentColorHex
                            selectedIcon = folder.icon
                            showEditFolder = true
                        } label: {
                            Label("Edit Folder", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            deleteFolder(folder)
                        } label: {
                            Label("Delete Folder", systemImage: "trash")
                        }
                    }
                }
            } header: {
                HStack {
                    Text("STUDY HUB")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.elianTextTertiary)
                    
                    Spacer()
                    
                    Button { showAddFolder = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.elianBlue)
                    }
                }
            }
            
            // MARK: - Logineo Status
            Section {
                HStack(spacing: 8) {
                    Circle()
                        .fill(KeychainService.shared.hasLogineoCredentials ? Color.elianSuccess : Color.elianTextTertiary)
                        .frame(width: 8, height: 8)
                    
                    Text(KeychainService.shared.hasLogineoCredentials ? "Logineo Connected" : "Logineo Not Configured")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.elianTextTertiary)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color.elianBackground)
        .navigationTitle("ElianAI")
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button {
                    showSettings = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape.fill")
                        Text("Settings")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.elianTextSecondary)
                }
            }
        }
        .sheet(isPresented: $showAddFolder) {
            folderFormSheet(isEdit: false)
        }
        .sheet(isPresented: $showEditFolder) {
            folderFormSheet(isEdit: true)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
    
    // MARK: - Sidebar Item Helper
    
    private func sidebarItem(destination: SidebarDestination, icon: String, label: String, color: Color) -> some View {
        NavigationLink(value: destination) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.elianTextPrimary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Folder Form Sheet (Create & Edit)
    
    private func folderFormSheet(isEdit: Bool) -> some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Folder Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Folder Name")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.elianTextSecondary)
                    
                    TextField("e.g. Biology, Math, History", text: $newFolderName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .padding(14)
                        .background(Color.elianSurfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Color Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.elianTextSecondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(folderColors, id: \.self) { color in
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: selectedColor == color ? 2 : 0)
                                )
                                .scaleEffect(selectedColor == color ? 1.1 : 1.0)
                                .onTapGesture {
                                    withAnimation(.spring(duration: 0.2)) {
                                        selectedColor = color
                                    }
                                    HapticEngine.selection()
                                }
                        }
                    }
                }
                
                // Icon Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Icon")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.elianTextSecondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(folderIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.system(size: 20))
                                .foregroundStyle(
                                    selectedIcon == icon ? Color(hex: selectedColor) : .elianTextTertiary
                                )
                                .frame(width: 48, height: 48)
                                .background(
                                    selectedIcon == icon
                                        ? Color(hex: selectedColor).opacity(0.15)
                                        : Color.elianSurfaceSecondary
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .onTapGesture {
                                    withAnimation(.spring(duration: 0.2)) {
                                        selectedIcon = icon
                                    }
                                    HapticEngine.selection()
                                }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(24)
            .background(Color.elianBackground)
            .navigationTitle(isEdit ? "Edit Folder" : "New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAddFolder = false
                        showEditFolder = false
                        resetForm()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEdit ? "Save" : "Create") {
                        if isEdit {
                            saveEditedFolder()
                        } else {
                            createFolder()
                        }
                    }
                    .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    private func createFolder() {
        let folder = FolderModel(
            name: newFolderName.trimmingCharacters(in: .whitespaces),
            icon: selectedIcon,
            accentColorHex: selectedColor
        )
        modelContext.insert(folder)
        selectedDestination = .folder(folder)
        showAddFolder = false
        HapticEngine.notification(.success)
        resetForm()
    }
    
    private func saveEditedFolder() {
        guard let folder = editingFolder else { return }
        folder.name = newFolderName.trimmingCharacters(in: .whitespaces)
        folder.icon = selectedIcon
        folder.accentColorHex = selectedColor
        showEditFolder = false
        editingFolder = nil
        HapticEngine.notification(.success)
        resetForm()
    }
    
    private func deleteFolder(_ folder: FolderModel) {
        if case .folder(let selected) = selectedDestination, selected == folder {
            selectedDestination = nil
        }
        modelContext.delete(folder)
        HapticEngine.notification(.warning)
    }
    
    private func resetForm() {
        newFolderName = ""
        selectedColor = "#4A9EFF"
        selectedIcon = "folder.fill"
    }
}
