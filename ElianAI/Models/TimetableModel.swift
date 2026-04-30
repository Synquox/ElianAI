import Foundation
import SwiftData

// MARK: - Timetable Subject

@Model
final class Subject {
    var id: UUID
    var name: String
    var colorHex: String
    var icon: String
    var linkedCourseId: Int?
    var linkedCourseName: String?
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \TimetablePeriod.subject)
    var periods: [TimetablePeriod] = []
    
    @Relationship(deleteRule: .nullify, inverse: \HomeworkEntry.subject)
    var homework: [HomeworkEntry] = []
    
    @Relationship(deleteRule: .nullify, inverse: \Textbook.subject)
    var textbooks: [Textbook] = []
    
    init(
        name: String,
        colorHex: String = "#4A9EFF",
        icon: String = "book.fill",
        linkedCourseId: Int? = nil,
        linkedCourseName: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.linkedCourseId = linkedCourseId
        self.linkedCourseName = linkedCourseName
        self.createdAt = .now
    }
}

// MARK: - Timetable Period

@Model
final class TimetablePeriod {
    var id: UUID
    var dayOfWeek: Int  // 1=Monday, 2=Tuesday, ..., 5=Friday
    var periodNumber: Int  // 1-based period index
    
    var subject: Subject?
    
    init(dayOfWeek: Int, periodNumber: Int, subject: Subject? = nil) {
        self.id = UUID()
        self.dayOfWeek = dayOfWeek
        self.periodNumber = periodNumber
        self.subject = subject
    }
}

// MARK: - Timetable Configuration

@Model
final class TimetableConfig {
    var id: UUID
    var periodsPerDay: Int
    var startHour: Int
    var startMinute: Int
    var periodDurationMinutes: Int
    
    init(
        periodsPerDay: Int = 8,
        startHour: Int = 8,
        startMinute: Int = 0,
        periodDurationMinutes: Int = 45
    ) {
        self.id = UUID()
        self.periodsPerDay = periodsPerDay
        self.startHour = startHour
        self.startMinute = startMinute
        self.periodDurationMinutes = periodDurationMinutes
    }
    
    /// Get the start time string for a given period
    func periodStartTime(_ period: Int) -> String {
        let totalMinutes = (startHour * 60 + startMinute) + (period - 1) * periodDurationMinutes
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return String(format: "%02d:%02d", h, m)
    }
}

// MARK: - Day Helper

enum Weekday: Int, CaseIterable, Identifiable {
    case monday = 1, tuesday, wednesday, thursday, friday
    
    var id: Int { rawValue }
    
    var shortName: String {
        switch self {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        }
    }
    
    var fullName: String {
        switch self {
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        }
    }
    
    /// The current weekday (1=Mon ... 5=Fri), or nil if weekend
    static var today: Weekday? {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: Date())
        // Calendar weekday: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
        let mapped = weekday - 1 // 0=Sun, 1=Mon ... 6=Sat
        return Weekday(rawValue: mapped == 0 ? 7 : mapped) // wrap Sunday
    }
}
