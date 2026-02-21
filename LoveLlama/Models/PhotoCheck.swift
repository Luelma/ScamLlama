import Foundation
import SwiftData

@Model
class PhotoCheck {
    var id: UUID = UUID()
    var imageData: Data?
    var detectionStatus: String?  // AUTHENTIC, FAKE, SUSPICIOUS, NOT_APPLICABLE, UNABLE_TO_EVALUATE
    var aiScore: Double?          // 0-100 ensemble score from Reality Defender
    var requestId: String?        // Reality Defender request ID for polling
    var isLocalOnly: Bool = false  // Whether result came from on-device analysis only
    var createdAt: Date = Date()

    var isAIGenerated: Bool? {
        guard let status = detectionStatus else { return nil }
        return status == "FAKE"
    }

    var isSuspicious: Bool {
        detectionStatus == "SUSPICIOUS" || detectionStatus == "FAKE"
    }

    var statusLabel: String {
        switch detectionStatus {
        case "AUTHENTIC": return "Likely Real"
        case "FAKE": return "Likely AI-Generated"
        case "SUSPICIOUS": return "Suspicious"
        case "NOT_APPLICABLE": return "Unable to Determine"
        case "UNABLE_TO_EVALUATE": return "Analysis Failed"
        default: return "Pending"
        }
    }

    var riskLevel: RiskLevel {
        switch detectionStatus {
        case "AUTHENTIC": return .low
        case "SUSPICIOUS": return .medium
        case "FAKE": return .critical
        default: return .medium
        }
    }

    init(imageData: Data? = nil) {
        self.id = UUID()
        self.imageData = imageData
        self.createdAt = Date()
    }
}
