import Foundation

struct AnalysisResult: Codable {
    var overallScore: Double
    var riskLevel: RiskLevel
    var detectedPatterns: [DetectedPattern]
    var summary: String
    var recommendation: String
    var conversationStage: String?
}

struct DetectedPattern: Codable, Identifiable {
    var id: UUID = UUID()
    var patternType: ScamPatternType
    var confidence: Double
    var evidence: String
    var explanation: String
}
