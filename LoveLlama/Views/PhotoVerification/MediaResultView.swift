import SwiftUI

struct MediaResultView: View {
    let analysis: MediaAnalysisResult
    var videoThumbnail: UIImage?
    var audioDuration: TimeInterval?
    var audioFileName: String?
    var onSave: (() -> Void)?
    @State private var saved = false

    private var result: PhotoDetectionResult { analysis.overallResult }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Media preview
                mediaPreview

                // Overall verdict
                VStack(spacing: 12) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 44))
                        .foregroundStyle(result.riskLevel.color)

                    Text(result.statusLabel)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(result.riskLevel.color)

                    RiskBadgeView(riskLevel: result.riskLevel)
                }

                // Analysis cards
                VStack(spacing: 12) {
                    // Reality Defender result card
                    rdResultCard

                    // Scam.ai card (video only)
                    if analysis.mediaType == .video {
                        if analysis.scamAILoading {
                            scamAILoadingCard
                        } else if let scamError = analysis.scamAIError {
                            scamAIErrorCard(message: scamError)
                        } else if let scamResult = analysis.scamAIResult {
                            scamAIResultCard(result: scamResult)
                        }
                    }
                }
                .padding(.horizontal)

                // Explanation
                Text(result.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Disclaimer
                VStack(alignment: .leading, spacing: 8) {
                    Label("Important", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)

                    Text("AI detection is not 100% accurate. These results are indicators, not proof. Always verify identities through video calls and other means.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Save button
                if let onSave, !saved {
                    Button {
                        onSave()
                        saved = true
                    } label: {
                        Label("Save to History", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                } else if saved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                }

                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle(analysis.mediaType == .video ? "Video Results" : "Voice Results")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var mediaPreview: some View {
        switch analysis.mediaType {
        case .video:
            if let thumbnail = videoThumbnail {
                ZStack {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(result.riskLevel.color, lineWidth: 3)
                        )
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(radius: 4)
                }
                .padding(.top, 8)
            }

        case .audio:
            VStack(spacing: 12) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.purple)

                if let fileName = audioFileName {
                    Text(fileName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let duration = audioDuration {
                    Text(formatDuration(duration))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.purple.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

        case .photo:
            EmptyView()
        }
    }

    private var rdResultCard: some View {
        analysisCard(
            title: "Reality Defender",
            icon: "checkmark.seal.fill",
            color: .indigo,
            result: analysis.rdResult
        )
    }

    private func scamAIResultCard(result: PhotoDetectionResult) -> some View {
        analysisCard(
            title: "Scam.ai",
            icon: "eye.trianglebadge.exclamationmark",
            color: .teal,
            result: result
        )
    }

    private var scamAILoadingCard: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "eye.trianglebadge.exclamationmark")
                    .foregroundStyle(.teal)
                Text("Scam.ai")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            Divider()
            HStack(spacing: 12) {
                ProgressView()
                Text("Analyzing...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color.teal.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.teal.opacity(0.2), lineWidth: 1)
        )
    }

    private func scamAIErrorCard(message: String) -> some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "eye.trianglebadge.exclamationmark")
                    .foregroundStyle(.teal)
                Text("Scam.ai")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(.secondary)
            }
            Divider()
            HStack {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private func analysisCard(title: String, icon: String, color: Color, result: PhotoDetectionResult) -> some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: cardStatusIcon(for: result))
                    .foregroundStyle(result.riskLevel.color)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.statusLabel)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(result.riskLevel.color)

                    if let score = result.score {
                        Text("Risk Score: \(Int(score))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                RiskBadgeView(riskLevel: result.riskLevel)
            }
        }
        .padding()
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }

    private func cardStatusIcon(for result: PhotoDetectionResult) -> String {
        switch result.status {
        case "AUTHENTIC": return "checkmark.shield.fill"
        case "FAKE": return "xmark.shield.fill"
        case "SUSPICIOUS": return "exclamationmark.triangle.fill"
        default: return "questionmark.circle.fill"
        }
    }

    // MARK: - Helpers

    private var statusIcon: String {
        switch result.status {
        case "AUTHENTIC": return "checkmark.shield.fill"
        case "FAKE": return "xmark.shield.fill"
        case "SUSPICIOUS": return "exclamationmark.triangle.fill"
        default: return "questionmark.circle.fill"
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
