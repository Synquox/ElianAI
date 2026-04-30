import SwiftUI
import SwiftData

struct HomeworkView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HomeworkEntry.createdAt, order: .reverse) private var allHomework: [HomeworkEntry]
    
    @State private var showAddHomework = false
    @State private var newTitle = ""
    @State private var newDescription = ""
    @State private var isSyncing = false
    @State private var syncError: String?
    @State private var filterChecked = false
    
    private var filteredHomework: [HomeworkEntry] {
        if filterChecked {
            return allHomework.filter { !$0.isCheckedOff }
        }
        return Array(allHomework)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            HStack {
                Text("\(filteredHomework.count) item\(filteredHomework.count == 1 ? "" : "s")")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.elianTextTertiary)
                
                Spacer()
                
                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        filterChecked.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: filterChecked ? "eye.slash" : "eye")
                            .font(.system(size: 12))
                        Text(filterChecked ? "Show All" : "Hide Done")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.elianBlue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            
            Divider().background(Color.elianBorder)
            
            if filteredHomework.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.elianSuccess.opacity(0.5))
                    Text("All caught up!")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.elianTextPrimary)
                    Text("No homework to do. Enjoy your free time! 🎉")
                        .font(.system(size: 15))
                        .foregroundStyle(.elianTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredHomework) { entry in
                        HomeworkRowView(entry: entry)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    modelContext.delete(entry)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.elianBackground)
        .navigationTitle("Homework")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button {
                        syncHomework()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16))
                            .foregroundStyle(.elianBlue)
                    }
                }
                
                Button {
                    showAddHomework = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.elianBlue)
                }
            }
        }
        .sheet(isPresented: $showAddHomework) {
            addHomeworkSheet
        }
        .alert("Sync Error", isPresented: Binding(
            get: { syncError != nil },
            set: { if !$0 { syncError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(syncError ?? "")
        }
    }
    
    // MARK: - Add Homework Sheet
    
    private var addHomeworkSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.elianTextSecondary)
                    
                    TextField("e.g. Worksheet page 45", text: $newTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .padding(14)
                        .background(Color.elianSurfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description (Optional)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.elianTextSecondary)
                    
                    TextEditor(text: $newDescription)
                        .font(.system(size: 15))
                        .scrollContentBackground(.hidden)
                        .padding(14)
                        .background(Color.elianSurfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .frame(minHeight: 100)
                }
                
                Spacer()
            }
            .padding(24)
            .background(Color.elianBackground)
            .navigationTitle("Add Homework")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAddHomework = false
                        newTitle = ""
                        newDescription = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addHomework()
                    }
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Actions
    
    private func addHomework() {
        let entry = HomeworkEntry(
            title: newTitle.trimmingCharacters(in: .whitespaces),
            descriptionText: newDescription.trimmingCharacters(in: .whitespaces),
            source: .manual
        )
        modelContext.insert(entry)
        try? modelContext.save()
        showAddHomework = false
        newTitle = ""
        newDescription = ""
        HapticEngine.notification(.success)
    }
    
    private func syncHomework() {
        guard KeychainService.shared.hasLogineoCredentials else {
            syncError = "Configure Logineo credentials in Settings first."
            return
        }
        
        isSyncing = true
        Task {
            await BackgroundSyncService.shared.performManualSync(modelContext: modelContext)
            await MainActor.run {
                isSyncing = false
                HapticEngine.notification(.success)
            }
        }
    }
}

// MARK: - Homework Row

struct HomeworkRowView: View {
    @Bindable var entry: HomeworkEntry
    
    @State private var showShareSheet = false
    @State private var shareFileURL: URL?
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Checkbox
            Button {
                withAnimation(.spring(duration: 0.2)) {
                    entry.isCheckedOff.toggle()
                }
                HapticEngine.selection()
            } label: {
                Image(systemName: entry.isCheckedOff ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(entry.isCheckedOff ? .elianSuccess : .elianTextTertiary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(entry.isCheckedOff ? .elianTextTertiary : .elianTextPrimary)
                    .strikethrough(entry.isCheckedOff)
                
                if !entry.descriptionText.isEmpty {
                    Text(entry.descriptionText)
                        .font(.system(size: 13))
                        .foregroundStyle(.elianTextTertiary)
                        .lineLimit(2)
                }
                
                // Attachments
                if !entry.attachments.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(entry.attachments) { attachment in
                            Button {
                                openAttachment(attachment)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: attachment.iconName)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color(hex: attachment.iconColor))
                                        .frame(width: 28, height: 28)
                                        .background(Color(hex: attachment.iconColor).opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(attachment.fileName)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.elianTextPrimary)
                                            .lineLimit(1)
                                        
                                        Text(attachment.fileData != nil ? "Tap to open" : "Download failed")
                                            .font(.system(size: 10))
                                            .foregroundStyle(attachment.fileData != nil ? .elianBlue : .elianError)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.elianTextTertiary)
                                }
                                .padding(8)
                                .background(Color.elianSurfaceSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 2)
                }
                
                HStack(spacing: 8) {
                    // Source badge
                    HStack(spacing: 3) {
                        Image(systemName: entry.source == .auto ? "antenna.radiowaves.left.and.right" : "hand.raised.fill")
                            .font(.system(size: 9))
                        Text(entry.source == .auto ? "Auto" : entry.source == .message ? "Message" : "Manual")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(entry.source == .auto ? .elianBlue : .elianTextTertiary)
                    
                    // Attachment count badge
                    if !entry.attachments.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "paperclip")
                                .font(.system(size: 9))
                            Text("\(entry.attachments.count) file\(entry.attachments.count == 1 ? "" : "s")")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.elianPurple)
                    }
                    
                    // Page refs
                    if !entry.pageReferences.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "book.pages")
                                .font(.system(size: 9))
                            Text("S. \(entry.pageReferences.map { String($0) }.joined(separator: ", "))")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.elianOrange)
                    }
                    
                    Spacer()
                    
                    Text(entry.createdAt.formatted(.relative(presentation: .named)))
                        .font(.system(size: 11))
                        .foregroundStyle(.elianTextTertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(entry.isCheckedOff ? 0.6 : 1.0)
        .sheet(isPresented: $showShareSheet) {
            if let url = shareFileURL {
                ShareSheet(activityItems: [url])
            }
        }
    }
    
    private func openAttachment(_ attachment: HomeworkAttachment) {
        guard let data = attachment.fileData else { return }
        
        // Write to temp file and open via share sheet
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(attachment.fileName)
        
        do {
            try data.write(to: fileURL)
            shareFileURL = fileURL
            showShareSheet = true
        } catch {
            print("Failed to write attachment: \(error)")
        }
    }
}

// MARK: - Share Sheet (UIKit wrapper)

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
