import SwiftUI

extension Color {
    static let loveLlamaPrimary = Color("AccentColor")
    static let riskLow = Color.green
    static let riskMedium = Color.yellow
    static let riskHigh = Color.orange
    static let riskCritical = Color.red
}

extension Date {
    var relativeDisplay: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

extension Double {
    var percentString: String {
        "\(Int(self * 100))%"
    }
}
