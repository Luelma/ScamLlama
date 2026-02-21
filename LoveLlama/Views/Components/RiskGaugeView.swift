import SwiftUI

struct RiskGaugeView: View {
    let score: Double
    let riskLevel: RiskLevel
    var size: CGFloat = 200

    private var trimEnd: CGFloat {
        0.5 * score
    }

    var body: some View {
        ZStack {
            // Background arc
            Circle()
                .trim(from: 0, to: 0.5)
                .stroke(Color(.systemGray5), style: StrokeStyle(lineWidth: 20, lineCap: .round))
                .rotationEffect(.degrees(180))
                .frame(width: size, height: size)

            // Filled arc
            Circle()
                .trim(from: 0, to: trimEnd)
                .stroke(
                    riskLevel.color,
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .rotationEffect(.degrees(180))
                .frame(width: size, height: size)
                .animation(.easeInOut(duration: 0.8), value: score)

            // Score text
            VStack(spacing: 4) {
                Text("\(Int(score * 100))")
                    .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                    .foregroundStyle(riskLevel.color)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.8), value: score)

                Text(riskLevel.label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            .offset(y: size * 0.05)
        }
        .frame(height: size * 0.65)
        .clipped()
    }
}

struct RiskBadgeView: View {
    let riskLevel: RiskLevel

    var body: some View {
        Label(riskLevel.label, systemImage: riskLevel.icon)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(riskLevel.color.opacity(0.15))
            .foregroundStyle(riskLevel.color)
            .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: 40) {
        RiskGaugeView(score: 0.15, riskLevel: .low)
        RiskGaugeView(score: 0.45, riskLevel: .medium)
        RiskGaugeView(score: 0.65, riskLevel: .high)
        RiskGaugeView(score: 0.90, riskLevel: .critical)
    }
}
