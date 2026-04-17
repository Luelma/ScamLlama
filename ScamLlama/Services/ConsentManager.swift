import Foundation
import Observation

@Observable
class ConsentManager {
    static let shared = ConsentManager()

    // Per-feature consent keys
    private let generalConsentKey = "hasAcceptedDataConsent"
    private let generalConsentDateKey = "dataConsentDate"
    private let chatAPIConsentKey = "hasConsentedChatAPI"
    private let photoAPIConsentKey = "hasConsentedPhotoAPI"

    // MARK: - General Consent (first-launch overview)

    var hasConsented: Bool {
        UserDefaults.standard.bool(forKey: generalConsentKey)
    }

    var consentDate: Date? {
        UserDefaults.standard.object(forKey: generalConsentDateKey) as? Date
    }

    func acceptConsent() {
        UserDefaults.standard.set(true, forKey: generalConsentKey)
        UserDefaults.standard.set(Date(), forKey: generalConsentDateKey)
    }

    // MARK: - Per-Feature API Consent

    /// Whether the user has explicitly consented to sending conversation text to Anthropic's Claude API
    var hasConsentedChatAPI: Bool {
        UserDefaults.standard.bool(forKey: chatAPIConsentKey)
    }

    /// Whether the user has explicitly consented to uploading photos to Reality Defender's API
    var hasConsentedPhotoAPI: Bool {
        UserDefaults.standard.bool(forKey: photoAPIConsentKey)
    }

    func acceptChatAPIConsent() {
        UserDefaults.standard.set(true, forKey: chatAPIConsentKey)
    }

    func acceptPhotoAPIConsent() {
        UserDefaults.standard.set(true, forKey: photoAPIConsentKey)
    }

    // MARK: - Revoke All

    func revokeConsent() {
        UserDefaults.standard.removeObject(forKey: generalConsentKey)
        UserDefaults.standard.removeObject(forKey: generalConsentDateKey)
        UserDefaults.standard.removeObject(forKey: chatAPIConsentKey)
        UserDefaults.standard.removeObject(forKey: photoAPIConsentKey)
    }
}
