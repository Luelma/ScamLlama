import Foundation
import SwiftData

@Model
class ChecklistSession {
    var id: UUID = UUID()
    var contactName: String?
    var checkedItemIDs: [String] = []
    var riskScore: Double = 0.0
    var riskLevel: RiskLevel = RiskLevel.low
    var createdAt: Date = Date()

    init(contactName: String? = nil, checkedItemIDs: [String] = [], riskScore: Double = 0.0, riskLevel: RiskLevel = .low) {
        self.id = UUID()
        self.contactName = contactName
        self.checkedItemIDs = checkedItemIDs
        self.riskScore = riskScore
        self.riskLevel = riskLevel
        self.createdAt = Date()
    }
}
