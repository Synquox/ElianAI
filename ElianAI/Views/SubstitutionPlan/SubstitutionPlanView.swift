import SwiftUI
import PDFKit

struct SubstitutionPlanView: View {
    @State private var pdfData: Data?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedCourseId: Int?
    @State private var courses: [MoodleCourse] = []
    @State private var showCoursePicker = false
    @State private var showSettings = false
    
    // Stored course selection
    @AppStorage("substitutionPlanCourseId") private var savedCourseId: Int = 0
    @AppStorage("substitutionPlanCourseName") private var savedCourseName: String = ""
    @AppStorage("substitutionPlanFileURL") private var savedFileURL: String = ""
    @AppStorage("substitutionPlanFileName") private var savedFileName: String = ""
    
    @State private var courseFiles: [MoodleFile] = []
    @State private var isFetchingFiles = false
    @State private var showFilePickerSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            if savedCourseId == 0 {
                // No course configured
                setupView
            } else if isLoading {
                loadingView
            } else if let data = pdfData {
                PDFViewWrapper(data: data)
            } else if let error = errorMessage {
                errorView(error)
            } else {
                emptyView
            }
        }
        .background(Color.elianBackground)
        .navigationTitle("Vertretungsplan")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showCoursePicker = true
                } label: {
                    Image(systemName: "gear")
                        .font(.system(size: 16))
                        .foregroundStyle(.elianTextSecondary)
                }
                
                Button {
                    loadPlan()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16))
                        .foregroundStyle(.elianBlue)
                }
                .disabled(savedFileURL.isEmpty)
            }
        }
        .sheet(isPresented: $showCoursePicker) {
            coursePickerSheet
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            if savedCourseId != 0 && pdfData == nil {
                loadPlan()
            }
        }
    }
    
    // MARK: - Views
    
    private var setupView: some View {
        VStack(spacing: 20) {
            if !KeychainService.shared.hasLogineoCredentials {
                // No Logineo configured at all
                Image(systemName: "network.slash")
                    .font(.system(size: 48))
                    .foregroundStyle(.elianOrange.opacity(0.5))
                
                Text("Logineo Not Connected")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.elianTextPrimary)
                
                Text("You need to connect your Logineo account first to access the substitution plan.")
                    .font(.system(size: 15))
                    .foregroundStyle(.elianTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                
                Button {
                    showSettings = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gear")
                        Text("Open Settings")
                    }
                    .elianButton(color: .elianOrange)
                }
            } else {
                // Logineo connected but no course selected
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundStyle(.elianPurple.opacity(0.5))
                
                Text("No Course Selected")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.elianTextPrimary)
                
                Text("Select the Logineo course that contains your substitution plan (Vertretungsplan).")
                    .font(.system(size: 15))
                    .foregroundStyle(.elianTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                
                Button {
                    showCoursePicker = true
                } label: {
                    Text("Select Course")
                        .elianButton(color: .elianPurple)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.elianPurple)
            Text("Loading Vertretungsplan...")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.elianTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 48))
                .foregroundStyle(.elianTextTertiary)
            Text("Kein Plan gefunden")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.elianTextSecondary)
            Text("Bitte wähle in den Einstellungen einen Kurs und eine Datei aus.")
                .font(.system(size: 14))
                .foregroundStyle(.elianTextTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
            
            Button {
                showCoursePicker = true
            } label: {
                Text("Datei auswählen")
                    .elianButton(color: .elianBlue)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.elianWarning)
            Text("Error Loading Plan")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.elianTextPrimary)
            Text(error)
                .font(.system(size: 14))
                .foregroundStyle(.elianTextSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                loadPlan()
            } label: {
                Text("Retry")
                    .elianOutlineButton(color: .elianBlue)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Course Picker
    
    private var coursePickerSheet: some View {
        NavigationStack {
            VStack {
                if courses.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Fetching courses...")
                            .font(.system(size: 14))
                            .foregroundStyle(.elianTextSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear { fetchCourses() }
                } else {
                    List(courses) { course in
                        Button {
                            selectCourse(course)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(course.displayName)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.elianTextPrimary)
                                }
                                Spacer()
                                if savedCourseId == course.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.elianBlue)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.elianBackground)
            .navigationTitle("Select Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCoursePicker = false }
                }
            }
        }
        .presentationDetents([.medium])
        .sheet(isPresented: $showFilePickerSheet) {
            filePickerSheet
        }
    }
    
    private var filePickerSheet: some View {
        NavigationStack {
            VStack {
                if isFetchingFiles {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Dateien werden geladen...")
                    }
                } else {
                    List(courseFiles) { file in
                        Button {
                            savedFileURL = file.url
                            savedFileName = file.name
                            showFilePickerSheet = false
                            loadPlan()
                        } label: {
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundStyle(.elianBlue)
                                Text(file.name)
                                    .font(.system(size: 14))
                                Spacer()
                                if savedFileURL == file.url {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.elianBlue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Datei auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { showFilePickerSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Actions
    
    private func loadPlan() {
        guard !savedFileURL.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let data = try await LogineoService.shared.downloadFile(url: savedFileURL)
                await MainActor.run {
                    pdfData = data
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func selectCourse(_ course: MoodleCourse) {
        savedCourseId = course.id
        savedCourseName = course.displayName
        showCoursePicker = false
        
        // Now fetch files for this course
        fetchFiles(for: course.id)
    }
    
    private func fetchFiles(for courseId: Int) {
        isFetchingFiles = true
        showFilePickerSheet = true
        Task {
            do {
                let files = try await LogineoService.shared.fetchCourseFiles(courseId: courseId)
                await MainActor.run {
                    courseFiles = files
                    isFetchingFiles = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isFetchingFiles = false
                }
            }
        }
    }
    
    private func fetchCourses() {
        Task {
            do {
                let fetched = try await LogineoService.shared.fetchCourses()
                await MainActor.run {
                    courses = fetched
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - PDF View Wrapper

struct PDFViewWrapper: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor(Color.elianBackground)
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        pdfView.document = PDFDocument(data: data)
    }
}
