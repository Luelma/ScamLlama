import SwiftUI

struct PhotoResultView: View {
    let result: PhotoDetectionResult
    var image: UIImage?
    var onSave: (() -> Void)?
    @State private var saved = false

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
                                .stroke(result.riskLevel.color, lineWidth: 3)
                        )
                        .padding(.top, 8)
                }

                // Status + score
                VStack(spacing: 12) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 44))
                        .foregroundStyle(result.riskLevel.color)

                    Text(result.statusLabel)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(result.riskLevel.color)

                    if let score = result.score {
                        Text("Risk Score: \(Int(score))%")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(result.riskLevel.color)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(result.riskLevel.color.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    RiskBadgeView(riskLevel: result.riskLevel)
                }

                // Attribution badge
                if result.isLocalOnly {
                    HStack(spacing: 6) {
                        Image(systemName: "iphone")
                            .foregroundStyle(.purple)
                        Text("On-Device Analysis")
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.purple.opacity(0.08))
                    .clipShape(Capsule())
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.indigo)
                        Text("Powered by Reality Defender")
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.indigo.opacity(0.08))
                    .clipShape(Capsule())
                }

                // Explanation
                VStack(alignment: .leading, spacing: 12) {
                    Label("Analysis", systemImage: "magnifyingglass")
                        .font(.headline)

                    Text(result.explanation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Suspicion flags (local-only results)
                if let flags = result.suspicionFlags, !flags.isEmpty {
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

                    Text(result.isLocalOnly
                        ? "This result was produced by on-device heuristic analysis, which has reduced accuracy compared to API-based detection. It checks for common AI image artifacts but cannot reliably detect all AI-generated images. Always verify identities through video calls."
                        : "AI detection is not 100% accurate. This result is an indicator, not proof. Always verify identities through video calls and other means."
                    )
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

    private var statusIcon: String {
        switch result.status {
        case "AUTHENTIC": return "checkmark.shield.fill"
        case "FAKE": return "xmark.shield.fill"
        case "SUSPICIOUS": return "exclamationmark.triangle.fill"
        default: return "questionmark.circle.fill"
        }
    }
}
