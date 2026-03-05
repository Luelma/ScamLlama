import SwiftUI
import AVFoundation

struct AudioRecorderView: View {
    @Environment(\.dismiss) private var dismiss
    let onRecordingComplete: (URL) -> Void

    @State private var audioRecorder: AVAudioRecorder?
    @State private var isRecording = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var recordingURL: URL?
    @State private var hasPermission = false
    @State private var permissionDenied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Timer display
                Text(formatTime(elapsedTime))
                    .font(.system(size: 56, weight: .light, design: .monospaced))
                    .foregroundStyle(isRecording ? .red : .primary)

                // Recording indicator
                if isRecording {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.red)
                            .frame(width: 10, height: 10)
                        Text("Recording...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if recordingURL != nil {
                    Label("Recording saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                } else {
                    Text("Tap to start recording a voice clip")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Record button
                Button {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color.red.opacity(0.15) : Color.purple.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(isRecording ? .red : .purple)
                    }
                }
                .disabled(permissionDenied)

                if permissionDenied {
                    Text("Microphone access denied. Enable it in Settings.")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                // Use recording button
                if let url = recordingURL, !isRecording {
                    Button {
                        onRecordingComplete(url)
                        dismiss()
                    } label: {
                        Text("Use This Recording")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .padding(.horizontal)
                }
            }
            .padding()
            .navigationTitle("Record Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        stopRecording()
                        cleanupRecording()
                        dismiss()
                    }
                }
            }
            .onAppear {
                requestPermission()
            }
            .onDisappear {
                stopRecording()
            }
        }
    }

    private func requestPermission() {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                hasPermission = granted
                permissionDenied = !granted
            }
        }
    }

    private func startRecording() {
        guard hasPermission else { return }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lovellama_voice_\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            recordingURL = url
            isRecording = true
            elapsedTime = 0

            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                elapsedTime += 0.1
            }
        } catch {
            // Recording failed silently
        }
    }

    private func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        timer?.invalidate()
        timer = nil
    }

    private func cleanupRecording() {
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        let tenths = Int((time * 10).truncatingRemainder(dividingBy: 10))
        return String(format: "%d:%02d.%d", mins, secs, tenths)
    }
}
