import Foundation
import UIKit

struct RealityDefenderClient {
    struct APIError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    struct DetectionResult {
        var status: String      // AUTHENTIC, FAKE, SUSPICIOUS, NOT_APPLICABLE, UNABLE_TO_EVALUATE, ANALYZING, UNKNOWN
        var score: Double?      // 0-100 ensemble score
        var requestId: String
    }

    private let baseURL = Constants.rdAPIBaseURL

    // Step 1: Get presigned URL for upload
    func getPresignedURL(fileName: String, apiKey: String) async throws -> (signedUrl: String, requestId: String) {
        let url = URL(string: "\(baseURL)/files/aws-presigned")!
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["fileName": fileName]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(message: "Invalid response from Reality Defender")
        }
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw APIError(message: "Invalid Reality Defender API key. Check your key in Settings.")
            }
            let responseBody = String(data: data, encoding: .utf8) ?? "Unknown"
            throw APIError(message: "Reality Defender error (\(httpResponse.statusCode)): \(responseBody)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // requestId is at the TOP level of the JSON response
        guard let requestId = json?["requestId"] as? String else {
            throw APIError(message: "Missing requestId in presigned URL response")
        }

        // signedUrl is nested inside response.signedUrl
        guard let responseObj = json?["response"] as? [String: Any],
              let signedUrl = responseObj["signedUrl"] as? String else {
            throw APIError(message: "Missing signedUrl in presigned URL response")
        }

        return (signedUrl, requestId)
    }

    // Step 2: Upload image data to presigned URL
    func uploadImage(data: Data, to signedUrl: String) async throws {
        try await uploadMedia(data: data, to: signedUrl, contentType: "image/jpeg")
    }

    // Step 2 (generalized): Upload any media data to presigned URL
    func uploadMedia(data: Data, to signedUrl: String, contentType: String) async throws {
        guard let url = URL(string: signedUrl) else {
            throw APIError(message: "Invalid upload URL")
        }
        var request = URLRequest(url: url, timeoutInterval: 120)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError(message: "Failed to upload media")
        }
    }

    // Step 3: Poll for results
    func getResults(requestId: String, apiKey: String) async throws -> DetectionResult {
        let url = URL(string: "\(baseURL)/media/users/\(requestId)")!
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(message: "Invalid response fetching results")
        }

        // 404 means results not ready yet
        if httpResponse.statusCode == 404 {
            return DetectionResult(status: "ANALYZING", score: nil, requestId: requestId)
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError(message: "Failed to fetch results (\(httpResponse.statusCode))")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Check resultsSummary for status
        if let resultsSummary = json?["resultsSummary"] as? [String: Any],
           let status = resultsSummary["status"] as? String {
            let metadata = resultsSummary["metadata"] as? [String: Any]
            let score = metadata?["finalScore"] as? Double
            return DetectionResult(status: status, score: score, requestId: requestId)
        }

        // No resultsSummary yet — still processing
        return DetectionResult(status: "ANALYZING", score: nil, requestId: requestId)
    }

    // Full flow: upload and poll until results are ready
    func analyzeImage(_ image: UIImage, apiKey: String) async throws -> DetectionResult {
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            throw APIError(message: "Failed to encode image")
        }

        let fileName = "lovellama_\(UUID().uuidString).jpg"

        // Step 1: Get presigned URL
        let (signedUrl, requestId) = try await getPresignedURL(fileName: fileName, apiKey: apiKey)

        // Step 2: Upload
        try await uploadImage(data: imageData, to: signedUrl)

        // Step 3: Poll for results (max 60 seconds, 3s intervals)
        let maxAttempts = 20
        for attempt in 0..<maxAttempts {
            try await Task.sleep(nanoseconds: 3_000_000_000)

            let result = try await getResults(requestId: requestId, apiKey: apiKey)

            // If status is a final result (not still processing), return it
            if result.status != "ANALYZING" && result.status != "UNKNOWN" {
                return result
            }

            // Last attempt — return whatever we have
            if attempt == maxAttempts - 1 {
                return result
            }
        }

        throw APIError(message: "Analysis timed out")
    }

    // Full flow for video: read file, upload, poll with extended timeout
    func analyzeVideo(_ videoURL: URL, apiKey: String) async throws -> DetectionResult {
        let videoData = try Data(contentsOf: videoURL)
        let ext = videoURL.pathExtension.lowercased()
        let contentType = ext == "mov" ? "video/quicktime" : "video/mp4"
        let fileName = "lovellama_\(UUID().uuidString).\(ext.isEmpty ? "mp4" : ext)"

        let (signedUrl, requestId) = try await getPresignedURL(fileName: fileName, apiKey: apiKey)
        try await uploadMedia(data: videoData, to: signedUrl, contentType: contentType)

        // Video processing takes longer — poll for up to 120 seconds (3s intervals)
        let maxAttempts = 40
        for attempt in 0..<maxAttempts {
            try await Task.sleep(nanoseconds: 3_000_000_000)
            let result = try await getResults(requestId: requestId, apiKey: apiKey)
            if result.status != "ANALYZING" && result.status != "UNKNOWN" {
                return result
            }
            if attempt == maxAttempts - 1 {
                return result
            }
        }
        throw APIError(message: "Video analysis timed out")
    }

    // Full flow for audio: read file, upload, poll with extended timeout
    func analyzeAudio(_ audioURL: URL, apiKey: String) async throws -> DetectionResult {
        let audioData = try Data(contentsOf: audioURL)
        let ext = audioURL.pathExtension.lowercased()
        let contentType: String
        switch ext {
        case "mp3": contentType = "audio/mpeg"
        case "wav": contentType = "audio/wav"
        case "m4a", "aac", "alac": contentType = "audio/mp4"
        case "ogg": contentType = "audio/ogg"
        case "flac": contentType = "audio/flac"
        default: contentType = "audio/mpeg"
        }
        let fileName = "lovellama_\(UUID().uuidString).\(ext.isEmpty ? "m4a" : ext)"

        let (signedUrl, requestId) = try await getPresignedURL(fileName: fileName, apiKey: apiKey)
        try await uploadMedia(data: audioData, to: signedUrl, contentType: contentType)

        // Audio processing — poll for up to 90 seconds (3s intervals)
        let maxAttempts = 30
        for attempt in 0..<maxAttempts {
            try await Task.sleep(nanoseconds: 3_000_000_000)
            let result = try await getResults(requestId: requestId, apiKey: apiKey)
            if result.status != "ANALYZING" && result.status != "UNKNOWN" {
                return result
            }
            if attempt == maxAttempts - 1 {
                return result
            }
        }
        throw APIError(message: "Audio analysis timed out")
    }
}
