import Foundation
import SwiftData

/// Tracks URLs that have already been processed during sync to prevent duplicate homework entries.
/// Persisted across app launches so re-syncs skip previously seen files.
@Model
final class SeenCourseFile {
    var url: String
    var courseId: Int
    var firstSeenAt: Date
    
    init(url: String, courseId: Int) {
        self.url = url
        self.courseId = courseId
        self.firstSeenAt = .now
    }
}
