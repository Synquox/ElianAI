import Foundation
import SwiftData

@Model
final class FolderModel {
    var id: UUID
    var name: String
    var icon: String
    var accentColorHex: String
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \NoteModel.folder)
    var notes: [NoteModel] = []
    
    init(
        name: String,
        icon: String = "folder.fill",
        accentColorHex: String = "#007AFF",
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.accentColorHex = accentColorHex
        self.createdAt = createdAt
    }
}
