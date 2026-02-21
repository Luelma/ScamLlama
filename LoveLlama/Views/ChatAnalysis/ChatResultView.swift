import SwiftUI

struct ChatResultView: View {
    let result: AnalysisResult
    var contactName: String = ""
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
