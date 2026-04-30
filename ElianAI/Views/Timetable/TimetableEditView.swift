import SwiftUI
import SwiftData

struct TimetableEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Subject.name) private var subjects: [Subject]
    
    @State private var showAddSubject = false
    @State private var editingSubject: Subject?
    @State private var subjectName = ""
    @State private var selectedColor = "#4A9EFF"
    @State private var selectedIcon = "book.fill"
    @State private var linkedCourseId: Int?
    @State private var linkedCourseName: String?
    @State private var courses: [MoodleCourse] = []
    @State private var isLoadingCourses = false
    
    private let subjectColors = [
        "#4A9EFF", "#A855F7", "#34D399", "#FB923C",
        "#F472B6", "#EF4444", "#F59E0B", "#06B6D4",
        "#8B5CF6", "#10B981", "#EC4899", "#6366F1"
    ]
    
    private let subjectIcons = [
        "book.fill", "function", "flask.fill", "globe.americas.fill",
        "paintpalette.fill", "music.note", "sportscourt.fill",
        "cpu.fill", "text.book.closed.fill", "pencil.and.ruler.fill",
        "person.3.fill", "cross.fill"
    ]
    
    var body: some View {
        NavigationStack {
            List {
                if subjects.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.elianTextTertiary)
                        Text("No subjects yet")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.elianTextSecondary)
                        Text("Add subjects to build your timetable")
                            .font(.system(size: 13))
                            .foregroundStyle(.elianTextTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(subjects) { subject in
                        HStack(spacing: 14) {
                            Image(systemName: subject.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(hex: subject.colorHex))
                                .frame(width: 36, height: 36)
                                .background(Color(hex: subject.colorHex).opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(subject.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.elianTextPrimary)
                                
                                if let courseName = subject.linkedCourseName {
                                    HStack(spacing: 4) {
                                        Image(systemName: "link")
                                            .font(.system(size: 10))
                                        Text(courseName)
                                            .font(.system(size: 12))
                                    }
                                    .foregroundStyle(.elianTextTertiary)
                                } else {
                                    Text("Not linked to Logineo")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.elianTextTertiary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(.elianTextTertiary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingSubject = subject
                            subjectName = subject.name
                            selectedColor = subject.colorHex
                            selectedIcon = subject.icon
                            linkedCourseId = subject.linkedCourseId
                            linkedCourseName = subject.linkedCourseName
                            showAddSubject = true
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                modelContext.delete(subject)
                                HapticEngine.notification(.warning)
                            } label: {
                                Label("Delete Subject", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.elianBackground)
            .navigationTitle("Subjects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        resetForm()
                        showAddSubject = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.elianBlue)
                    }
                }
            }
            .sheet(isPresented: $showAddSubject) {
                subjectFormSheet
            }
        }
    }
    
    // MARK: - Subject Form Sheet
    
    private var subjectFormSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Subject Name")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.elianTextSecondary)
                        
                        TextField("e.g. Mathematics, Biology", text: $subjectName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .padding(14)
                            .background(Color.elianSurfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Color
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.elianTextSecondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(subjectColors, id: \.self) { color in
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
                                    }
                            }
                        }
                    }
                    
                    // Icon
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icon")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.elianTextSecondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(subjectIcons, id: \.self) { icon in
                                Image(systemName: icon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(
                                        selectedIcon == icon ? Color(hex: selectedColor) : .elianTextTertiary
                                    )
                                    .frame(width: 44, height: 44)
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
                                    }
                            }
                        }
                    }
                    
                    // Logineo Course Link
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Logineo Course")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.elianTextSecondary)
                            
                            Spacer()
                            
                            if isLoadingCourses {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Button("Fetch Courses") {
                                    fetchCourses()
                                }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.elianBlue)
                            }
                        }
                        
                        if !courses.isEmpty {
                            ForEach(courses) { course in
                                Button {
                                    linkedCourseId = course.id
                                    linkedCourseName = course.displayName
                                    HapticEngine.selection()
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: linkedCourseId == course.id ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(linkedCourseId == course.id ? .elianBlue : .elianTextTertiary)
                                        
                                        Text(course.displayName)
                                            .font(.system(size: 14))
                                            .foregroundStyle(.elianTextPrimary)
                                            .lineLimit(2)
                                        
                                        Spacer()
                                    }
                                    .padding(10)
                                    .background(
                                        linkedCourseId == course.id
                                            ? Color.elianBlue.opacity(0.08)
                                            : Color.elianSurfaceSecondary
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        } else if !KeychainService.shared.hasLogineoCredentials {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.elianWarning)
                                Text("Configure Logineo in Settings first")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.elianTextTertiary)
                            }
                            .padding(10)
                        }
                    }
                }
                .padding(24)
            }
            .background(Color.elianBackground)
            .navigationTitle(editingSubject == nil ? "New Subject" : "Edit Subject")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAddSubject = false
                        resetForm()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingSubject == nil ? "Create" : "Save") {
                        saveSubject()
                    }
                    .disabled(subjectName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }
    
    // MARK: - Actions
    
    private func saveSubject() {
        let name = subjectName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        
        if let existing = editingSubject {
            existing.name = name
            existing.colorHex = selectedColor
            existing.icon = selectedIcon
            existing.linkedCourseId = linkedCourseId
            existing.linkedCourseName = linkedCourseName
        } else {
            let subject = Subject(
                name: name,
                colorHex: selectedColor,
                icon: selectedIcon,
                linkedCourseId: linkedCourseId,
                linkedCourseName: linkedCourseName
            )
            modelContext.insert(subject)
        }
        
        try? modelContext.save()
        showAddSubject = false
        resetForm()
        HapticEngine.notification(.success)
    }
    
    private func fetchCourses() {
        isLoadingCourses = true
        Task {
            do {
                let fetched = try await LogineoService.shared.fetchCourses()
                await MainActor.run {
                    courses = fetched
                    isLoadingCourses = false
                }
            } catch {
                await MainActor.run {
                    isLoadingCourses = false
                }
            }
        }
    }
    
    private func resetForm() {
        subjectName = ""
        selectedColor = "#4A9EFF"
        selectedIcon = "book.fill"
        linkedCourseId = nil
        linkedCourseName = nil
        editingSubject = nil
    }
}
