import SwiftUI
import SwiftData

struct ChecklistView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ChecklistViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Live score header
                scoreHeader
                    .padding()
                    .background(.ultraThinMaterial)

                // Checklist
                List {
                    // Contact name
                    Section {
                        TextField("Contact name (optional)", text: $viewModel.contactName)
                    }

                    // Red flag items by category
                    ForEach(viewModel.categories, id: \.self) { category in
                        Section(header: categoryHeader(category)) {
                            ForEach(viewModel.items(for: category)) { item in
                                ChecklistRowView(
                                    item: item,
                                    isChecked: viewModel.isChecked(item.id)
                                ) {
                                    viewModel.toggle(item.id)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .brandedNavigationBar(title: "Red Flags", icon: "checklist")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") {
                        viewModel.reset()
                    }
                    .disabled(viewModel.checkedIDs.isEmpty)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        viewModel.saveSession(modelContext: modelContext)
                        viewModel.showingResult = true
                    } label: {
                        Text("View Full Assessment")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.riskLevel.color)
                    .disabled(viewModel.checkedIDs.isEmpty)
                }
            }
            .navigationDestination(isPresented: $viewModel.showingResult) {
                ChecklistResultView(viewModel: viewModel)
            }
        }
    }

    private var scoreHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Risk Score")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.score.percentString)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(viewModel.riskLevel.color)
                    .contentTransition(.numericText())
                    .animation(.easeInOut, value: viewModel.score)
            }

            Spacer()

            RiskBadgeView(riskLevel: viewModel.riskLevel)

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Flags")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(viewModel.checkedCount) / \(viewModel.items.count)")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
        }
    }

    private func categoryHeader(_ category: String) -> some View {
        HStack {
            Image(systemName: categoryIcon(category))
            Text(category)
        }
    }

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "Communication": return "bubble.left.and.bubble.right"
        case "Emotional": return "heart"
        case "Identity": return "person.crop.circle"
        case "Financial": return "dollarsign.circle"
        default: return "flag"
        }
    }
}

struct ChecklistRowView: View {
    let item: ChecklistItem
    let isChecked: Bool
    let onToggle: () -> Void

    @State private var showDescription = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Button(action: onToggle) {
                    Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundStyle(isChecked ? .red : .secondary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(isChecked ? .semibold : .regular)
                        .foregroundStyle(isChecked ? .primary : .secondary)

                    if showDescription {
                        Text(item.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showDescription.toggle()
                    }
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            // Weight indicator
            if isChecked {
                HStack(spacing: 4) {
                    ForEach(0..<5) { i in
                        Circle()
                            .fill(Double(i) < item.weight ? Color.red : Color(.systemGray4))
                            .frame(width: 6, height: 6)
                    }
                    Text("severity")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 32)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isChecked)
    }
}

#Preview {
    ChecklistView()
        .modelContainer(for: ChecklistSession.self, inMemory: true)
}
