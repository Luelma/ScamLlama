import SwiftUI

struct BrandedNavTitle: View {
    let title: String
    let icon: String

    private let gradientColors: [Color] = [
        Color(red: 0.55, green: 0.11, blue: 0.53),
        Color(red: 0.93, green: 0.27, blue: 0.27)
    ]

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }
}

extension View {
    func brandedNavigationBar(title: String, icon: String) -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    BrandedNavTitle(title: title, icon: icon)
                }
            }
    }
}
