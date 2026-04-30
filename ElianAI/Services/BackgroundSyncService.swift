import Foundation
import SwiftData
import BackgroundTasks
import UserNotifications

/// Manages background sync for homework scanning and message checking
final class BackgroundSyncService {
    static let shared = BackgroundSyncService()
    static let syncTaskIdentifier = "com.synquox.ElianAI.homework-sync"
    
    private init() {}
    
    // MARK: - Registration
    
    /// Register background task with the system — call from app init
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.syncTaskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundSync(task: task as! BGAppRefreshTask)
        }
    }
    
    /// Schedule the next background sync
    func scheduleSync() {
        let request = BGAppRefreshTaskRequest(identifier: Self.syncTaskIdentifier)
        
        // Target 18:00 today/tomorrow
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 18
        components.minute = 0
        
        if let targetDate = calendar.date(from: components) {
            if targetDate > Date() {
                request.earliestBeginDate = targetDate
            } else {
                // Already past 18:00 today, schedule for tomorrow
                request.earliestBeginDate = calendar.date(byAdding: .day, value: 1, to: targetDate)
            }
        } else {
            request.earliestBeginDate = Date(timeIntervalSinceNow: 3600)
        }
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule background sync: \(error)")
        }
    }
    
    // MARK: - Background Task Handler
    
    private func handleBackgroundSync(task: BGAppRefreshTask) {
        // Schedule the next sync immediately
        scheduleSync()
        
        let syncTask = Task {
            // Create a dedicated ModelContext for background work
            let container = try? ModelContainer(for:
                FolderModel.self, NoteModel.self, QuizQuestion.self,
                QuizAttempt.self, Flashcard.self, ChatMessage.self,
                Subject.self, TimetablePeriod.self, TimetableConfig.self,
                HomeworkEntry.self, HomeworkAttachment.self,
                SeenCourseFile.self, Textbook.self, MoodleMessageEntry.self
            )
            let context = container.map { ModelContext($0) }
            await performSync(modelContext: context)
        }
        
        task.expirationHandler = {
            syncTask.cancel()
        }
        
        Task {
            _ = try? await syncTask.value
            task.setTaskCompleted(success: true)
        }
    }
    
    // MARK: - Manual Sync
    
    /// Perform sync on-demand (called from UI "Sync Now" button)
    @MainActor
    func performManualSync(modelContext: ModelContext) async {
        await performSync(modelContext: modelContext)
    }
    
    // MARK: - Core Sync Logic
    
    /// The main sync routine: scan today's + yesterday's subjects for homework
    private func performSync(modelContext: ModelContext? = nil) async {
        let logineo = LogineoService.shared
        
        guard KeychainService.shared.hasLogineoCredentials else { return }
        
        do {
            try await logineo.login()
        } catch {
            print("Background sync login failed: \(error)")
            return
        }
        
        do {
            let courses = try await logineo.fetchCourses()
            var newHomeworkCount = 0
            var newAttachmentCount = 0
            
            for course in courses {
                let homeworkResults = try await logineo.scanForHomework(
                    courseId: course.id,
                    courseName: course.fullName
                )
                
                // Load previously seen URLs for this course
                var seenURLs = Set<String>()
                if let ctx = modelContext {
                    let cid = course.id
                    let descriptor = FetchDescriptor<SeenCourseFile>(
                        predicate: #Predicate { $0.courseId == cid }
                    )
                    let seen = (try? ctx.fetch(descriptor)) ?? []
                    seenURLs = Set(seen.map { $0.url })
                }
                
                for item in homeworkResults {
                    // Collect all URLs for this homework (title URL + attachment URLs)
                    let itemURLs = item.attachmentURLs
                    
                    // Skip entirely if ALL attachment URLs were already seen
                    if !itemURLs.isEmpty && itemURLs.allSatisfy({ seenURLs.contains($0) }) {
                        continue
                    }
                    
                    // Also skip if title was already processed (fallback for items without attachments)
                    if itemURLs.isEmpty {
                        if let ctx = modelContext {
                            let title = item.title
                            let descriptor = FetchDescriptor<HomeworkEntry>(
                                predicate: #Predicate { $0.title == title }
                            )
                            let existing = (try? ctx.fetch(descriptor)) ?? []
                            if !existing.isEmpty { continue }
                        }
                    }
                    
                    // Determine if attachments are worksheets (non-book files)
                    let isBookReference = !item.pageReferences.isEmpty && item.attachmentURLs.isEmpty
                    
                    // Create the homework entry
                    let entry = HomeworkEntry(
                        title: item.title,
                        descriptionText: item.description,
                        source: .auto,
                        dueDate: item.dueDate,
                        pageReferences: item.pageReferences,
                        attachmentURLs: item.attachmentURLs
                    )
                    modelContext?.insert(entry)
                    newHomeworkCount += 1
                    
                    // Auto-download non-book attachments (worksheets, PDFs, etc.)
                    if !isBookReference {
                        for urlString in item.attachmentURLs where !seenURLs.contains(urlString) {
                            do {
                                let fileData = try await logineo.downloadFile(url: urlString)
                                let fileName = Self.extractFileName(from: urlString)
                                let fileType = Self.detectFileType(from: fileName, url: urlString)
                                
                                let attachment = HomeworkAttachment(
                                    fileName: fileName,
                                    fileType: fileType,
                                    fileData: fileData,
                                    sourceURL: urlString
                                )
                                attachment.homework = entry
                                modelContext?.insert(attachment)
                                newAttachmentCount += 1
                            } catch {
                                print("Failed to download attachment \(urlString): \(error)")
                                let attachment = HomeworkAttachment(
                                    fileName: Self.extractFileName(from: urlString),
                                    fileType: Self.detectFileType(from: "", url: urlString),
                                    fileData: nil,
                                    sourceURL: urlString
                                )
                                attachment.homework = entry
                                modelContext?.insert(attachment)
                            }
                        }
                    }
                    
                    // Mark all URLs as seen
                    for urlString in item.attachmentURLs where !seenURLs.contains(urlString) {
                        let seen = SeenCourseFile(url: urlString, courseId: course.id)
                        modelContext?.insert(seen)
                        seenURLs.insert(urlString)
                    }
                }
            }
            
            // Also scrape messages and auto-convert homework mentions
            let messages = try await logineo.scrapeMessages()
            let homeworkKeywords = ["hausaufgabe", "homework", "aufgabe", "abgabe", "deadline", "fällig"]
            
            for msg in messages {
                let hasHomework = homeworkKeywords.contains { msg.content.lowercased().contains($0) }
                
                if hasHomework {
                    // Deduplicate
                    if let ctx = modelContext {
                        let content = msg.content
                        let descriptor = FetchDescriptor<HomeworkEntry>(
                            predicate: #Predicate { $0.descriptionText == content }
                        )
                        let existing = (try? ctx.fetch(descriptor)) ?? []
                        if !existing.isEmpty { continue }
                    }
                    
                    let entry = HomeworkEntry(
                        title: "📩 \(msg.sender): Homework",
                        descriptionText: msg.content,
                        source: .message
                    )
                    modelContext?.insert(entry)
                    newHomeworkCount += 1
                }
            }
            
            try? modelContext?.save()
            
            // Notify user if new homework was found
            if newHomeworkCount > 0 {
                sendNewHomeworkNotification(count: newHomeworkCount, attachments: newAttachmentCount)
            }
            
        } catch {
            print("Background sync failed: \(error)")
        }
    }
    
    // MARK: - File Helpers
    
    /// Extract a readable filename from a URL
    private static func extractFileName(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return "Attachment" }
        let lastComponent = url.lastPathComponent
            .removingPercentEncoding ?? url.lastPathComponent
        return lastComponent.isEmpty ? "Attachment" : lastComponent
    }
    
    /// Detect file type from name and URL
    private static func detectFileType(from name: String, url: String) -> String {
        let combined = "\(name.lowercased()) \(url.lowercased())"
        if combined.contains(".pdf") { return "pdf" }
        if combined.contains(".docx") || combined.contains(".doc") { return "docx" }
        if combined.contains(".pptx") || combined.contains(".ppt") { return "ppt" }
        if combined.contains(".png") || combined.contains(".jpg") || combined.contains(".jpeg") { return "image" }
        if combined.contains(".xlsx") || combined.contains(".xls") { return "spreadsheet" }
        return "unknown"
    }
    
    private func sendNewHomeworkNotification(count: Int, attachments: Int) {
        let content = UNMutableNotificationContent()
        content.title = "ElianAI — New Homework Found"
        
        var body = "\(count) new homework item\(count == 1 ? "" : "s") detected from Logineo."
        if attachments > 0 {
            body += " \(attachments) worksheet\(attachments == 1 ? "" : "s") auto-downloaded."
        }
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "new-homework-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Notifications
    
    /// Schedule a local notification for missing homework
    func scheduleMissingHomeworkAlert(subjectName: String, nextLessonDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Missing Homework"
        content.body = "No homework found for \(subjectName). Your next lesson is tomorrow — please check manually."
        content.sound = .default
        
        // Schedule for one day before the lesson
        let calendar = Calendar.current
        guard let alertDate = calendar.date(byAdding: .day, value: -1, to: nextLessonDate) else { return }
        
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: alertDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "missing-homework-\(subjectName)-\(nextLessonDate.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    /// Request notification permissions
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
}
