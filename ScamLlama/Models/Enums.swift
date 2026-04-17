import SwiftUI

enum RiskLevel: String, Codable, CaseIterable {
    case low, medium, high, critical

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }

    var label: String {
        switch self {
        case .low: return "Low Risk"
        case .medium: return "Medium Risk"
        case .high: return "High Risk"
        case .critical: return "Critical Risk"
        }
    }

    var icon: String {
        switch self {
        case .low: return "checkmark.shield"
        case .medium: return "exclamationmark.triangle"
        case .high: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.shield.fill"
        }
    }
}

enum ScamPatternType: String, Codable, CaseIterable {
    // Financial pressure & requests
    case financialRequest
    case urgencyPressure
    case upfrontPayment
    case unusualPaymentMethod
    case overpaymentRefund

    // Investment & crypto scams
    case fakeCryptoInvestment
    case guaranteedReturns
    case tradingPlatformScam
    case pigButcheringFinancial

    // Impersonation
    case bankImpersonation
    case governmentImpersonation
    case techSupportScam
    case utilityImpersonation

    // Phishing & account access
    case phishingAttempt
    case accountVerification
    case suspiciousLink
    case credentialHarvesting

    // Job & opportunity scams
    case fakeJobOffer
    case workFromHomeScam
    case reshippingMule

    // Prize & lottery scams
    case lotteryPrizeScam
    case inheritanceScam
    case sweepstakesScam

    // Threat & extortion
    case legalThreat
    case debtCollectionScam
    case blackmailExtortion

    // Social engineering
    case emotionalManipulation
    case charityScam
    case disasterReliefScam
    case rentalHousingScam

    // General red flags
    case tooGoodToBeTrue
    case inconsistentDetails
    case grammarScriptedResponses
    case aiGeneratedText
    case packageDeliveryScam

    var displayName: String {
        switch self {
        case .financialRequest: return "Financial Request"
        case .urgencyPressure: return "Urgency & Pressure"
        case .upfrontPayment: return "Upfront Payment Required"
        case .unusualPaymentMethod: return "Unusual Payment Method"
        case .overpaymentRefund: return "Overpayment / Refund Scam"
        case .fakeCryptoInvestment: return "Fake Crypto Investment"
        case .guaranteedReturns: return "Guaranteed Returns"
        case .tradingPlatformScam: return "Fake Trading Platform"
        case .pigButcheringFinancial: return "Pig Butchering (Investment)"
        case .bankImpersonation: return "Bank Impersonation"
        case .governmentImpersonation: return "Government Impersonation"
        case .techSupportScam: return "Tech Support Scam"
        case .utilityImpersonation: return "Utility Impersonation"
        case .phishingAttempt: return "Phishing Attempt"
        case .accountVerification: return "Account Verification Scam"
        case .suspiciousLink: return "Suspicious Link"
        case .credentialHarvesting: return "Credential Harvesting"
        case .fakeJobOffer: return "Fake Job Offer"
        case .workFromHomeScam: return "Work From Home Scam"
        case .reshippingMule: return "Reshipping / Money Mule"
        case .lotteryPrizeScam: return "Lottery / Prize Scam"
        case .inheritanceScam: return "Inheritance Scam"
        case .sweepstakesScam: return "Sweepstakes Scam"
        case .legalThreat: return "Legal Threat"
        case .debtCollectionScam: return "Fake Debt Collection"
        case .blackmailExtortion: return "Blackmail / Extortion"
        case .emotionalManipulation: return "Emotional Manipulation"
        case .charityScam: return "Charity Scam"
        case .disasterReliefScam: return "Disaster Relief Scam"
        case .rentalHousingScam: return "Rental / Housing Scam"
        case .tooGoodToBeTrue: return "Too Good to Be True"
        case .inconsistentDetails: return "Inconsistent Details"
        case .grammarScriptedResponses: return "Scripted Responses"
        case .aiGeneratedText: return "AI-Generated Text"
        case .packageDeliveryScam: return "Package Delivery Scam"
        }
    }

    var icon: String {
        switch self {
        case .financialRequest: return "dollarsign.circle.fill"
        case .urgencyPressure: return "clock.badge.exclamationmark"
        case .upfrontPayment: return "banknote.fill"
        case .unusualPaymentMethod: return "creditcard.trianglebadge.exclamationmark"
        case .overpaymentRefund: return "arrow.uturn.left.circle.fill"
        case .fakeCryptoInvestment: return "bitcoinsign.circle.fill"
        case .guaranteedReturns: return "chart.line.uptrend.xyaxis"
        case .tradingPlatformScam: return "chart.bar.fill"
        case .pigButcheringFinancial: return "chart.line.uptrend.xyaxis.circle.fill"
        case .bankImpersonation: return "building.columns.fill"
        case .governmentImpersonation: return "building.fill"
        case .techSupportScam: return "desktopcomputer"
        case .utilityImpersonation: return "bolt.fill"
        case .phishingAttempt: return "envelope.badge.shield.half.filled"
        case .accountVerification: return "person.badge.key.fill"
        case .suspiciousLink: return "link.badge.plus"
        case .credentialHarvesting: return "lock.open.fill"
        case .fakeJobOffer: return "briefcase.fill"
        case .workFromHomeScam: return "house.fill"
        case .reshippingMule: return "shippingbox.fill"
        case .lotteryPrizeScam: return "star.circle.fill"
        case .inheritanceScam: return "scroll.fill"
        case .sweepstakesScam: return "gift.fill"
        case .legalThreat: return "exclamationmark.shield.fill"
        case .debtCollectionScam: return "phone.badge.waveform.fill"
        case .blackmailExtortion: return "eye.slash.fill"
        case .emotionalManipulation: return "theatermasks.fill"
        case .charityScam: return "heart.fill"
        case .disasterReliefScam: return "cloud.bolt.fill"
        case .rentalHousingScam: return "house.lodge.fill"
        case .tooGoodToBeTrue: return "sparkles"
        case .inconsistentDetails: return "questionmark.circle.fill"
        case .grammarScriptedResponses: return "text.bubble.fill"
        case .aiGeneratedText: return "cpu.fill"
        case .packageDeliveryScam: return "box.truck.fill"
        }
    }

    var weight: Double {
        switch self {
        // Critical (5.0)
        case .financialRequest: return 5.0
        case .fakeCryptoInvestment: return 5.0
        case .pigButcheringFinancial: return 5.0
        case .credentialHarvesting: return 5.0
        case .blackmailExtortion: return 5.0

        // High (4.0)
        case .urgencyPressure: return 4.0
        case .upfrontPayment: return 4.0
        case .unusualPaymentMethod: return 4.0
        case .guaranteedReturns: return 4.0
        case .bankImpersonation: return 4.0
        case .governmentImpersonation: return 4.0
        case .phishingAttempt: return 4.0
        case .accountVerification: return 4.0
        case .legalThreat: return 4.0
        case .debtCollectionScam: return 4.0

        // Elevated (3.5)
        case .tradingPlatformScam: return 3.5
        case .techSupportScam: return 3.5
        case .overpaymentRefund: return 3.5
        case .suspiciousLink: return 3.5
        case .reshippingMule: return 3.5
        case .aiGeneratedText: return 3.5
        case .emotionalManipulation: return 3.5
        case .utilityImpersonation: return 3.5

        // Moderate (3.0)
        case .fakeJobOffer: return 3.0
        case .workFromHomeScam: return 3.0
        case .lotteryPrizeScam: return 3.0
        case .inheritanceScam: return 3.0
        case .sweepstakesScam: return 3.0
        case .charityScam: return 3.0
        case .disasterReliefScam: return 3.0
        case .rentalHousingScam: return 3.0
        case .packageDeliveryScam: return 3.0

        // Low-Moderate (2.0)
        case .tooGoodToBeTrue: return 2.0
        case .inconsistentDetails: return 2.0
        case .grammarScriptedResponses: return 1.5
        }
    }
}

enum AnalysisSource: String, Codable {
    case paste, screenshot
}

enum MediaType: String, Codable, CaseIterable {
    case photo, video, audio

    var label: String {
        switch self {
        case .photo: return "Photo"
        case .video: return "Video"
        case .audio: return "Voice"
        }
    }

    var icon: String {
        switch self {
        case .photo: return "person.crop.circle.badge.questionmark"
        case .video: return "video.fill"
        case .audio: return "mic.fill"
        }
    }

    var maxFileSize: Int {
        switch self {
        case .photo: return 20_000_000
        case .video: return 250_000_000
        case .audio: return 20_000_000
        }
    }

    var maxFileSizeLabel: String {
        switch self {
        case .photo: return "20 MB"
        case .video: return "250 MB"
        case .audio: return "20 MB"
        }
    }
}
