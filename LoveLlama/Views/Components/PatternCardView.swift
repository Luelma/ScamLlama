import SwiftUI

struct PatternCardView: View {
    let pattern: DetectedPattern

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: pattern.patternType.icon)
                    .font(.title3)
                    .foregroundStyle(.red)
                Text(pattern.patternType.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                confidenceBadge
            }

            if !pattern.evidence.isEmpty {
                Text("\"\(pattern.evidence)\"")
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Text(pattern.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    private var confidenceBadge: some View {
        Text("\(Int(pattern.confidence * 100))%")
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(confidenceColor.opacity(0.15))
            .foregroundStyle(confidenceColor)
            .clipShape(Capsule())
    }

    private var confidenceColor: Color {
        switch pattern.confidence {
        case 0.75...: return .red
        case 0.5..<0.75: return .orange
        default: return .yellow
        }
    }
}
