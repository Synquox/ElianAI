import Foundation
import SwiftSoup

/// Service for authenticating with and scraping data from Logineo (Moodle-based LMS)
@MainActor @Observable
final class LogineoService {
    static let shared = LogineoService()
    
    private(set) var isLoggedIn = false
    private(set) var isLoading = false
    private(set) var courses: [MoodleCourse] = []
    private(set) var lastSyncDate: Date?
    
    private var session: URLSession
    private var loginToken: String?
    
    private init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        session = URLSession(configuration: config)
    }
    
    var baseURL: String {
        let stored = KeychainService.shared.logineoURL
        if stored.hasPrefix("https://") { return stored }
        return "https://\(stored)"
    }
    
    // MARK: - Authentication
    
    /// Log into Logineo/Moodle using stored credentials
    func login() async throws {
        guard KeychainService.shared.hasLogineoCredentials,
              let username = KeychainService.shared.logineoUsername,
              let password = KeychainService.shared.logineoPassword else {
            throw LogineoError.noCredentials
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // Step 1: Fetch the login page to get the login token
        let loginPageURL = URL(string: "\(baseURL)/login/index.php")!
        let (loginPageData, _) = try await session.data(from: loginPageURL)
        
        guard let html = String(data: loginPageData, encoding: .utf8) else {
            throw LogineoError.parsingError("Could not read login page")
        }
        
        let doc = try SwiftSoup.parse(html)
        loginToken = try doc.select("input[name=logintoken]").first()?.val()
        
        // Step 2: POST login credentials
        var request = URLRequest(url: loginPageURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var body = "username=\(urlEncode(username))&password=\(urlEncode(password))"
        if let token = loginToken {
            body += "&logintoken=\(urlEncode(token))"
        }
        request.httpBody = body.data(using: .utf8)
        
        let (responseData, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LogineoError.networkError("Invalid response")
        }
        
        // Check if login succeeded — Moodle redirects to dashboard on success
        let responseHTML = String(data: responseData, encoding: .utf8) ?? ""
        let responseDoc = try SwiftSoup.parse(responseHTML)
        
        // If we still see a login form with error, login failed
        let errorElements = try responseDoc.select(".loginerrors, .alert-danger, #loginerrormessage")
        if !errorElements.isEmpty() {
            throw LogineoError.loginFailed
        }
        
        // Also check if we're still on the login page (login form present = not authenticated)
        let loginFormPresent = try responseDoc.select("form#login").first() != nil ||
                               (responseHTML.contains("id=\"loginbtn\"") && !responseHTML.contains("class=\"usermenu\""))
        
        if loginFormPresent {
            throw LogineoError.loginFailed
        }
        
        // Require positive proof of dashboard/authenticated page
        let isOnDashboard = httpResponse.url?.path.contains("my") == true ||
                           responseHTML.contains("data-block=\"navigation\"") ||
                           responseHTML.contains("id=\"page-my-index\"") ||
                           responseHTML.contains("class=\"usermenu\"") ||
                           responseHTML.contains("data-region=\"drawer\"") ||
                           httpResponse.statusCode == 303
        
        if isOnDashboard {
            isLoggedIn = true
        } else {
            // Fail-closed: if we can't confirm dashboard, assume login failed
            throw LogineoError.loginFailed
        }
    }
    
    /// Attempt re-login with stored credentials
    func relogin() async throws {
        isLoggedIn = false
        // Clear cookies to get a fresh session
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
        try await login()
    }
    
    // MARK: - Course Fetching
    
    /// Fetch the list of enrolled courses from Moodle
    func fetchCourses() async throws -> [MoodleCourse] {
        try await ensureLoggedIn()
        
        isLoading = true
        defer { isLoading = false }
        
        // Use the main dashboard page - modern Moodle (Logineo) lists courses here
        // often in a drawer or on the main page content.
        let url = URL(string: "\(baseURL)/my/")!
        let (data, _) = try await session.data(from: url)
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw LogineoError.parsingError("Could not read dashboard page")
        }
        
        let doc = try SwiftSoup.parse(html)
        
        var parsedCourses: [MoodleCourse] = []
        
        // Strategy 1: Look for course links in the navigation drawer or main content
        // Pattern: a[href*=/course/view.php?id=]
        let courseLinks = try doc.select("a[href*=/course/view.php?id=], a.list-group-item[href*=/course/view.php]")
        
        for link in courseLinks {
            let href = try link.attr("href")
            let name = try link.text().trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip links that don't look like course names (e.g. icons, generic labels)
            guard !name.isEmpty, name.count > 2 else { continue }
            
            guard let urlComponents = URLComponents(string: href),
                  let idParam = urlComponents.queryItems?.first(where: { $0.name == "id" }),
                  let courseId = Int(idParam.value ?? "") else {
                continue
            }
            
            // Avoid duplicates
            if !parsedCourses.contains(where: { $0.id == courseId }) {
                let course = MoodleCourse(id: courseId, fullName: name, shortName: "")
                parsedCourses.append(course)
            }
        }
        
        // Strategy 2: Check for course cards (Moodle 4.x style)
        let courseCards = try doc.select(".coursename, .multiline, .course-name")
        for card in courseCards {
            let link = try card.select("a").first() ?? card
            let href = try link.attr("href")
            let name = try card.text().trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !name.isEmpty,
                  let urlComponents = URLComponents(string: href),
                  let idParam = urlComponents.queryItems?.first(where: { $0.name == "id" }),
                  let courseId = Int(idParam.value ?? "") else {
                continue
            }
            
            if !parsedCourses.contains(where: { $0.id == courseId }) {
                let course = MoodleCourse(id: courseId, fullName: name, shortName: "")
                parsedCourses.append(course)
            }
        }
        
        courses = parsedCourses
        return parsedCourses
    }
    
    // MARK: - Course Content Fetching
    
    /// Fetch files and activities from a specific course
    func fetchCourseFiles(courseId: Int) async throws -> [MoodleFile] {
        try await ensureLoggedIn()
        
        let url = URL(string: "\(baseURL)/course/view.php?id=\(courseId)")!
        let (data, _) = try await session.data(from: url)
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw LogineoError.parsingError("Could not read course page")
        }
        
        let doc = try SwiftSoup.parse(html)
        var files: [MoodleFile] = []
        
        // Look for resource links (files)
        let resourceLinks = try doc.select("a[href*=/mod/resource], a[href*=/mod/assign], a[href*=/pluginfile.php]")
        for link in resourceLinks {
            let href = try link.attr("href")
            let name = try link.text().trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !name.isEmpty, !href.isEmpty else { continue }
            
            let fileType = detectFileType(from: name, url: href)
            let file = MoodleFile(
                name: name,
                url: href,
                fileType: fileType,
                modifiedDate: nil,
                courseId: courseId
            )
            files.append(file)
        }
        
        return files
    }
    
    // MARK: - Substitution Plan
    
    /// Find and download the Vertretungsplan PDF from a specific course
    func fetchSubstitutionPlan(courseId: Int) async throws -> Data? {
        let files = try await fetchCourseFiles(courseId: courseId)
        
        // Look for a file named "Vertretungsplan"
        guard let planFile = files.first(where: {
            $0.name.lowercased().contains("vertretungsplan")
        }) else {
            return nil
        }
        
        // Download the PDF
        guard let fileURL = URL(string: planFile.url) else {
            throw LogineoError.invalidURL
        }
        
        let (data, response) = try await session.data(from: fileURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LogineoError.networkError("Failed to download substitution plan")
        }
        
        return data
    }
    
    // MARK: - Homework Scanning
    
    /// Scan a course for new homework/assignment files — recursively enters sub-folders
    func scanForHomework(courseId: Int, courseName: String) async throws -> [HomeworkScrapeResult] {
        try await ensureLoggedIn()
        
        var visited = Set<String>()
        let courseURL = "\(baseURL)/course/view.php?id=\(courseId)"
        
        return try await scanPage(
            url: courseURL,
            courseId: courseId,
            courseName: courseName,
            visited: &visited,
            depth: 0,
            maxDepth: 3
        )
    }
    
    /// Recursively scan a page (course root or folder) for homework
    private func scanPage(
        url pageURL: String,
        courseId: Int,
        courseName: String,
        visited: inout Set<String>,
        depth: Int,
        maxDepth: Int
    ) async throws -> [HomeworkScrapeResult] {
        // Prevent loops
        guard !visited.contains(pageURL) else { return [] }
        visited.insert(pageURL)
        
        guard let url = URL(string: pageURL) else { return [] }
        let (data, _) = try await session.data(from: url)
        
        guard let html = String(data: data, encoding: .utf8) else {
            return []
        }
        
        let doc = try SwiftSoup.parse(html)
        var results: [HomeworkScrapeResult] = []
        
        // 1. Extract assignments and resources from this page
        let activities = try doc.select("li.activity.assign, li.activity.resource, li.activity.url")
        for activity in activities {
            let nameElement = try activity.select(".instancename, .aalink").first()
            let name = try nameElement?.text().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            guard !name.isEmpty else { continue }
            
            // Try to find description/content
            let descElement = try activity.select(".contentafterlink, .no-overflow").first()
            let description = try descElement?.text() ?? ""
            
            // Parse page references like "S. 45", "Seite 12", "p. 7"
            let pageRefs = parsePageReferences(from: "\(name) \(description)")
            
            // Collect attachment URLs
            var attachments: [String] = []
            let links = try activity.select("a[href*=pluginfile]")
            for link in links {
                let href = try link.attr("href")
                if !visited.contains(href) {
                    attachments.append(href)
                }
            }
            
            // Also check for direct resource links (mod/resource/view.php)
            let resourceLinks = try activity.select("a[href*=/mod/resource/view.php]")
            for link in resourceLinks {
                let href = try link.attr("href")
                if !visited.contains(href) {
                    attachments.append(href)
                }
            }
            
            let result = HomeworkScrapeResult(
                title: name,
                description: description,
                courseId: courseId,
                courseName: courseName,
                dueDate: nil,
                attachmentURLs: attachments,
                pageReferences: pageRefs
            )
            results.append(result)
        }
        
        // 2. Find and recurse into sub-folders (if not at max depth)
        if depth < maxDepth {
            let folderLinks = try doc.select("a[href*=/mod/folder/view.php]")
            for link in folderLinks {
                let href = try link.attr("href")
                guard !href.isEmpty, !visited.contains(href) else { continue }
                
                let subResults = try await scanPage(
                    url: href,
                    courseId: courseId,
                    courseName: courseName,
                    visited: &visited,
                    depth: depth + 1,
                    maxDepth: maxDepth
                )
                results.append(contentsOf: subResults)
            }
            
            // Also follow section links that lead to sub-pages
            let sectionLinks = try doc.select("a[href*=/course/view.php][href*=section]")
            for link in sectionLinks {
                let href = try link.attr("href")
                guard !href.isEmpty, !visited.contains(href) else { continue }
                
                let subResults = try await scanPage(
                    url: href,
                    courseId: courseId,
                    courseName: courseName,
                    visited: &visited,
                    depth: depth + 1,
                    maxDepth: maxDepth
                )
                results.append(contentsOf: subResults)
            }
        }
        
        return results
    }
    
    // MARK: - Message Scraping
    
    /// Scrape messages from Moodle messaging
    func scrapeMessages() async throws -> [MoodleMessage] {
        try await ensureLoggedIn()
        
        let url = URL(string: "\(baseURL)/message/index.php")!
        let (data, _) = try await session.data(from: url)
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw LogineoError.parsingError("Could not read messages page")
        }
        
        let doc = try SwiftSoup.parse(html)
        var messages: [MoodleMessage] = []
        
        // Parse message list
        let messageElements = try doc.select(".message, .notification, [data-region='message']")
        for element in messageElements {
            let sender = try element.select(".name, .message-sender, [data-region='sender-name']").first()?.text() ?? "Unknown"
            let content = try element.select(".text, .message-body, [data-region='text']").first()?.text() ?? ""
            let timeText = try element.select(".timesent, .timestamp, time").first()?.text() ?? ""
            
            guard !content.isEmpty else { continue }
            
            let message = MoodleMessage(
                sender: sender,
                content: content,
                timestamp: parseRelativeDate(timeText) ?? .now,
                courseContext: nil
            )
            messages.append(message)
        }
        
        return messages
    }
    
    // MARK: - Download File
    
    /// Download a file from Moodle using the authenticated session
    func downloadFile(url: String) async throws -> Data {
        try await ensureLoggedIn()
        
        guard let fileURL = URL(string: url) else {
            throw LogineoError.invalidURL
        }
        
        let (data, response) = try await session.data(from: fileURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LogineoError.networkError("Failed to download file")
        }
        
        return data
    }
    
    // MARK: - Helpers
    
    private func ensureLoggedIn() async throws {
        if !isLoggedIn {
            try await login()
        }
    }
    
    private func urlEncode(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }
    
    private func detectFileType(from name: String, url: String) -> String {
        let combined = "\(name.lowercased()) \(url.lowercased())"
        if combined.contains(".pdf") { return "pdf" }
        if combined.contains(".docx") || combined.contains(".doc") { return "docx" }
        if combined.contains(".pptx") || combined.contains(".ppt") { return "ppt" }
        if combined.contains(".png") || combined.contains(".jpg") || combined.contains(".jpeg") { return "image" }
        if combined.contains("/mod/assign") { return "assignment" }
        return "unknown"
    }
    
    /// Parse page references from text (e.g. "S. 45", "Seite 12", "p. 7")
    func parsePageReferences(from text: String) -> [Int] {
        var pages: [Int] = []
        
        let patterns = [
            "S\\.\\s*(\\d+)",           // S. 45
            "Seite\\s*(\\d+)",          // Seite 12
            "p\\.\\s*(\\d+)",           // p. 7
            "page\\s*(\\d+)",           // page 7
            "Aufgabe\\s*(\\d+)",        // Aufgabe 3
            "Nr\\.\\s*(\\d+)"           // Nr. 5
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                let matches = regex.matches(in: text, range: range)
                for match in matches {
                    if let numRange = Range(match.range(at: 1), in: text),
                       let num = Int(text[numRange]) {
                        pages.append(num)
                    }
                }
            }
        }
        
        return Array(Set(pages)).sorted()
    }
    
    private func parseRelativeDate(_ text: String) -> Date? {
        // Simple relative date parsing for common Moodle formats
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        
        let formats = ["dd.MM.yyyy HH:mm", "dd. MMMM yyyy, HH:mm", "yyyy-MM-dd HH:mm"]
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) {
                return date
            }
        }
        
        return nil
    }
}
