import Foundation
import Observation

@Observable
class SettingsViewModel {
    // Claude API key
    var apiKey: String = ""
    var hasKey: Bool = false
    var showKey: Bool = false
    var statusMessage: String?
    var isError: Bool = false

    // Reality Defender API key
    var rdApiKey: String = ""
    var hasRDKey: Bool = false
    var showRDKey: Bool = false
    var rdStatusMessage: String?
    var isRDError: Bool = false

    // Only load presence status on init — NOT the full key
    func loadKeyStatus() async {
        hasKey = await APIKeyManager.shared.hasKey()
        hasRDKey = await RDKeyManager.shared.hasKey()
        // Keys stay empty until user explicitly enters or reveals them
    }

    // MARK: - Claude Key

    func revealKey() async {
        if hasKey {
            apiKey = await APIKeyManager.shared.getKey() ?? ""
        }
    }

    func saveKey() async {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusMessage = "Please enter an API key"
            isError = true
            return
        }
        guard trimmed.hasPrefix("sk-ant-") else {
            statusMessage = "Invalid key format. Keys start with sk-ant-"
            isError = true
            return
        }
        do {
            try await APIKeyManager.shared.saveKey(trimmed)
            hasKey = true
            statusMessage = "API key saved"
            isError = false
            // Clear from memory after saving
            apiKey = ""
        } catch {
            statusMessage = error.localizedDescription
            isError = true
        }
    }

    func deleteKey() async {
        await APIKeyManager.shared.deleteKey()
        apiKey = ""
        hasKey = false
        showKey = false
        statusMessage = "API key removed"
        isError = false
    }

    var maskedKey: String {
        guard apiKey.count > 12 else {
            return hasKey ? "sk-ant-•••••••••••" : ""
        }
        let prefix = String(apiKey.prefix(7))
        let suffix = String(apiKey.suffix(4))
        return "\(prefix)...\(suffix)"
    }

    // MARK: - Reality Defender Key

    func revealRDKey() async {
        if hasRDKey {
            rdApiKey = await RDKeyManager.shared.getKey() ?? ""
        }
    }

    func saveRDKey() async {
        let trimmed = rdApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            rdStatusMessage = "Please enter an API key"
            isRDError = true
            return
        }
        do {
            try await RDKeyManager.shared.saveKey(trimmed)
            hasRDKey = true
            rdStatusMessage = "API key saved"
            isRDError = false
            // Clear from memory after saving
            rdApiKey = ""
        } catch {
            rdStatusMessage = error.localizedDescription
            isRDError = true
        }
    }

    func deleteRDKey() async {
        await RDKeyManager.shared.deleteKey()
        rdApiKey = ""
        hasRDKey = false
        showRDKey = false
        rdStatusMessage = "API key removed"
        isRDError = false
    }

    var maskedRDKey: String {
        guard rdApiKey.count > 12 else {
            return hasRDKey ? "••••••••••••••••" : ""
        }
        let prefix = String(rdApiKey.prefix(8))
        let suffix = String(rdApiKey.suffix(4))
        return "\(prefix)...\(suffix)"
    }
}
