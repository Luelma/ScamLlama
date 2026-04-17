import SwiftUI

struct ChecklistResultView: View {
    let viewModel: ChecklistViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Risk score + status
                VStack(spacing: 12) {
                    Image(systemName: viewModel.riskLevel.icon)
                        .font(.system(size: 44))
                        .foregroundStyle(viewModel.riskLevel.color)

                    Text("Risk Score: \(Int(viewModel.score * 100))%")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(viewModel.riskLevel.color)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(viewModel.riskLevel.color.opacity(0.1))
                        .clipShape(Capsule())

                    RiskBadgeView(riskLevel: viewModel.riskLevel)
                }
                .padding(.top, 20)

                // Summary card
                summaryCard

                // Checked items detail
                if !viewModel.checkedItems().isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Red Flags Identified")
                            .font(.title3)
                            .fontWeight(.bold)

                        ForEach(viewModel.checkedItems()) { item in
                            redFlagCard(item)
                        }
                    }
                    .padding(.horizontal)
                }

                // Recommendation
                recommendationCard
                    .padding(.horizontal)
                    .padding(.bottom, 40)
            }
        }
        .navigationTitle("Assessment Results")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: viewModel.riskLevel.icon)
                    .font(.title2)
                    .foregroundStyle(viewModel.riskLevel.color)
                Text(summaryText)
                    .font(.headline)
            }

            if let name = viewModel.contactName.isEmpty ? nil : viewModel.contactName {
                Text("Assessment for: \(name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("\(viewModel.checkedCount) of \(viewModel.items.count) red flags identified")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(viewModel.riskLevel.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var summaryText: String {
        switch viewModel.riskLevel {
        case .low:
            return "Few warning signs detected"
        case .medium:
            return "Some concerning patterns found"
        case .high:
            return "Multiple serious red flags"
        case .critical:
            return "Strong indicators of a scam"
        }
    }

    private func redFlagCard(_ item: ChecklistItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(item.category)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
            Text(item.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recommendation", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(.teal)

            Text(recommendationText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.teal.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var recommendationText: String {
        switch viewModel.riskLevel {
        case .low:
            return "Based on the flags you've identified, this person shows few warning signs. Stay cautious and continue to verify their identity over time. Trust your instincts."
        case .medium:
            return "There are some concerning patterns here. We recommend verifying their identity through a video call before deepening the relationship. Don't share financial information."
        case .high:
            return "Multiple serious red flags are present. We strongly recommend not sending any money or personal information. Try to verify their identity independently and consider reporting this profile."
        case .critical:
            return "This situation shows strong indicators of a financial scam. Stop all financial transactions immediately. Do not send money, gift cards, or crypto. Report this to the FTC at reportfraud.ftc.gov."
        }
    }
}
