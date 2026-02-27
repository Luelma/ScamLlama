import Foundation
import UIKit
import Observation

/// Combined result containing both local and Reality Defender analysis.
struct PhotoAnalysisResult: Equatable {
    var localResult: PhotoDetectionResult
    var rdResult: PhotoDetectionResult?
    /// Whether RD analysis is still in progress (local finished, RD pending).
    var rdLoading: Bool = false
    /// If RD failed, a user-facing reason.
    var rdError: String? = nil

    /// The higher-risk result drives the overall verdict.
    var overallResult: PhotoDetectionResult {
        guard let rd = rdResult else { return localResult }
        let order: [RiskLevel] = [.low, .medium, .high, .critical]
        let rdIndex = order.firstIndex(of: rd.riskLevel) ?? 0
        let localIndex = order.firstIndex(of: localResult.riskLevel) ?? 0
        return rdIndex >= localIndex ? rd : localResult
    }

    static func == (lhs: PhotoAnalysisResult, rhs: PhotoAnalysisResult) -> Bool {
        lhs.localResult.status == rhs.localResult.status &&
        lhs.rdResult?.status == rhs.rdResult?.status &&
        lhs.rdLoading == rhs.rdLoading &&
        lhs.rdError == rhs.rdError
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

    private let client = RealityDefenderClient()
    private let localAnalyzer = LocalImageAnalyzer()

    func analyze(image: UIImage) async {
        // Step 1: Local on-device scan (fast, always runs first)
        state = .scanning
        let localResult = await localAnalyzer.analyze(image)
        localScanResult = localResult
        let localDetection = buildLocalOnlyResult(from: localResult)

        // Step 2: Check consent before attempting RD
        guard ConsentManager.shared.hasConsented,
              ConsentManager.shared.hasConsentedPhotoAPI else {
            let analysis = PhotoAnalysisResult(localResult: localDetection)
            state = .complete(result: analysis)
            return
        }

        // Step 3: Resolve API key — user key first, then embedded key
        let userKey = await RDKeyManager.shared.getKey()
        let apiKey = userKey ?? EmbeddedKeyProvider.rdAPIKey()

        guard !apiKey.isEmpty else {
            let analysis = PhotoAnalysisResult(localResult: localDetection)
            state = .complete(result: analysis)
            return
        }

        // Show local result immediately with RD loading indicator
        state = .complete(result: PhotoAnalysisResult(localResult: localDetection, rdLoading: true))

        // Step 4: Try Reality Defender API
        state = .uploading

        do {
            state = .analyzing
            let apiResult = try await client.analyzeImage(image, apiKey: apiKey)
            let rdDetection = PhotoDetectionResult(
                status: apiResult.status,
                score: apiResult.score,
                requestId: apiResult.requestId
            )
            let analysis = PhotoAnalysisResult(localResult: localDetection, rdResult: rdDetection)
            state = .complete(result: analysis)
        } catch {
            // RD failed — show local result + error message for RD card
            let analysis = PhotoAnalysisResult(
                localResult: localDetection,
                rdError: "Reality Defender analysis unavailable"
            )
            state = .complete(result: analysis)
        }
    }

    func reset() {
        state = .idle
        localScanResult = nil
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
