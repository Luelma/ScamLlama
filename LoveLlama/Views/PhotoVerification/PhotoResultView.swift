import SwiftUI

struct PhotoResultView: View {
    let analysis: PhotoAnalysisResult
    var image: UIImage?
    var onSave: (() -> Void)?
    @State private var saved = false

    private var overall: PhotoDetectionResult { analysis.overallResult }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Image preview
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(overall.riskLevel.color, lineWidth: 3)
                        )
                        .padding(.top, 8)
                }

                // Overall verdict
                VStack(spacing: 12) {
                    Image(systemName: statusIcon(for: overall))
                        .font(.system(size: 44))
                        .foregroundStyle(overall.riskLevel.color)

                    Text(overall.statusLabel)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(overall.riskLevel.color)

                    RiskBadgeView(riskLevel: overall.riskLevel)
                }

                // Side-by-side analysis cards
                VStack(spacing: 12) {
                    // On-Device Analysis card
                    analysisCard(
                        title: "On-Device Analysis",
                        icon: "iphone",
                        color: .purple,
                        result: analysis.localResult
                    )

                    // Reality Defender card
                    if analysis.rdLoading {
                        cloudLoadingCard(title: "Reality Defender", icon: "checkmark.seal.fill", color: .indigo)
                    } else if let rdError = analysis.rdError {
                        cloudErrorCard(title: "Reality Defender", icon: "checkmark.seal.fill", color: .indigo, message: rdError)
                    } else if let rdResult = analysis.rdResult {
                        analysisCard(
                            title: "Reality Defender",
                            icon: "checkmark.seal.fill",
                            color: .indigo,
                            result: rdResult
                        )
                    } else {
                        cloudErrorCard(title: "Reality Defender", icon: "checkmark.seal.fill", color: .indigo, message: "Photo sharing consent required for Reality Defender analysis")
                    }

                    // Scam.ai card
                    if analysis.scamAILoading {
                        cloudLoadingCard(title: "Scam.ai", icon: "eye.trianglebadge.exclamationmark", color: .teal)
                    } else if let scamError = analysis.scamAIError {
                        cloudErrorCard(title: "Scam.ai", icon: "eye.trianglebadge.exclamationmark", color: .teal, message: scamError)
                    } else if let scamResult = analysis.scamAIResult {
                        analysisCard(
                            title: "Scam.ai",
                            icon: "eye.trianglebadge.exclamationmark",
                            color: .teal,
                            result: scamResult
                        )
                    } else {
                        cloudErrorCard(title: "Scam.ai", icon: "eye.trianglebadge.exclamationmark", color: .teal, message: "Photo sharing consent required for Scam.ai analysis")
                    }
                }
                .padding(.horizontal)

                // Detection Signals (local flags)
                if let flags = analysis.localResult.suspicionFlags, !flags.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Detection Signals", systemImage: "list.bullet.rectangle")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        ForEach(flags, id: \.self) { flag in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                                    .padding(.top, 2)
                                Text(flag)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

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
        .navigationTitle("Photo Results")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Card Views

    private func analysisCard(title: String, icon: String, color: Color, result: PhotoDetectionResult) -> some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: statusIcon(for: result))
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

    private func cloudLoadingCard(title: String, icon: String, color: Color) -> some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
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
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }

    private func cloudErrorCard(title: String, icon: String, color: Color, message: String) -> some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
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

    // MARK: - Helpers

    private func statusIcon(for result: PhotoDetectionResult) -> String {
        switch result.status {
        case "AUTHENTIC": return "checkmark.shield.fill"
        case "FAKE": return "xmark.shield.fill"
        case "SUSPICIOUS": return "exclamationmark.triangle.fill"
        default: return "questionmark.circle.fill"
        }
    }
}
