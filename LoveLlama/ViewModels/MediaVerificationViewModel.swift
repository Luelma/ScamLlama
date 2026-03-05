import Foundation
import UIKit
import SwiftData
import Observation
import AVFoundation

@Observable
class MediaVerificationViewModel {
    // Shared state
    var selectedMediaType: MediaType = .photo
    var showingResult = false

    // Photo state
    var selectedImage: UIImage?
    var photoDetector = AIImageDetector()

    // Video state
    var selectedVideoURL: URL?
    var videoThumbnail: UIImage?

    // Audio state
    var selectedAudioURL: URL?
    var audioDuration: TimeInterval?
    var audioFileName: String?

    // Media detector (for video/audio)
    var mediaDetector = MediaDetector()

    // Recording
    var showingAudioRecorder = false
    var showingVideoRecorder = false

    // MARK: - Computed

    var isLoading: Bool {
        switch selectedMediaType {
        case .photo:
            return photoDetector.state == .scanning || photoDetector.state == .uploading || photoDetector.state == .analyzing
        case .video, .audio:
            return mediaDetector.state == .processing || mediaDetector.state == .uploading || mediaDetector.state == .analyzing
        }
    }

    var stateMessage: String? {
        switch selectedMediaType {
        case .photo:
            switch photoDetector.state {
            case .scanning: return "Scanning image locally..."
            case .uploading: return "Uploading image..."
            case .analyzing: return "Analyzing with Reality Defender..."
            default: return nil
            }
        case .video:
            switch mediaDetector.state {
            case .processing: return "Preparing video..."
            case .uploading: return "Uploading video..."
            case .analyzing: return "Analyzing video for deepfakes..."
            default: return nil
            }
        case .audio:
            switch mediaDetector.state {
            case .processing: return "Preparing audio..."
            case .uploading: return "Uploading audio..."
            case .analyzing: return "Analyzing voice for deepfakes..."
            default: return nil
            }
        }
    }

    var photoAnalysisResult: PhotoAnalysisResult? {
        if case .complete(let result) = photoDetector.state {
            return result
        }
        return nil
    }

    var mediaAnalysisResult: MediaAnalysisResult? {
        if case .complete(let result) = mediaDetector.state {
            return result
        }
        return nil
    }

    var errorMessage: String? {
        switch selectedMediaType {
        case .photo:
            if case .error(let msg) = photoDetector.state { return msg }
        case .video, .audio:
            if case .error(let msg) = mediaDetector.state { return msg }
        }
        return nil
    }

    var hasSelectedMedia: Bool {
        switch selectedMediaType {
        case .photo: return selectedImage != nil
        case .video: return selectedVideoURL != nil
        case .audio: return selectedAudioURL != nil
        }
    }

    // MARK: - Actions

    func analyzePhoto() async {
        guard let image = selectedImage else { return }
        await photoDetector.analyze(image: image)
        if photoAnalysisResult != nil {
            showingResult = true
        }
    }

    func analyzeVideo() async {
        guard let url = selectedVideoURL else { return }
        await mediaDetector.analyzeVideo(url: url)
        if mediaAnalysisResult != nil {
            showingResult = true
        }
    }

    func analyzeAudio() async {
        guard let url = selectedAudioURL else { return }
        await mediaDetector.analyzeAudio(url: url)
        if mediaAnalysisResult != nil {
            showingResult = true
        }
    }

    func analyze() async {
        switch selectedMediaType {
        case .photo: await analyzePhoto()
        case .video: await analyzeVideo()
        case .audio: await analyzeAudio()
        }
    }

    func setVideoURL(_ url: URL) {
        selectedVideoURL = url
        // Generate thumbnail
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)
        Task {
            if let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) {
                await MainActor.run {
                    videoThumbnail = UIImage(cgImage: cgImage)
                }
            }
            // Get duration
            if let duration = try? await asset.load(.duration) {
                await MainActor.run {
                    audioDuration = duration.seconds
                }
            }
        }
    }

    func setAudioURL(_ url: URL) {
        selectedAudioURL = url
        audioFileName = url.lastPathComponent
        // Get duration
        let asset = AVURLAsset(url: url)
        Task {
            if let duration = try? await asset.load(.duration) {
                await MainActor.run {
                    audioDuration = duration.seconds
                }
            }
        }
    }

    func saveResult(modelContext: ModelContext) {
        let check: PhotoCheck
        switch selectedMediaType {
        case .photo:
            guard let analysis = photoAnalysisResult else { return }
            let result = analysis.overallResult
            check = PhotoCheck(imageData: selectedImage?.jpegData(compressionQuality: 0.5))
            check.detectionStatus = result.status
            check.aiScore = result.score
            check.requestId = result.requestId
            check.isLocalOnly = analysis.rdResult == nil
            check.mediaType = "photo"

        case .video:
            guard let analysis = mediaAnalysisResult else { return }
            let result = analysis.rdResult
            // Store video thumbnail as imageData for history display
            check = PhotoCheck(imageData: videoThumbnail?.jpegData(compressionQuality: 0.5))
            check.detectionStatus = result.status
            check.aiScore = result.score
            check.requestId = result.requestId
            check.isLocalOnly = false
            check.mediaType = "video"
            check.mediaDuration = audioDuration
            check.mediaFileName = selectedVideoURL?.lastPathComponent

        case .audio:
            guard let analysis = mediaAnalysisResult else { return }
            let result = analysis.rdResult
            check = PhotoCheck()
            check.detectionStatus = result.status
            check.aiScore = result.score
            check.requestId = result.requestId
            check.isLocalOnly = false
            check.mediaType = "audio"
            check.mediaDuration = audioDuration
            check.mediaFileName = audioFileName
        }
        modelContext.insert(check)
    }

    func reset() {
        selectedImage = nil
        selectedVideoURL = nil
        videoThumbnail = nil
        selectedAudioURL = nil
        audioDuration = nil
        audioFileName = nil
        photoDetector.reset()
        mediaDetector.reset()
        showingResult = false
    }

    func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
