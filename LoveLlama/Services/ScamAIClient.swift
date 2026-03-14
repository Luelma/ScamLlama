import Foundation
import UIKit

struct ScamAIClient {
    struct APIError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    struct DetectionResult {
        var likelyAIGenerated: Bool
        var confidenceScore: Double   // 0.0 - 1.0
        var processingTimeMs: Double?
    }

    struct VideoDetectionResult {
        var isManipulated: Bool
        var confidenceScore: Double   // 0.0 - 1.0
        var processingTimeMs: Double?
        var detectionTypes: [String]
    }

    private let baseURL = Constants.scamAIAPIBaseURL

    /// Analyze an image for AI generation using the Scam.ai detect-file endpoint.
    func analyzeImage(_ image: UIImage, apiKey: String) async throws -> DetectionResult {
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            throw APIError(message: "Failed to encode image")
        }

        guard imageData.count <= 10_000_000 else {
            throw APIError(message: "Image exceeds Scam.ai 10 MB limit")
        }

        let url = URL(string: "\(baseURL)/detect-file")!
        let boundary = UUID().uuidString

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Build multipart body
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(message: "Invalid response from Scam.ai")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw APIError(message: "Invalid Scam.ai API key")
            }
            let responseBody = String(data: data, encoding: .utf8) ?? "Unknown"
            throw APIError(message: "Scam.ai error (\(httpResponse.statusCode)): \(responseBody)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Response nests results under result.payload; top-level shortcuts also available
        let resultObj = json?["result"] as? [String: Any]
        let payload = resultObj?["payload"] as? [String: Any]

        if let payload,
           let likelyAI = payload["likely_ai_generated"] as? Bool,
           let confidence = payload["confidence_score"] as? Double {
            let processingTime = payload["processing_time_ms"] as? Double
            return DetectionResult(
                likelyAIGenerated: likelyAI,
                confidenceScore: confidence,
                processingTimeMs: processingTime
            )
        }

        // Fallback to top-level fields
        if let detected = json?["detected"] as? Bool,
           let confidence = json?["confidence"] as? Double {
            return DetectionResult(
                likelyAIGenerated: detected,
                confidenceScore: confidence,
                processingTimeMs: nil
            )
        }

        throw APIError(message: "Unexpected response format from Scam.ai")
    }

    /// Analyze a video for deepfakes using the Scam.ai video detection endpoint.
    func analyzeVideo(_ videoURL: URL, apiKey: String) async throws -> VideoDetectionResult {
        let videoData = try Data(contentsOf: videoURL)

        let url = URL(string: "https://api.scam.ai/api/defence/video/detection")!
        let boundary = UUID().uuidString

        var request = URLRequest(url: url, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let ext = videoURL.pathExtension.lowercased()
        let mimeType = ext == "mov" ? "video/quicktime" : "video/mp4"
        let fileName = "video.\(ext.isEmpty ? "mp4" : ext)"

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"video\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(videoData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(message: "Invalid response from Scam.ai")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw APIError(message: "Invalid Scam.ai API key")
            }
            let responseBody = String(data: data, encoding: .utf8) ?? "Unknown"
            throw APIError(message: "Scam.ai error (\(httpResponse.statusCode)): \(responseBody)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let dataObj = json?["data"] as? [String: Any]
        let resultObj = dataObj?["result"] as? [String: Any]

        guard let resultObj,
              let isManipulated = resultObj["is_manipulated"] as? Bool,
              let confidence = resultObj["confidence_score"] as? Double else {
            throw APIError(message: "Unexpected response format from Scam.ai")
        }

        let details = resultObj["analysis_details"] as? [String: Any]
        let processingTime = details?["processing_time_ms"] as? Double
        let detectionTypes = details?["detection_types"] as? [String] ?? []

        return VideoDetectionResult(
            isManipulated: isManipulated,
            confidenceScore: confidence,
            processingTimeMs: processingTime,
            detectionTypes: detectionTypes
        )
    }
}
