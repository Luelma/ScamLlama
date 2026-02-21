import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \ChecklistSession.createdAt, order: .reverse) private var checklistSessions: [ChecklistSession]
    @Query(sort: \Conversation.createdAt, order: .reverse) private var conversations: [Conversation]
    @Query(sort: \PhotoCheck.createdAt, order: .reverse) private var photoChecks: [PhotoCheck]
    @Binding var selectedTab: Int

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Stats summary (if user has any history)
                    if totalScans > 0 {
                        statsSection
                            .padding(.horizontal)
                    } else {
                        heroSection
                            .padding(.horizontal)
                    }

                    // Quick actions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Actions")
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                QuickActionCard(
                                    title: "Analyze Chat",
                                    subtitle: "Is this convo sketchy? 🤔",
                                    icon: "text.bubble.fill",
                                    color: .purple
                                ) { selectedTab = 1 }

                                QuickActionCard(
                                    title: "Check Photo",
                                    subtitle: "Real person or catfish? 🐟",
                                    icon: "person.crop.circle.badge.questionmark",
                                    color: Color(red: 0.55, green: 0.11, blue: 0.53)
                                ) { selectedTab = 2 }

                                QuickActionCard(
                                    title: "Red Flags",
                                    subtitle: "Spot the warning signs 🚩",
                                    icon: "checklist",
                                    color: .red
                                ) { selectedTab = 3 }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Recent activity
                    if !recentItems.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recent Activity")
                                    .font(.headline)
                                Spacer()
                                Button("See All") { selectedTab = 4 }
                                    .font(.subheadline)
                            }
                            .padding(.horizontal)

                            ForEach(recentItems) { item in
                                RecentActivityRow(
                                    title: item.title,
                                    subtitle: item.subtitle,
                                    riskLevel: item.riskLevel,
                                    date: item.date,
                                    icon: item.icon
                                )
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Education tip
                    tipCard
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                }
                .padding(.top, 16)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image("LoveLlamaLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        Text("Love Llama")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 0.55, green: 0.11, blue: 0.53), Color(red: 0.93, green: 0.27, blue: 0.27)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Computed

    private var totalScans: Int {
        conversations.count + photoChecks.count + checklistSessions.count
    }

    private var highRiskCount: Int {
        let convRisk = conversations.filter { ($0.analysisResult?.riskLevel ?? .low) == .high || ($0.analysisResult?.riskLevel ?? .low) == .critical }.count
        let photoRisk = photoChecks.filter { $0.riskLevel == .high || $0.riskLevel == .critical }.count
        let checkRisk = checklistSessions.filter { $0.riskLevel == .high || $0.riskLevel == .critical }.count
        return convRisk + photoRisk + checkRisk
    }

    private var recentItems: [HistoryItem] {
        var all: [HistoryItem] = []
        all += conversations.prefix(3).map { .conversation($0) }
        all += photoChecks.prefix(3).map { .photo($0) }
        all += checklistSessions.prefix(3).map { .checklist($0) }
        return all.sorted { $0.date > $1.date }.prefix(5).map { $0 }
    }

    // MARK: - Subviews

    private var statsSection: some View {
        VStack(spacing: 16) {
            Image("LoveLlamaLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            HStack(spacing: 24) {
                StatPill(value: "\(totalScans)", label: "Scans", color: .blue)
                StatPill(value: "\(highRiskCount)", label: "High Risk", color: highRiskCount > 0 ? .red : .green)
                StatPill(value: "\(photoChecks.count)", label: "Photos", color: .purple)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.08), Color.pink.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var heroSection: some View {
        VStack(spacing: 14) {
            Image("LoveLlamaLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .purple.opacity(0.3), radius: 10, y: 4)

            Text("Don't let love make you blind")
                .font(.title3)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("Analyze chats, verify photos, and spot red flags before your heart gets scammed.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.08), Color.pink.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var tipCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Llama Wisdom 🦙", systemImage: "lightbulb.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.purple)

            Text("Romance scams cost Americans over $1.3 billion in 2023. If they say \"I love you\" before a video call — that's not love, that's a script.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.purple.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Supporting Views

struct StatPill: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(width: 150, alignment: .leading)
            .padding()
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct RecentActivityRow: View {
    let title: String
    let subtitle: String
    let riskLevel: RiskLevel
    let date: Date
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(riskLevel.color)
                .frame(width: 40, height: 40)
                .background(riskLevel.color.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                RiskBadgeView(riskLevel: riskLevel)
                Text(date.relativeDisplay)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    DashboardView(selectedTab: .constant(0))
        .modelContainer(for: [ChecklistSession.self, Conversation.self, PhotoCheck.self], inMemory: true)
}
