import SwiftUI

struct LoadingAnalysisView: View {
    let localResult: LocalScanResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text("Running AI analysis...")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                RiskBadgeView(riskLevel: localResult.riskLevel)
            }

            Text("Quick scan found \(localResult.flaggedPatterns.count) potential pattern(s)")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(localResult.flaggedPatterns) { pattern in
                HStack(spacing: 8) {
                    Image(systemName: pattern.patternType.icon)
                        .font(.caption)
                        .foregroundStyle(localResult.riskLevel.color)
                        .frame(width: 20)
                    Text(pattern.patternType.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
