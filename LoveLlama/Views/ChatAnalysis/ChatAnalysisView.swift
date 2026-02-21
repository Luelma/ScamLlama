import SwiftUI
import SwiftData
import PhotosUI

struct ChatAnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ChatAnalysisViewModel()
    @State private var selectedItem: PhotosPickerItem?
    @State private var showAPIConsentAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Context fields
                    HStack(spacing: 12) {
                        TextField("Contact name", text: $viewModel.contactName)
                            .textFieldStyle(.roundedBorder)
                        TextField("Platform", text: $viewModel.platform)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.horizontal)

                    // Input mode picker
                    Picker("Input Mode", selection: $viewModel.inputMode) {
                        ForEach(ChatAnalysisViewModel.InputMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Input area based on mode
                    if viewModel.inputMode == .paste {
                        pasteInputSection
                    } else {
                        screenshotInputSection
                    }

                    // Editable text preview (for screenshot mode after OCR)
                    if viewModel.inputMode == .screenshot && !viewModel.inputText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Extracted Text (editable)", systemImage: "text.magnifyingglass")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            TextEditor(text: $viewModel.inputText)
                                .frame(minHeight: 120)
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(.separator), lineWidth: 0.5)
                                )

                            Text("\(viewModel.inputText.count) characters")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal)
                    }

                    // Local scan preview while API loads
                    if let localResult = viewModel.engine.localScanResult,
                       !localResult.flaggedPatterns.isEmpty,
                       viewModel.isLoading {
                        LoadingAnalysisView(localResult: localResult)
                            .padding(.horizontal)
                    }

                    // Error
                    if let error = viewModel.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    // Analyze button
                    Button {
                        handleAnalyzeTapped()
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(viewModel.isLoading ? "Analyzing..." : "Analyze Conversation")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canAnalyze || viewModel.isLoading)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .brandedNavigationBar(title: "Analyze Chat", icon: "text.bubble.fill")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") { viewModel.reset() }
                        .disabled(viewModel.inputText.isEmpty && viewModel.selectedImage == nil && !viewModel.isLoading)
                }
            }
            .navigationDestination(isPresented: $viewModel.showingResult) {
                if let result = viewModel.analysisResult {
                    ChatResultView(
                        result: result,
                        contactName: viewModel.contactName,
                        onSave: {
                            viewModel.saveConversation(modelContext: modelContext)
                        }
                    )
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await viewModel.extractText(from: image)
                    }
                }
            }
            .alert("Share Data with Anthropic?", isPresented: $showAPIConsentAlert) {
                Button("Allow & Analyze") {
                    ConsentManager.shared.acceptChatAPIConsent()
                    Task { await viewModel.analyze() }
                }
                Button("Analyze Locally Only") {
                    Task { await viewModel.analyze() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("To provide AI-enhanced analysis, the conversation text you entered will be sent to Anthropic's Claude API (api.anthropic.com) for scam pattern detection.\n\nData sent: The conversation text only. No personal identifiers, contact names, or device info are included.\n\nRecipient: Anthropic, PBC — processed under their usage policy.\n\nYou can also analyze locally on-device without sharing any data.")
            }
        }
    }

    // MARK: - Analyze Flow

    private func handleAnalyzeTapped() {
        let hasAPIKey = Task {
            await APIKeyManager.shared.getKey() != nil
        }

        Task {
            let keyExists = await hasAPIKey.value

            // If they have an API key but haven't consented to chat API sharing yet, prompt
            if keyExists && ConsentManager.shared.hasConsented && !ConsentManager.shared.hasConsentedChatAPI {
                showAPIConsentAlert = true
            } else {
                await viewModel.analyze()
            }
        }
    }

    // MARK: - Paste Input

    private var pasteInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Paste conversation text", systemImage: "doc.on.clipboard")
                .font(.subheadline)
                .fontWeight(.medium)

            TextEditor(text: $viewModel.inputText)
                .frame(minHeight: 200)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )

            if !viewModel.inputText.isEmpty {
                Text("\(viewModel.inputText.count) characters")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Screenshot Input

    private var screenshotInputSection: some View {
        VStack(spacing: 12) {
            if let image = viewModel.selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
            }

            if viewModel.isExtractingText {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Extracting text from screenshot...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let ocrError = viewModel.ocrError {
                Label(ocrError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            PhotosPicker(
                selection: $selectedItem,
                matching: .screenshots
            ) {
                Label(
                    viewModel.selectedImage == nil ? "Select Screenshot" : "Choose Different Screenshot",
                    systemImage: "photo.on.rectangle"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
    }
}

#Preview {
    ChatAnalysisView()
        .modelContainer(for: [Conversation.self], inMemory: true)
}
