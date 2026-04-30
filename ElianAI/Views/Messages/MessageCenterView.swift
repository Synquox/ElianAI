import SwiftUI
import SwiftData

struct MessageCenterView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MoodleMessageEntry.timestamp, order: .reverse) private var messages: [MoodleMessageEntry]
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private var unreadCount: Int {
        messages.filter { !$0.isRead }.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading && messages.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.elianOrange)
                    Text("Loading messages...")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.elianTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if messages.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.elianOrange.opacity(0.5))
                    Text("No Messages")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.elianTextPrimary)
                    Text("Sync with Logineo to fetch your latest messages.")
                        .font(.system(size: 15))
                        .foregroundStyle(.elianTextSecondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        syncMessages()
                    } label: {
                        Text("Sync Now")
                            .elianButton(color: .elianOrange)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(messages) { message in
                        MessageRowView(message: message)
                            .onTapGesture {
                                message.isRead = true
                                try? modelContext.save()
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(message)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                if message.hasHomework {
                                    Button {
                                        convertToHomework(message)
                                    } label: {
                                        Label("Add Homework", systemImage: "plus.circle")
                                    }
                                    .tint(.elianGreen)
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.elianBackground)
        .navigationTitle("Messages")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button {
                        syncMessages()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16))
                            .foregroundStyle(.elianOrange)
                    }
                }
            }
        }
        .alert("Sync Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    // MARK: - Actions
    
    private func syncMessages() {
        guard KeychainService.shared.hasLogineoCredentials else {
            errorMessage = "Configure Logineo credentials in Settings first."
            return
        }
        
        isLoading = true
        Task {
            do {
                let scraped = try await LogineoService.shared.scrapeMessages()
                await MainActor.run {
                    for msg in scraped {
                        // Check for homework keywords
                        let keywords = ["hausaufgabe", "homework", "aufgabe", "abgabe", "deadline", "fällig", "bis morgen"]
                        let hasHW = keywords.contains { msg.content.lowercased().contains($0) }
                        
                        let entry = MoodleMessageEntry(
                            sender: msg.sender,
                            content: msg.content,
                            courseContext: msg.courseContext,
                            timestamp: msg.timestamp,
                            isRead: false,
                            hasHomework: hasHW
                        )
                        modelContext.insert(entry)
                    }
                    try? modelContext.save()
                    isLoading = false
                    HapticEngine.notification(.success)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func convertToHomework(_ message: MoodleMessageEntry) {
        let homework = HomeworkEntry(
            title: "From: \(message.sender)",
            descriptionText: message.content,
            source: .message
        )
        modelContext.insert(homework)
        message.hasHomework = false
        message.linkedHomeworkId = homework.id
        try? modelContext.save()
        HapticEngine.notification(.success)
    }
}

// MARK: - Message Row

struct MessageRowView: View {
    let message: MoodleMessageEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Unread indicator
                if !message.isRead {
                    Circle()
                        .fill(Color.elianOrange)
                        .frame(width: 8, height: 8)
                }
                
                Text(message.sender)
                    .font(.system(size: 15, weight: message.isRead ? .medium : .bold))
                    .foregroundStyle(.elianTextPrimary)
                
                Spacer()
                
                if message.hasHomework {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.elianWarning)
                }
                
                Text(message.timestamp.formatted(.relative(presentation: .named)))
                    .font(.system(size: 12))
                    .foregroundStyle(.elianTextTertiary)
            }
            
            Text(message.content)
                .font(.system(size: 14))
                .foregroundStyle(.elianTextSecondary)
                .lineLimit(3)
            
            if let context = message.courseContext, !context.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 10))
                    Text(context)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.elianBlue)
            }
        }
        .padding(.vertical, 4)
    }
}
