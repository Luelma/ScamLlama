import Foundation

class ChecklistScorer {
    let items: [ChecklistItem]

    init() {
        guard let url = Bundle.main.url(forResource: "ChecklistData", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(ChecklistData.self, from: data) else {
            self.items = []
            return
        }
        self.items = decoded.items
    }

    init(items: [ChecklistItem]) {
        self.items = items
    }

    var categories: [String] {
        let cats = Set(items.map(\.category))
        let order = ["Communication", "Emotional", "Identity", "Financial"]
        return order.filter { cats.contains($0) }
    }

    func items(for category: String) -> [ChecklistItem] {
        items.filter { $0.category == category }
    }

    func calculateScore(checkedIDs: Set<String>) -> (score: Double, riskLevel: RiskLevel) {
        guard !items.isEmpty, !checkedIDs.isEmpty else { return (0, .low) }

        let checkedItems = items.filter { checkedIDs.contains($0.id) }
        guard !checkedItems.isEmpty else { return (0, .low) }

        // 1. Base score: normalize against a realistic danger ceiling (~15 weight points)
        //    This means checking 3 high-weight items (5+5+4=14) scores ~93% instead of 19%
        let checkedWeight = checkedItems.reduce(0.0) { $0 + $1.weight }
        let maxRealistic: Double = 15.0
        let baseScore = min(checkedWeight / maxRealistic, 1.0)

        // 2. Critical item floor: any single high-weight item (≥4.0) guarantees at least medium risk
        let maxItemWeight = checkedItems.map(\.weight).max() ?? 0
        let criticalFloor: Double
        if maxItemWeight >= 5.0 {
            criticalFloor = 0.45  // Financial requests alone = high risk territory
        } else if maxItemWeight >= 4.0 {
            criticalFloor = 0.30  // Refusing video calls alone = medium risk
        } else if maxItemWeight >= 3.0 {
            criticalFloor = 0.20  // Love bombing alone = approaching medium
        } else {
            criticalFloor = 0.0
        }

        // 3. Count bonus: more checked items = more danger
        let countBonus = Double(checkedItems.count) * 0.04

        // 4. Category spread bonus: flags across multiple categories is worse
        let checkedCategories = Set(checkedItems.map(\.category))
        let categoryBonus = Double(checkedCategories.count - 1) * 0.05

        // 5. Financial combo: financial items + emotional/communication items = extra danger
        let hasFinancial = checkedItems.contains { $0.category == "Financial" }
        let hasEmotional = checkedItems.contains { $0.category == "Emotional" }
        let hasCommunication = checkedItems.contains { $0.category == "Communication" }
        let comboBonus: Double = hasFinancial && (hasEmotional || hasCommunication) ? 0.15 : 0.0

        let rawScore = max(baseScore + countBonus + categoryBonus + comboBonus, criticalFloor)
        let score = min(rawScore, 1.0)

        let riskLevel: RiskLevel
        switch score {
        case 0..<0.15: riskLevel = .low
        case 0.15..<0.40: riskLevel = .medium
        case 0.40..<0.65: riskLevel = .high
        default: riskLevel = .critical
        }

        return (score, riskLevel)
    }
}
