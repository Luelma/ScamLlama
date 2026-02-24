import Foundation
import UIKit
import Observation

@Observable
class AIImageDetector {
    enum State: Equatable {
        case idle
        case scanning       // Local on-device analysis
        case uploading      // Uploading to Reality Defender
        case analyzing      // Waiting for Reality Defender results
        case complete(result: PhotoDetectionResult)
        case error(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.scanning, .scanning), (.uploading, .uploading), (.analyzing, .analyzing):
                return true
            case (.complete(let a), .complete(let b)):
                return a.status == b.status
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

        // Step 2: Check both general and per-feature consent before uploading
        guard ConsentManager.shared.hasConsented,
              ConsentManager.shared.hasConsentedPhotoAPI else {
            let result = buildLocalOnlyResult(from: localResult)
            state = .complete(result: result)
            return
        }

        // Step 3: Check for Reality Defender API key
        guard let apiKey = await RDKeyManager.shared.getKey() else {
            let result = buildLocalOnlyResult(from: localResult)
            state = .complete(result: result)
            return
        }

        // Step 4: Try Reality Defender API for deeper analysis
        state = .uploading

        do {
            state = .analyzing
            let apiResult = try await client.analyzeImage(image, apiKey: apiKey)
            let detectionResult = PhotoDetectionResult(
                status: apiResult.status,
                score: apiResult.score,
                requestId: apiResult.requestId
            )
            state = .complete(result: detectionResult)
        } catch {
            // Step 5: Fall back to local result on API failure
            let result = buildLocalOnlyResult(from: localResult)
            state = .complete(result: result)
        }
    }

    func reset() {
        state = .idle
        localScanResult = nil
    }

    private func buildLocalOnlyResult(from localResult: LocalImageScanResult) -> PhotoDetectionResult {
        // Map local risk level to status strings used by PhotoDetectionResult
        let status: String
        switch localResult.riskLevel {
        case .low: status = "AUTHENTIC"
        case .medium, .high: status = "SUSPICIOUS"
        case .critical: status = "FAKE"          // Only label FAKE when evidence is very strong
        }

        return PhotoDetectionResult(
            status: status,
            score: localResult.overallScore * 100, // Convert 0-1 to 0-100
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
        case "FAKE": return "Likely AI-Generated"
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
        let base: String
        switch status {
        case "AUTHENTIC":
            base = "This image shows no signs of AI generation. It appears to be a genuine photograph."
        case "FAKE":
            base = "This image shows strong indicators of being AI-generated. Profile photos created by AI are commonly used in romance scams."
        case "SUSPICIOUS":
            base = "This image has some characteristics that may indicate AI generation or manipulation. Proceed with caution."
        case "NOT_APPLICABLE":
            base = "The image couldn't be reliably analyzed. This may happen with very small images, heavy filters, or non-photographic content."
        default:
            base = "Analysis could not be completed. Try again with a different image."
        }

        if isLocalOnly {
            return base + "\n\nThis result was produced by on-device analysis with reduced accuracy. For more reliable results, add a Reality Defender API key in Settings."
        }
        return base
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
