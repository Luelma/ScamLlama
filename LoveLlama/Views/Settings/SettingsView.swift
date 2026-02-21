import SwiftUI
import SwiftData

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @State private var showDeleteConfirmation = false
    @State private var showRDDeleteConfirmation = false
    @State private var showDeleteAllDataConfirmation = false
    @State private var showRevokeConsentConfirmation = false
    @State private var dataDeleted = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                // Claude API Key
                Section {
                    if viewModel.hasKey && !viewModel.showKey {
                        HStack {
                            Label("API Key", systemImage: "key.fill")
                            Spacer()
                            Text(viewModel.maskedKey)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospaced()
                        }
                        Button("Show Key") {
                            viewModel.showKey = true
                            Task { await viewModel.revealKey() }
                        }
                        Button("Remove Key", role: .destructive) { showDeleteConfirmation = true }
                    } else {
                        SecureField("sk-ant-...", text: $viewModel.apiKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .monospaced()
                            .font(.caption)
                        Button("Save API Key") {
                            Task { await viewModel.saveKey() }
                        }
                        .disabled(viewModel.apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if let status = viewModel.statusMessage {
                        Label(status, systemImage: viewModel.isError ? "xmark.circle" : "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(viewModel.isError ? .red : .green)
                    }
                } header: {
                    Text("Anthropic API Key")
                } footer: {
                    Text("Powers AI chat analysis. Stored in the iOS Keychain.")
                }

                // Reality Defender API Key
                Section {
                    if viewModel.hasRDKey && !viewModel.showRDKey {
                        HStack {
                            Label("API Key", systemImage: "key.fill")
                            Spacer()
                            Text(viewModel.maskedRDKey)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospaced()
                        }
                        Button("Show Key") {
                            viewModel.showRDKey = true
                            Task { await viewModel.revealRDKey() }
                        }
                        Button("Remove Key", role: .destructive) { showRDDeleteConfirmation = true }
                    } else {
                        SecureField("Your Reality Defender key", text: $viewModel.rdApiKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .monospaced()
                            .font(.caption)
                        Button("Save API Key") {
                            Task { await viewModel.saveRDKey() }
                        }
                        .disabled(viewModel.rdApiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if let status = viewModel.rdStatusMessage {
                        Label(status, systemImage: viewModel.isRDError ? "xmark.circle" : "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(viewModel.isRDError ? .red : .green)
                    }
                } header: {
                    Text("Reality Defender API Key")
                } footer: {
                    Text("Powers AI photo detection. You have 500 credits (1 per scan).")
                }

                // Data & Privacy
                Section {
                    if ConsentManager.shared.hasConsented {
                        HStack {
                            Label("Data Processing", systemImage: "checkmark.shield.fill")
                            Spacer()
                            Text("Consented")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        Button("Revoke Consent", role: .destructive) {
                            showRevokeConsentConfirmation = true
                        }
                    } else {
                        Label("Data Processing", systemImage: "exclamationmark.shield.fill")
                            .foregroundStyle(.orange)
                        Text("You haven't consented to third-party data processing. Analysis features won't work until you consent.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        showDeleteAllDataConfirmation = true
                    } label: {
                        Label("Delete All Data", systemImage: "trash.fill")
                    }

                    if dataDeleted {
                        Label("All data deleted", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                } header: {
                    Text("Data & Privacy")
                } footer: {
                    Text("Deletes all saved conversations, photo checks, checklist sessions, and API keys.")
                }

                // About
                Section("About") {
                    LabeledContent("Version", value: "1.1")
                    LabeledContent("Build", value: "3")
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }
                }

                // Links
                Section {
                    Link(destination: URL(string: "https://reportfraud.ftc.gov")!) {
                        Label("Report a Scam (FTC)", systemImage: "exclamationmark.bubble")
                    }
                    Link(destination: URL(string: "https://console.anthropic.com")!) {
                        Label("Get Anthropic Key", systemImage: "link")
                    }
                    Link(destination: URL(string: "https://app.realitydefender.ai/settings/manage-api-keys")!) {
                        Label("Get Reality Defender Key", systemImage: "link")
                    }
                    Link(destination: URL(string: "mailto:lovellama.app@gmail.com")!) {
                        Label("Contact Support", systemImage: "envelope")
                    }
                }
            }
            .brandedNavigationBar(title: "Settings", icon: "gearshape.fill")
            .task {
                await viewModel.loadKeyStatus()
            }
            .confirmationDialog("Remove Claude API Key?", isPresented: $showDeleteConfirmation) {
                Button("Remove", role: .destructive) {
                    Task { await viewModel.deleteKey() }
                }
            } message: {
                Text("This will remove your saved Anthropic API key.")
            }
            .confirmationDialog("Remove Reality Defender Key?", isPresented: $showRDDeleteConfirmation) {
                Button("Remove", role: .destructive) {
                    Task { await viewModel.deleteRDKey() }
                }
            } message: {
                Text("This will remove your saved Reality Defender API key.")
            }
            .confirmationDialog("Delete All Data?", isPresented: $showDeleteAllDataConfirmation) {
                Button("Delete Everything", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("This will permanently delete all conversations, photo checks, checklist sessions, and API keys. This cannot be undone.")
            }
            .confirmationDialog("Revoke Data Processing Consent?", isPresented: $showRevokeConsentConfirmation) {
                Button("Revoke", role: .destructive) {
                    ConsentManager.shared.revokeConsent()
                }
            } message: {
                Text("This will revoke all data sharing permissions. The app will still work using on-device analysis only. No data will be sent to Anthropic or Reality Defender until you consent again.")
            }
        }
    }

    private func deleteAllData() {
        // Delete all SwiftData records
        do {
            try modelContext.delete(model: Conversation.self)
            try modelContext.delete(model: PhotoCheck.self)
            try modelContext.delete(model: ChecklistSession.self)
            try modelContext.save()
        } catch {
            print("Failed to delete data: \(error)")
        }

        // Delete API keys
        Task {
            await viewModel.deleteKey()
            await viewModel.deleteRDKey()
        }

        // Revoke consent
        ConsentManager.shared.revokeConsent()

        dataDeleted = true
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [ChecklistSession.self, Conversation.self, PhotoCheck.self], inMemory: true)
}
