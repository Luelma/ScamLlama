import SwiftUI
import UIKit

struct VideoRecorderView: UIViewControllerRepresentable {
    let onVideoRecorded: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.movie"]
        picker.videoMaximumDuration = 300 // 5 minutes max
        picker.videoQuality = .typeMedium
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onVideoRecorded: onVideoRecorded, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onVideoRecorded: (URL) -> Void
        let dismiss: DismissAction

        init(onVideoRecorded: @escaping (URL) -> Void, dismiss: DismissAction) {
            self.onVideoRecorded = onVideoRecorded
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let videoURL = info[.mediaURL] as? URL {
                // Copy to temp directory so it persists after picker dismisses
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("scamllama_video_\(UUID().uuidString).\(videoURL.pathExtension)")
                try? FileManager.default.copyItem(at: videoURL, to: tempURL)
                onVideoRecorded(tempURL)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
