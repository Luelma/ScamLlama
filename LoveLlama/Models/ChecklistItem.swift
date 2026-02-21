import Foundation

struct ChecklistItem: Codable, Identifiable {
    var id: String
    var title: String
    var description: String
    var weight: Double
    var category: String
}

struct ChecklistData: Codable {
    var items: [ChecklistItem]
}
