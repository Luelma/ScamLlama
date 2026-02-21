import SwiftUI
import SwiftData

struct HistoryListView: View {
    @Query(sort: \Conversation.createdAt, order: .reverse) private var conversations: [Conversation]
    @Query(sort: \ChecklistSession.createdAt, order: .reverse) private var checklistSessions: [ChecklistSession]
    @Query(sort: \PhotoCheck.createdAt, order: .reverse) private var photoChecks: [PhotoCheck]
    @Environment(\.modelContext) private var modelContext
    @State private var filter: HistoryFilter = .all

    private var items: [HistoryItem] {
        var all: [HistoryItem] = []

        if filter == .all || filter == .chats {
            all += conversations.map { HistoryItem.conversation($0) }
        }
        if filter == .all || filter == .photos {
            all += photoChecks.map { HistoryItem.photo($0) }
        }
        if filter == .all || filter == .checklists {
            all += checklistSessions.map { HistoryItem.checklist($0) }
        }

        return all.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                HistoryRowView(item: item)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .brandedNavigationBar(title: "History", icon: "clock.fill")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Filter", selection: $filter) {
                            ForEach(HistoryFilter.allCases) { f in
                                Label(f.label, systemImage: f.icon)
                                    .tag(f)
                            }
                        }
                    } label: {
                        Image(systemName: filter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
            }
            .navigationDestination(for: HistoryItem.self) { item in
                HistoryDetailView(item: item)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No History Yet", systemImage: "clock")
        } description: {
            Text("Your analysis results will appear here after you save them.")
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let toDelete = offsets.map { items[$0] }
        for item in toDelete {
            switch item {
            case .conversation(let c): modelContext.delete(c)
            case .photo(let p): modelContext.delete(p)
            case .checklist(let s): modelContext.delete(s)
            }
        }
    }
}

// MARK: - Supporting Types

enum HistoryFilter: String, CaseIterable, Identifiable {
    case all, chats, photos, checklists

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .chats: return "Chat Analyses"
        case .photos: return "Photo Checks"
        case .checklists: return "Checklists"
        }
    }

    var icon: String {
        switch self {
        case .all: return "tray.full"
        case .chats: return "text.bubble"
        case .photos: return "person.crop.circle.badge.questionmark"
        case .checklists: return "checklist"
        }
    }
}

enum HistoryItem: Identifiable, Hashable {
    case conversation(Conversation)
    case photo(PhotoCheck)
    case checklist(ChecklistSession)

    var id: UUID {
        switch self {
        case .conversation(let c): return c.id
        case .photo(let p): return p.id
        case .checklist(let s): return s.id
        }
    }

    var date: Date {
        switch self {
        case .conversation(let c): return c.createdAt
        case .photo(let p): return p.createdAt
        case .checklist(let s): return s.createdAt
        }
    }

    var riskLevel: RiskLevel {
        switch self {
        case .conversation(let c): return c.analysisResult?.riskLevel ?? .medium
        case .photo(let p): return p.riskLevel
        case .checklist(let s): return s.riskLevel
        }
    }

    var title: String {
        switch self {
        case .conversation(let c): return c.contactName ?? "Chat Analysis"
        case .photo: return "Photo Check"
        case .checklist(let s): return s.contactName ?? "Checklist"
        }
    }

    var subtitle: String {
        switch self {
        case .conversation(let c):
            return c.analysisResult?.summary ?? "Analysis saved"
        case .photo(let p):
            return p.statusLabel
        case .checklist(let s):
            return "\(s.checkedItemIDs.count) red flags identified"
        }
    }

    var icon: String {
        switch self {
        case .conversation: return "text.bubble.fill"
        case .photo: return "person.crop.circle.badge.questionmark"
        case .checklist: return "checklist"
        }
    }

    var typeLabel: String {
        switch self {
        case .conversation: return "Chat"
        case .photo: return "Photo"
        case .checklist: return "Checklist"
        }
    }

    static func == (lhs: HistoryItem, rhs: HistoryItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Row View

struct HistoryRowView: View {
    let item: HistoryItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.title3)
                .foregroundStyle(item.riskLevel.color)
                .frame(width: 40, height: 40)
                .background(item.riskLevel.color.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(item.typeLabel)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack {
                    RiskBadgeView(riskLevel: item.riskLevel)
                    Spacer()
                    Text(item.date.relativeDisplay)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HistoryListView()
        .modelContainer(for: [ChecklistSession.self, Conversation.self, PhotoCheck.self], inMemory: true)
}
