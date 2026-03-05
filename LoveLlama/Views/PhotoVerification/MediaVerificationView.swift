import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct MediaVerificationView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = MediaVerificationViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var showAPIConsentAlert = false
    @State private var showAudioDocumentPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Media type picker
                    Picker("Media Type", selection: $viewModel.selectedMediaType) {
                        ForEach(MediaType.allCases, id: \.self) { type in
                            Label(type.label, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Info card
                    infoCard

                    // Loading state
                    if let message = viewModel.stateMessage {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Error
                    if let error = viewModel.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    // Media-specific content
                    switch viewModel.selectedMediaType {
                    case .photo: photoContent
                    case .video: videoContent
                    case .audio: audioContent
                    }

                    // Analyze button
                    if viewModel.hasSelectedMedia {
                        Button {
                            handleAnalyzeTapped()
                        } label: {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text(viewModel.isLoading ? "Analyzing..." : analyzeButtonLabel)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .disabled(viewModel.isLoading)
                        .padding(.horizontal)
                    }

                    // Info label
                    if !viewModel.isLoading && !viewModel.hasSelectedMedia {
                        Label(infoLabelText, systemImage: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .brandedNavigationBar(title: "Verify Media", icon: "shield.lefthalf.filled")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") { viewModel.reset() }
                        .disabled(!viewModel.hasSelectedMedia && !viewModel.isLoading)
                }
            }
            // Photo result destination
            .navigationDestination(isPresented: Binding(
                get: { viewModel.showingResult && viewModel.selectedMediaType == .photo },
                set: { viewModel.showingResult = $0 }
            )) {
                if let result = viewModel.photoAnalysisResult {
                    PhotoResultView(
                        analysis: result,
                        image: viewModel.selectedImage,
                        onSave: { viewModel.saveResult(modelContext: modelContext) }
                    )
                }
            }
            // Media result destination (video/audio)
            .navigationDestination(isPresented: Binding(
                get: { viewModel.showingResult && viewModel.selectedMediaType != .photo },
                set: { viewModel.showingResult = $0 }
            )) {
                if let result = viewModel.mediaAnalysisResult {
                    MediaResultView(
                        analysis: result,
                        videoThumbnail: viewModel.videoThumbnail,
                        audioDuration: viewModel.audioDuration,
                        audioFileName: viewModel.audioFileName,
                        onSave: { viewModel.saveResult(modelContext: modelContext) }
                    )
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        viewModel.selectedImage = image
                    }
                }
            }
            .onChange(of: selectedVideoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let movie = try? await newItem.loadTransferable(type: VideoTransferable.self) {
                        viewModel.setVideoURL(movie.url)
                    }
                }
            }
            .alert("Share Media with Reality Defender?", isPresented: $showAPIConsentAlert) {
                Button("Allow & Analyze") {
                    ConsentManager.shared.acceptPhotoAPIConsent()
                    Task { await viewModel.analyze() }
                }
                if viewModel.selectedMediaType == .photo {
                    Button("Analyze On-Device Only") {
                        Task { await viewModel.analyze() }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(consentMessage)
            }
            .sheet(isPresented: $viewModel.showingAudioRecorder) {
                AudioRecorderView { url in
                    viewModel.setAudioURL(url)
                }
            }
            .fullScreenCover(isPresented: $viewModel.showingVideoRecorder) {
                VideoRecorderView { url in
                    viewModel.setVideoURL(url)
                }
            }
            .sheet(isPresented: $showAudioDocumentPicker) {
                AudioDocumentPicker { url in
                    viewModel.setAudioURL(url)
                }
            }
        }
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(infoCardTitle, systemImage: "sparkles")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.purple)

            Text(infoCardText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.purple.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var infoCardTitle: String {
        switch viewModel.selectedMediaType {
        case .photo: return "AI Photo Detection"
        case .video: return "Video Deepfake Detection"
        case .audio: return "Voice Deepfake Detection"
        }
    }

    private var infoCardText: String {
        switch viewModel.selectedMediaType {
        case .photo:
            return "Upload a profile photo to check if it was generated by AI. Combines on-device analysis with Reality Defender's deepfake detection."
        case .video:
            return "Upload a video clip to detect AI-generated or deepfaked video content. Uses Reality Defender's deepfake detection API. Max 250 MB."
        case .audio:
            return "Upload a voice clip to detect AI-cloned or synthetic voices. Uses Reality Defender's deepfake detection API. Max 20 MB."
        }
    }

    // MARK: - Photo Content

    private var photoContent: some View {
        VStack(spacing: 16) {
            if let image = viewModel.selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                    .padding(.horizontal)
            }

            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images
            ) {
                Label(
                    viewModel.selectedImage == nil ? "Select Profile Photo" : "Choose Different Photo",
                    systemImage: "person.crop.circle.badge.plus"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
        }
    }

    // MARK: - Video Content

    private var videoContent: some View {
        VStack(spacing: 16) {
            if let thumbnail = viewModel.videoThumbnail {
                ZStack {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(radius: 4)
                }
                .padding(.horizontal)

                if let duration = viewModel.audioDuration {
                    Text("Duration: \(viewModel.formatDuration(duration))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            PhotosPicker(
                selection: $selectedVideoItem,
                matching: .videos
            ) {
                Label(
                    viewModel.selectedVideoURL == nil ? "Select Video" : "Choose Different Video",
                    systemImage: "video.badge.plus"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)

            Button {
                viewModel.showingVideoRecorder = true
            } label: {
                Label("Record Video", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
        }
    }

    // MARK: - Audio Content

    private var audioContent: some View {
        VStack(spacing: 16) {
            if viewModel.selectedAudioURL != nil {
                VStack(spacing: 12) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.purple)

                    if let fileName = viewModel.audioFileName {
                        Text(fileName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let duration = viewModel.audioDuration {
                        Text("Duration: \(viewModel.formatDuration(duration))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.purple.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }

            Button {
                showAudioDocumentPicker = true
            } label: {
                Label(
                    viewModel.selectedAudioURL == nil ? "Select Audio File" : "Choose Different Audio",
                    systemImage: "doc.badge.plus"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)

            Button {
                viewModel.showingAudioRecorder = true
            } label: {
                Label("Record Voice", systemImage: "mic.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
        }
    }

    // MARK: - Analyze Flow

    private var analyzeButtonLabel: String {
        switch viewModel.selectedMediaType {
        case .photo: return "Check for AI Generation"
        case .video: return "Check Video for Deepfakes"
        case .audio: return "Check Voice for Deepfakes"
        }
    }

    private var infoLabelText: String {
        switch viewModel.selectedMediaType {
        case .photo: return "On-device + Reality Defender dual analysis"
        case .video: return "Reality Defender deepfake detection"
        case .audio: return "Reality Defender voice clone detection"
        }
    }

    private var consentMessage: String {
        let mediaLabel = viewModel.selectedMediaType.label.lowercased()
        return "To provide enhanced AI detection, your selected \(mediaLabel) will be uploaded to Reality Defender's API (api.prd.realitydefender.xyz) for deepfake analysis.\n\nData sent: The \(mediaLabel) file only. No file names, metadata, or personal information are included.\n\nRecipient: Reality Defender, Inc. — processed under their privacy policy."
    }

    private func handleAnalyzeTapped() {
        if ConsentManager.shared.hasConsented && !ConsentManager.shared.hasConsentedPhotoAPI {
            showAPIConsentAlert = true
        } else {
            Task { await viewModel.analyze() }
        }
    }
}

// MARK: - Video Transferable

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("lovellama_video_\(UUID().uuidString).\(received.file.pathExtension)")
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}

// MARK: - Audio Document Picker

struct AudioDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [.mp3, .wav, .aiff, .mpeg4Audio, .audio]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            // Copy to temp for continued access
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("lovellama_audio_\(UUID().uuidString).\(url.pathExtension)")
            try? FileManager.default.copyItem(at: url, to: tempURL)
            onPick(tempURL)
        }
    }
}

#Preview {
    MediaVerificationView()
        .modelContainer(for: [PhotoCheck.self], inMemory: true)
}
