import Foundation
import UIKit
import Observation

/// Combined result containing local, Reality Defender, and Scam.ai analysis.
struct PhotoAnalysisResult: Equatable {
    var localResult: PhotoDetectionResult
    var rdResult: PhotoDetectionResult?
    var scamAIResult: PhotoDetectionResult?
    /// Whether RD analysis is still in progress (local finished, RD pending).
    var rdLoading: Bool = false
    /// Whether Scam.ai analysis is still in progress.
    var scamAILoading: Bool = false
    /// If RD failed, a user-facing reason.
    var rdError: String? = nil
    /// If Scam.ai failed, a user-facing reason.
    var scamAIError: String? = nil

    /// The higher-risk result drives the overall verdict.
    var overallResult: PhotoDetectionResult {
        let order: [RiskLevel] = [.low, .medium, .high, .critical]
        var best = localResult
        var bestIndex = order.firstIndex(of: best.riskLevel) ?? 0

        if let rd = rdResult {
            let rdIndex = order.firstIndex(of: rd.riskLevel) ?? 0
            if rdIndex >= bestIndex { best = rd; bestIndex = rdIndex }
        }
        if let scam = scamAIResult {
            let scamIndex = order.firstIndex(of: scam.riskLevel) ?? 0
            if scamIndex >= bestIndex { best = scam; bestIndex = scamIndex }
        }
        return best
    }

    static func == (lhs: PhotoAnalysisResult, rhs: PhotoAnalysisResult) -> Bool {
        lhs.localResult.status == rhs.localResult.status &&
        lhs.rdResult?.status == rhs.rdResult?.status &&
        lhs.scamAIResult?.status == rhs.scamAIResult?.status &&
        lhs.rdLoading == rhs.rdLoading &&
        lhs.scamAILoading == rhs.scamAILoading &&
        lhs.rdError == rhs.rdError &&
        lhs.scamAIError == rhs.scamAIError
    }
}

@Observable
class AIImageDetector {
    enum State: Equatable {
        case idle
        case scanning       // Local on-device analysis
        case uploading      // Uploading to Reality Defender
        case analyzing      // Waiting for Reality Defender results
        case complete(result: PhotoAnalysisResult)
        case error(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.scanning, .scanning), (.uploading, .uploading), (.analyzing, .analyzing):
                return true
            case (.complete(let a), .complete(let b)):
                return a == b
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    var state: State = .idle
    var localScanResult: LocalImageScanResult?

    private let rdClient = RealityDefenderClient()
    private let scamAIClient = ScamAIClient()
    private let localAnalyzer = LocalImageAnalyzer()

    func analyze(image: UIImage) async {
        // Step 1: Local on-device scan (fast, always runs first)
        state = .scanning
        let localResult = await localAnalyzer.analyze(image)
        localScanResult = localResult
        let localDetection = buildLocalOnlyResult(from: localResult)

        // Step 2: Check consent before attempting cloud APIs
        guard ConsentManager.shared.hasConsented,
              ConsentManager.shared.hasConsentedPhotoAPI else {
            let analysis = PhotoAnalysisResult(localResult: localDetection)
            state = .complete(result: analysis)
            return
        }

        // Step 3: Resolve API keys
        let rdUserKey = await RDKeyManager.shared.getKey()
        let rdAPIKey = rdUserKey ?? EmbeddedKeyProvider.rdAPIKey()
        let scamAIAPIKey = EmbeddedKeyProvider.scamAIAPIKey()

        let hasRD = !rdAPIKey.isEmpty
        let hasScamAI = !scamAIAPIKey.isEmpty

        guard hasRD || hasScamAI else {
            let analysis = PhotoAnalysisResult(localResult: localDetection)
            state = .complete(result: analysis)
            return
        }

        // Show local result immediately with cloud loading indicators
        state = .complete(result: PhotoAnalysisResult(
            localResult: localDetection,
            rdLoading: hasRD,
            scamAILoading: hasScamAI
        ))

        // Step 4: Run cloud APIs in parallel
        state = .analyzing

        // Reality Defender task
        let rdTask: Task<PhotoDetectionResult?, Never> = Task {
            guard hasRD else { return nil }
            do {
                let apiResult = try await rdClient.analyzeImage(image, apiKey: rdAPIKey)
                return PhotoDetectionResult(
                    status: apiResult.status,
                    score: apiResult.score,
                    requestId: apiResult.requestId
                )
            } catch {
                return nil
            }
        }

        // Scam.ai task
        let scamTask: Task<(result: PhotoDetectionResult?, error: String?), Never> = Task {
            guard hasScamAI else { return (nil, nil) }
            do {
                let apiResult = try await scamAIClient.analyzeImage(image, apiKey: scamAIAPIKey)
                let score = apiResult.confidenceScore * 100  // normalize to 0-100
                let status: String
                if apiResult.likelyAIGenerated {
                    status = score >= 75 ? "FAKE" : "SUSPICIOUS"
                } else {
                    status = score >= 50 ? "SUSPICIOUS" : "AUTHENTIC"
                }
                return (PhotoDetectionResult(
                    status: status,
                    score: score,
                    requestId: ""
                ), nil)
            } catch {
                return (nil, "Scam.ai analysis unavailable")
            }
        }

        let rdDetection = await rdTask.value
        let scamResult = await scamTask.value

        // Adjust local result to incorporate RD findings if available
        var adjustedLocal = localDetection
        if let rd = rdDetection {
            adjustedLocal = adjustLocalResult(localDetection, localScan: localResult, rdResult: rd)
        }

        let analysis = PhotoAnalysisResult(
            localResult: adjustedLocal,
            rdResult: rdDetection,
            scamAIResult: scamResult.result,
            rdError: rdDetection == nil && hasRD ? "Reality Defender analysis unavailable" : nil,
            scamAIError: scamResult.error
        )
        state = .complete(result: analysis)
    }

    func reset() {
        state = .idle
        localScanResult = nil
    }

    /// Blend Reality Defender score into the local result so the two cards don't wildly contradict.
    /// RD score (0-100) is treated as an authoritative signal that pulls the local score toward it.
    private func adjustLocalResult(_ local: PhotoDetectionResult, localScan: LocalImageScanResult, rdResult: PhotoDetectionResult) -> PhotoDetectionResult {
        guard let rdScore = rdResult.score else { return local }

        let localScore = localScan.overallScore  // 0.0 - 1.0
        let rdNormalized = rdScore / 100.0       // normalize to 0.0 - 1.0

        // Weighted blend: RD carries 60% weight since it's a purpose-built deepfake detector
        let blendedScore = localScore * 0.4 + rdNormalized * 0.6
        let clampedScore = min(1.0, max(0.0, blendedScore))

        // Derive status from blended score using the same thresholds as LocalImageAnalyzer
        let status: String
        switch clampedScore {
        case ..<0.25: status = "AUTHENTIC"
        case 0.25..<0.50: status = "SUSPICIOUS"
        case 0.50..<0.75: status = "SUSPICIOUS"
        default: status = "FAKE"
        }

        // Append a note to the flags explaining the adjustment
        var flags = local.suspicionFlags ?? []
        if abs(rdNormalized - localScore) > 0.3 {
            flags.append("Score adjusted using Reality Defender analysis")
        }

        return PhotoDetectionResult(
            status: status,
            score: clampedScore * 100,
            requestId: local.requestId,
            isLocalOnly: false,
            suspicionFlags: flags
        )
    }

    private func buildLocalOnlyResult(from localResult: LocalImageScanResult) -> PhotoDetectionResult {
        let status: String
        switch localResult.riskLevel {
        case .low: status = "AUTHENTIC"
        case .medium, .high: status = "SUSPICIOUS"
        case .critical: status = "FAKE"
        }

        return PhotoDetectionResult(
            status: status,
            score: localResult.overallScore * 100,
            requestId: "",
            isLocalOnly: true,
            suspicionFlags: localResult.suspicionFlags.map { $0.finding }
        )
    }
}

struct PhotoDetectionResult: Equatable {
    var status: String
    var score: Double?
    var requestId: String
    var isLocalOnly: Bool = false
    var suspicionFlags: [String]? = nil

    var statusLabel: String {
        switch status {
        case "AUTHENTIC": return "Likely Real"
        case "FAKE": return "Likely AI-Generated or Manipulated"
        case "SUSPICIOUS": return "Suspicious"
        case "NOT_APPLICABLE": return "Unable to Determine"
        case "UNABLE_TO_EVALUATE": return "Analysis Failed"
        default: return "Unknown"
        }
    }

    var riskLevel: RiskLevel {
        switch status {
        case "AUTHENTIC": return .low
        case "SUSPICIOUS": return .medium
        case "FAKE": return .critical
        default: return .medium
        }
    }

    var explanation: String {
        switch status {
        case "AUTHENTIC":
            return "This image shows no signs of AI generation or manipulation. It appears to be a genuine photograph."
        case "FAKE":
            return "This image shows strong indicators of being AI-generated or manipulated. Fake or composited profile photos are commonly used in romance scams."
        case "SUSPICIOUS":
            return "This image has some characteristics that may indicate AI generation or photo manipulation. Proceed with caution."
        case "NOT_APPLICABLE":
            return "The image couldn't be reliably analyzed. This may happen with very small images, heavy filters, or non-photographic content."
        default:
            return "Analysis could not be completed. Try again with a different image."
        }
    }
}

// Separate key manager for Reality Defender (same pattern as APIKeyManager)
actor RDKeyManager {
    static let shared = RDKeyManager()

    private let service = Constants.rdAPIKeyKeychainKey

    func saveKey(_ key: String) throws {
        let data = Data(key.utf8)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func getKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }

    func hasKey() -> Bool {
        getKey() != nil
    }
}
