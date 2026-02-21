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
    case loveBombing
    case urgencyPressure
    case financialRequest
    case isolationTactics
    case inconsistentDetails
    case refusingVideoCall
    case militaryDeploymentStory
    case moveOffPlatform
    case tooGoodToBeTrue
    case grammarScriptedResponses
    case pigButchering
    case sextortionSetup
    case emotionalManipulation
    case tragicBackstory
    case futurePromises
    case aiGeneratedText

    var displayName: String {
        switch self {
        case .loveBombing: return "Love Bombing"
        case .urgencyPressure: return "Urgency & Pressure"
        case .financialRequest: return "Financial Request"
        case .isolationTactics: return "Isolation Tactics"
        case .inconsistentDetails: return "Inconsistent Details"
        case .refusingVideoCall: return "Refusing Video Calls"
        case .militaryDeploymentStory: return "Military/Deployment Story"
        case .moveOffPlatform: return "Moving Off Platform"
        case .tooGoodToBeTrue: return "Too Good to Be True"
        case .grammarScriptedResponses: return "Scripted Responses"
        case .pigButchering: return "Pig Butchering Scam"
        case .sextortionSetup: return "Sextortion Setup"
        case .emotionalManipulation: return "Emotional Manipulation"
        case .tragicBackstory: return "Tragic Backstory"
        case .futurePromises: return "Future Promises"
        case .aiGeneratedText: return "AI-Generated Text"
        }
    }

    var icon: String {
        switch self {
        case .loveBombing: return "heart.fill"
        case .urgencyPressure: return "clock.badge.exclamationmark"
        case .financialRequest: return "dollarsign.circle.fill"
        case .isolationTactics: return "person.crop.circle.badge.minus"
        case .inconsistentDetails: return "questionmark.circle.fill"
        case .refusingVideoCall: return "video.slash.fill"
        case .militaryDeploymentStory: return "shield.fill"
        case .moveOffPlatform: return "arrow.right.circle.fill"
        case .tooGoodToBeTrue: return "sparkles"
        case .grammarScriptedResponses: return "text.bubble.fill"
        case .pigButchering: return "chart.line.uptrend.xyaxis"
        case .sextortionSetup: return "eye.slash.fill"
        case .emotionalManipulation: return "theatermasks.fill"
        case .tragicBackstory: return "heart.slash.fill"
        case .futurePromises: return "airplane.departure"
        case .aiGeneratedText: return "cpu.fill"
        }
    }

    /// How dangerous this pattern is (used for weighted scoring)
    var weight: Double {
        switch self {
        case .financialRequest: return 5.0
        case .pigButchering: return 5.0
        case .emotionalManipulation: return 4.0
        case .urgencyPressure: return 4.0
        case .sextortionSetup: return 4.0
        case .isolationTactics: return 3.5
        case .militaryDeploymentStory: return 3.5
        case .loveBombing: return 3.0
        case .tragicBackstory: return 3.0
        case .refusingVideoCall: return 3.0
        case .moveOffPlatform: return 2.5
        case .futurePromises: return 2.5
        case .tooGoodToBeTrue: return 2.0
        case .inconsistentDetails: return 2.0
        case .grammarScriptedResponses: return 1.5
        case .aiGeneratedText: return 3.5
        }
    }
}

enum AnalysisSource: String, Codable {
    case paste, screenshot
}
