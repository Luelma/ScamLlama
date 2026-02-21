import SwiftUI
import SwiftData

struct HistoryDetailView: View {
    let item: HistoryItem

    var body: some View {
        switch item {
        case .conversation(let conversation):
            ConversationDetailView(conversation: conversation)
        case .photo(let photoCheck):
            PhotoCheckDetailView(photoCheck: photoCheck)
        case .checklist(let session):
            ChecklistSessionDetailView(session: session)
        }
    }
}

// MARK: - Conversation Detail

struct ConversationDetailView: View {
    let conversation: Conversation

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let result = conversation.analysisResult {
                    RiskGaugeView(score: result.overallScore, riskLevel: result.riskLevel)
                        .padding(.top, 20)

                    // Info
                    VStack(spacing: 8) {
                        if let name = conversation.contactName, !name.isEmpty {
                            Text("Analysis for: \(name)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 16) {
                            Label(conversation.source == .paste ? "Pasted" : "Screenshot", systemImage: conversation.source == .paste ? "doc.on.clipboard" : "camera.viewfinder")
                            Label(conversation.createdAt.relativeDisplay, systemImage: "clock")
                        }
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                        if let stage = result.conversationStage {
                            Text("Stage: \(stage.replacingOccurrences(of: "_", with: " ").capitalized)")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray5))
                                .clipShape(Capsule())
                        }
                    }

                    Text(result.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Patterns
                    if !result.detectedPatterns.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Detected Patterns (\(result.detectedPatterns.count))")
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.horizontal)

                            ForEach(result.detectedPatterns) { pattern in
                                PatternCardView(pattern: pattern)
                                    .padding(.horizontal)
                            }
                        }
                    }

                    // Recommendation
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Recommendation", systemImage: "lightbulb.fill")
                            .font(.headline)
                            .foregroundStyle(.blue)
                        Text(result.recommendation)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // Original text (collapsed)
                    DisclosureGroup {
                        Text(conversation.inputText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    } label: {
                        Label("Original Text", systemImage: "doc.text")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                } else {
                    ContentUnavailableView("No Results", systemImage: "doc.questionmark", description: Text("Analysis results are not available."))
                }

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Chat Analysis")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Photo Check Detail

struct PhotoCheckDetailView: View {
    let photoCheck: PhotoCheck

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Image
                if let data = photoCheck.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(photoCheck.riskLevel.color, lineWidth: 3)
                        )
                        .padding(.top)
                }

                // Status
                VStack(spacing: 12) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 48))
                        .foregroundStyle(photoCheck.riskLevel.color)

                    Text(photoCheck.statusLabel)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(photoCheck.riskLevel.color)

                    if let score = photoCheck.aiScore {
                        HStack(spacing: 4) {
                            Text("Confidence:")
                                .foregroundStyle(.secondary)
                            Text("\(Int(score))%")
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }

                    Text(photoCheck.createdAt.relativeDisplay)
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    if photoCheck.isLocalOnly {
                        Label("On-Device Analysis", systemImage: "iphone")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }

                // Gauge
                if let score = photoCheck.aiScore {
                    RiskGaugeView(
                        score: score / 100.0,
                        riskLevel: photoCheck.riskLevel,
                        size: 160
                    )
                }

                // Disclaimer
                VStack(alignment: .leading, spacing: 8) {
                    Label("Important", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)

                    Text("AI detection is not 100% accurate. This result is an indicator, not proof. Always verify identities through video calls and other means.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Photo Results")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statusIcon: String {
        switch photoCheck.detectionStatus {
        case "AUTHENTIC": return "checkmark.shield.fill"
        case "FAKE": return "xmark.shield.fill"
        case "SUSPICIOUS": return "exclamationmark.triangle.fill"
        default: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Checklist Session Detail

struct ChecklistSessionDetailView: View {
    let session: ChecklistSession

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                RiskGaugeView(score: session.riskScore, riskLevel: session.riskLevel)
                    .padding(.top, 20)

                VStack(spacing: 8) {
                    if let name = session.contactName, !name.isEmpty {
                        Text("Assessment for: \(name)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text("\(session.checkedItemIDs.count) red flags identified")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(session.createdAt.relativeDisplay)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                RiskBadgeView(riskLevel: session.riskLevel)

                // Recommendation
                VStack(alignment: .leading, spacing: 12) {
                    Label("Recommendation", systemImage: "lightbulb.fill")
                        .font(.headline)
                        .foregroundStyle(.blue)

                    Text(recommendationText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Checklist Results")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var recommendationText: String {
        switch session.riskLevel {
        case .low:
            return "Few warning signs were identified. Stay cautious and continue to verify their identity over time."
        case .medium:
            return "Some concerning patterns were found. Verify their identity through a video call before deepening the relationship."
        case .high:
            return "Multiple serious red flags were present. Do not send money or personal information. Verify their identity independently."
        case .critical:
            return "Strong indicators of a scam. Stop all financial transactions immediately. Report this person to the platform and consider contacting the FTC."
        }
    }
}
