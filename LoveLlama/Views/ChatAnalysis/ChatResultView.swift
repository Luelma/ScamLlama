import SwiftUI

struct ChatResultView: View {
    let result: AnalysisResult
    var contactName: String = ""
    var context: ConversationContext?
    var onSave: (() -> Void)?
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Risk score + status
                VStack(spacing: 12) {
                    Image(systemName: result.riskLevel.icon)
                        .font(.system(size: 44))
                        .foregroundStyle(result.riskLevel.color)

                    Text("Risk Score: \(Int(result.overallScore * 100))%")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(result.riskLevel.color)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(result.riskLevel.color.opacity(0.1))
                        .clipShape(Capsule())

                    RiskBadgeView(riskLevel: result.riskLevel)

                    if !contactName.isEmpty {
                        Text("Analysis for: \(contactName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let stage = result.conversationStage {
                        HStack {
                            Image(systemName: "arrow.triangle.branch")
                            Text("Stage: \(stage.replacingOccurrences(of: "_", with: " ").capitalized)")
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                    }

                    Text(result.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 16)

                // Situation assessment card
                if let context = context, context.hasAnyData {
                    SituationAssessmentCardView(context: context)
                }

                // What a Scammer Would Do Next
                if let prediction = result.nextMovePrediction {
                    NextMovePredictionCardView(prediction: prediction)
                }

                // Detected patterns
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
        }
        .navigationTitle("Analysis Results")
        .navigationBarTitleDisplayMode(.inline)
    }

}

// MARK: - Shared Card Views

enum SituationRisk {
    case low, medium, high
    var icon: String {
        switch self {
        case .low: return "checkmark.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .high: return "xmark.circle.fill"
        }
    }
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .red
        }
    }
}

struct SituationAssessmentCardView: View {
    let context: ConversationContext

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Situation Assessment", systemImage: "person.text.rectangle")
                .font(.headline)
                .foregroundStyle(.purple)

            VStack(spacing: 8) {
                if let duration = context.talkingDuration {
                    situationRow(
                        label: "Talking Duration",
                        value: duration.rawValue,
                        risk: duration == .threeMonthsPlus ? .high : (duration == .oneToThreeMonths ? .medium : .low)
                    )
                }
                if let videoCalled = context.hasVideoCalledPerson {
                    situationRow(
                        label: "Video Called",
                        value: videoCalled ? "Yes" : "No",
                        risk: videoCalled ? .low : .high
                    )
                }
                if let metInPerson = context.hasMetInPerson {
                    situationRow(
                        label: "Met In Person",
                        value: metInPerson ? "Yes" : "No",
                        risk: metInPerson ? .low : .high
                    )
                }
                if let money = context.hasBeenAskedForMoney {
                    situationRow(
                        label: "Money Requested",
                        value: money ? "Yes" : "No",
                        risk: money ? .high : .low
                    )
                }
                if let investments = context.hasDiscussedInvestments {
                    situationRow(
                        label: "Investments Discussed",
                        value: investments ? "Yes" : "No",
                        risk: investments ? .high : .low
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.purple.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func situationRow(label: String, value: String, risk: SituationRisk) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
            Image(systemName: risk.icon)
                .foregroundStyle(risk.color)
                .font(.subheadline)
        }
    }
}

struct NextMovePredictionCardView: View {
    let prediction: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What a Scammer Would Do Next", systemImage: "arrow.trianglehead.clockwise")
                .font(.headline)
                .foregroundStyle(.orange)

            Text(prediction)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}
