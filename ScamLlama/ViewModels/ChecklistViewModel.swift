import Foundation
import SwiftData
import Observation

@Observable
class ChecklistViewModel {
    let scorer: ChecklistScorer
    var contactName: String = ""
    var checkedIDs: Set<String> = []
    var score: Double = 0.0
    var riskLevel: RiskLevel = .low
    var showingResult = false

    var items: [ChecklistItem] { scorer.items }
    var categories: [String] { scorer.categories }
    var checkedCount: Int { checkedIDs.count }

    init(scorer: ChecklistScorer = ChecklistScorer()) {
        self.scorer = scorer
    }

    func items(for category: String) -> [ChecklistItem] {
        scorer.items(for: category)
    }

    func isChecked(_ id: String) -> Bool {
        checkedIDs.contains(id)
    }

    func toggle(_ id: String) {
        if checkedIDs.contains(id) {
            checkedIDs.remove(id)
        } else {
            checkedIDs.insert(id)
        }
        recalculate()
    }

    func recalculate() {
        let result = scorer.calculateScore(checkedIDs: checkedIDs)
        score = result.score
        riskLevel = result.riskLevel
    }

    func checkedItems() -> [ChecklistItem] {
        items.filter { checkedIDs.contains($0.id) }
    }

    func saveSession(modelContext: ModelContext) {
        let session = ChecklistSession(
            contactName: contactName.isEmpty ? nil : contactName,
            checkedItemIDs: Array(checkedIDs),
            riskScore: score,
            riskLevel: riskLevel
        )
        modelContext.insert(session)
    }

    func reset() {
        contactName = ""
        checkedIDs = []
        score = 0.0
        riskLevel = .low
        showingResult = false
    }
}
