import SwiftUI
import SwiftData

@main
struct ScamLlamaApp: App {
    @State private var showConsentSheet = false
    @State private var showForceUpdate = false
    @State private var forceUpdateMessage = ""

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    if !ConsentManager.shared.hasConsented {
                        showConsentSheet = true
                    }
                }
                .task {
                    let (needsUpdate, message) = await ForceUpdateChecker.check()
                    if needsUpdate {
                        forceUpdateMessage = message
                        showForceUpdate = true
                    }
                }
                .sheet(isPresented: $showConsentSheet) {
                    ConsentSheetView(isPresented: $showConsentSheet)
                        .interactiveDismissDisabled()
                }
                .fullScreenCover(isPresented: $showForceUpdate) {
                    ForceUpdateView(message: forceUpdateMessage)
                }
        }
        .modelContainer(for: [
            ChecklistSession.self,
            Conversation.self,
            PhotoCheck.self
        ])
    }
}

struct ConsentSheetView: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image("ScamLlamaLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: .teal.opacity(0.3), radius: 8, y: 3)

                    Text("Before We Get Started")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Scam Llama can optionally use third-party AI services for enhanced analysis. All features also work fully offline on your device. Here's what you should know:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 16) {
                        consentItem(
                            icon: "text.bubble.fill",
                            color: .teal,
                            title: "Chat Analysis",
                            description: "Conversation text you submit may be sent to Anthropic's Claude API (api.anthropic.com) for AI-enhanced scam detection. Only the text is sent — no names, contacts, or device info. You'll be asked for permission before any data is shared. Works offline without an API key."
                        )

                        consentItem(
                            icon: "person.crop.circle.badge.questionmark",
                            color: Color(red: 0.12, green: 0.22, blue: 0.42),
                            title: "Photo Verification",
                            description: "Photos are analyzed on-device first. If you add a Reality Defender API key, photos may be uploaded to Reality Defender's API (realitydefender.xyz) for enhanced AI detection. Only the photo is sent. You'll be asked for permission before any upload. Works offline without an API key."
                        )

                        consentItem(
                            icon: "lock.shield.fill",
                            color: .green,
                            title: "Your Data Stays Yours",
                            description: "All analysis history is stored locally on your device with encryption. You can delete everything at any time from Settings."
                        )

                        consentItem(
                            icon: "eye.slash.fill",
                            color: .teal,
                            title: "No Tracking",
                            description: "We don't collect analytics, track your activity, or share data with advertisers."
                        )
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    Text("By tapping \"I Agree\", you acknowledge how Scam Llama works. You will be asked for additional permission before any data is sent to a third-party service.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        ConsentManager.shared.acceptConsent()
                        isPresented = false
                    } label: {
                        Text("I Agree")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.12, green: 0.22, blue: 0.42), Color(red: 0.13, green: 0.55, blue: 0.47)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Text("Read Full Privacy Policy")
                            .font(.subheadline)
                    }
                }
                .padding()
            }
        }
    }

    private func consentItem(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Force Update View

struct ForceUpdateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image("ScamLlamaLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .teal.opacity(0.3), radius: 8, y: 3)

            Text("Update Required")
                .font(.title2)
                .fontWeight(.bold)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                UIApplication.shared.open(ForceUpdateChecker.appStoreURL)
            } label: {
                Text("Update Now")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.12, green: 0.22, blue: 0.42), Color(red: 0.13, green: 0.55, blue: 0.47)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}
