import Foundation
import UIKit
import SwiftData
import Observation

@Observable
class PhotoVerificationViewModel {
    var selectedImage: UIImage?
    var detector = AIImageDetector()
    var showingResult = false

    var isLoading: Bool {
        detector.state == .scanning || detector.state == .uploading || detector.state == .analyzing
    }

    var stateMessage: String? {
        switch detector.state {
        case .scanning: return "Scanning image locally..."
        case .uploading: return "Uploading image..."
        case .analyzing: return "Analyzing with Reality Defender..."
        default: return nil
        }
    }

    var detectionResult: PhotoDetectionResult? {
        if case .complete(let result) = detector.state {
            return result
        }
        return nil
    }

    var errorMessage: String? {
        if case .error(let msg) = detector.state {
            return msg
        }
        return nil
    }

    func analyze() async {
        guard let image = selectedImage else { return }
        await detector.analyze(image: image)
        if detectionResult != nil {
            showingResult = true
        }
    }

    func saveResult(modelContext: ModelContext) {
        guard let result = detectionResult else { return }
        let check = PhotoCheck(imageData: selectedImage?.jpegData(compressionQuality: 0.5))
        check.detectionStatus = result.status
        check.aiScore = result.score
        check.requestId = result.requestId
        check.isLocalOnly = result.isLocalOnly
        modelContext.insert(check)
    }

    func reset() {
        selectedImage = nil
        detector.reset()
        showingResult = false
    }
}
