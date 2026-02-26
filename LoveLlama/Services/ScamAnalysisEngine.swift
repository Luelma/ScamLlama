import Foundation

@Observable
class ScamAnalysisEngine {
    enum State: Equatable {
        case idle
        case scanning
        case analyzing
        case complete(AnalysisResult)
        case error(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.scanning, .scanning), (.analyzing, .analyzing):
                return true
            case (.complete(let a), .complete(let b)):
                return a.overallScore == b.overallScore
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    var state: State = .idle
    var localScanResult: LocalScanResult?

    private let scanner = LocalPatternScanner()
    private let apiClient = ClaudeAPIClient()

    func analyze(text: String, context: ConversationContext? = nil) async {
        state = .scanning

        // Step 1: Instant local scan (now produces full analysis)
        let localResult = scanner.scan(text, context: context)
        localScanResult = localResult

        // Step 2: Try API for deeper analysis (optional)
        state = .analyzing

        // Check both general and per-feature consent before sending data
        guard ConsentManager.shared.hasConsented,
              ConsentManager.shared.hasConsentedChatAPI else {
            let result = buildLocalOnlyResult(from: localResult)
            state = .complete(result)
            return
        }

        guard let apiKey = await APIKeyManager.shared.getKey() else {
            // No API key — use the enhanced local result
            let result = buildLocalOnlyResult(from: localResult)
            state = .complete(result)
            return
        }

        do {
            let apiResult = try await apiClient.analyze(text: text, apiKey: apiKey, context: context)
            state = .complete(apiResult)
        } catch {
            // Fall back to local result on API failure
            let result = buildLocalOnlyResult(from: localResult)
            state = .complete(result)
        }
    }

    func reset() {
        state = .idle
        localScanResult = nil
    }

    private func buildLocalOnlyResult(from localResult: LocalScanResult) -> AnalysisResult {
        // Use the rich per-pattern explanations from the enhanced scanner
        let patterns = localResult.flaggedPatterns.map { flagged in
            DetectedPattern(
                patternType: flagged.patternType,
                confidence: flagged.confidence,
                evidence: formatEvidence(flagged.matchedPhrases),
                explanation: flagged.explanation
            )
        }

        // Sort by weight (most dangerous first)
        let sortedPatterns = patterns.sorted { $0.patternType.weight > $1.patternType.weight }

        return AnalysisResult(
            overallScore: localResult.weightedScore,
            riskLevel: localResult.riskLevel,
            detectedPatterns: sortedPatterns,
            summary: localResult.summary,
            recommendation: localResult.recommendation,
            conversationStage: localResult.conversationStage,
            nextMovePrediction: localResult.nextMovePrediction
        )
    }

    /// Format raw regex matches into readable evidence snippets
    private func formatEvidence(_ phrases: [String]) -> String {
        let cleaned = phrases.map { phrase in
            // Strip regex syntax for display
            phrase
                .replacingOccurrences(of: "\\b", with: "")
                .replacingOccurrences(of: "\\$", with: "$")
                .replacingOccurrences(of: "\\d{2,}", with: "XX")
                .replacingOccurrences(of: "\\d+", with: "XX")
                .replacingOccurrences(of: ".*", with: "...")
                .replacingOccurrences(of: " ?", with: " ")
        }
        let unique = Array(Set(cleaned)).prefix(6)
        return "Matched: " + unique.joined(separator: ", ")
    }
}
