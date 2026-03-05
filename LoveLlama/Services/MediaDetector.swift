import Foundation
import Observation

struct MediaAnalysisResult: Equatable {
    var rdResult: PhotoDetectionResult
    var mediaType: MediaType

    static func == (lhs: MediaAnalysisResult, rhs: MediaAnalysisResult) -> Bool {
        lhs.rdResult.status == rhs.rdResult.status &&
        lhs.mediaType == rhs.mediaType
    }
}

@Observable
class MediaDetector {
    enum State: Equatable {
        case idle
        case processing       // Reading/preparing file
        case uploading        // Uploading to Reality Defender
        case analyzing        // Waiting for Reality Defender results
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

    private let client = RealityDefenderClient()

    func analyzeVideo(url: URL) async {
        state = .processing

        // Validate file size
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int,
           size > MediaType.video.maxFileSize {
            state = .error("Video exceeds 250 MB limit. Please select a shorter clip.")
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
            let result = try await client.analyzeVideo(url, apiKey: apiKey)
            let detection = PhotoDetectionResult(
                status: result.status,
                score: result.score,
                requestId: result.requestId
            )
            state = .complete(result: MediaAnalysisResult(rdResult: detection, mediaType: .video))
        } catch {
            state = .error(error.localizedDescription)
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
            let result = try await client.analyzeAudio(url, apiKey: apiKey)
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
