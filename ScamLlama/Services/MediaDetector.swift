import Foundation
import Observation

struct MediaAnalysisResult: Equatable {
    var rdResult: PhotoDetectionResult
    var scamAIResult: PhotoDetectionResult?
    var scamAILoading: Bool = false
    var scamAIError: String? = nil
    var mediaType: MediaType

    /// The higher-risk result drives the overall verdict.
    var overallResult: PhotoDetectionResult {
        guard let scam = scamAIResult else { return rdResult }
        let order: [RiskLevel] = [.low, .medium, .high, .critical]
        let rdIndex = order.firstIndex(of: rdResult.riskLevel) ?? 0
        let scamIndex = order.firstIndex(of: scam.riskLevel) ?? 0
        return scamIndex >= rdIndex ? scam : rdResult
    }

    static func == (lhs: MediaAnalysisResult, rhs: MediaAnalysisResult) -> Bool {
        lhs.rdResult.status == rhs.rdResult.status &&
        lhs.scamAIResult?.status == rhs.scamAIResult?.status &&
        lhs.scamAILoading == rhs.scamAILoading &&
        lhs.scamAIError == rhs.scamAIError &&
        lhs.mediaType == rhs.mediaType
    }
}

@Observable
class MediaDetector {
    enum State: Equatable {
        case idle
        case processing       // Reading/preparing file
        case uploading        // Uploading to APIs
        case analyzing        // Waiting for API results
        case complete(result: MediaAnalysisResult)
        case error(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.processing, .processing), (.uploading, .uploading), (.analyzing, .analyzing):
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

    private let rdClient = RealityDefenderClient()
    private let scamAIClient = ScamAIClient()

    func analyzeVideo(url: URL) async {
        state = .processing

        // Validate file size
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int,
           size > MediaType.video.maxFileSize {
            state = .error("Video exceeds 250 MB limit. Please select a shorter clip.")
            return
        }

        // Resolve API keys
        let rdUserKey = await RDKeyManager.shared.getKey()
        let rdAPIKey = rdUserKey ?? EmbeddedKeyProvider.rdAPIKey()
        let scamAIAPIKey = EmbeddedKeyProvider.scamAIAPIKey()

        guard !rdAPIKey.isEmpty else {
            state = .error("No Reality Defender API key available")
            return
        }

        state = .uploading
        state = .analyzing

        // Run RD and Scam.ai in parallel
        let rdTask: Task<PhotoDetectionResult?, Never> = Task {
            do {
                let result = try await rdClient.analyzeVideo(url, apiKey: rdAPIKey)
                return PhotoDetectionResult(
                    status: result.status,
                    score: result.score,
                    requestId: result.requestId
                )
            } catch {
                return nil
            }
        }

        let scamTask: Task<(result: PhotoDetectionResult?, error: String?), Never> = Task {
            guard !scamAIAPIKey.isEmpty else { return (nil, nil) }
            do {
                let apiResult = try await scamAIClient.analyzeVideo(url, apiKey: scamAIAPIKey)
                let score = apiResult.confidenceScore * 100
                let status: String
                if apiResult.isManipulated {
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

        if let rd = rdDetection {
            state = .complete(result: MediaAnalysisResult(
                rdResult: rd,
                scamAIResult: scamResult.result,
                scamAIError: scamResult.error,
                mediaType: .video
            ))
        } else {
            state = .error("Video analysis failed")
        }
    }

    func analyzeAudio(url: URL) async {
        state = .processing

        // Validate file size
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int,
           size > MediaType.audio.maxFileSize {
            state = .error("Audio exceeds 20 MB limit. Please select a shorter clip.")
            return
        }

        // Resolve API key
        let userKey = await RDKeyManager.shared.getKey()
        let apiKey = userKey ?? EmbeddedKeyProvider.rdAPIKey()
        guard !apiKey.isEmpty else {
            state = .error("No Reality Defender API key available")
            return
        }

        state = .uploading
        do {
            state = .analyzing
            let result = try await rdClient.analyzeAudio(url, apiKey: apiKey)
            let detection = PhotoDetectionResult(
                status: result.status,
                score: result.score,
                requestId: result.requestId
            )
            state = .complete(result: MediaAnalysisResult(rdResult: detection, mediaType: .audio))
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func reset() {
        state = .idle
    }
}
