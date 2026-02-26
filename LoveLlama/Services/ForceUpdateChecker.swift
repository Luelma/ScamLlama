import Foundation

struct ForceUpdateChecker {
    static let appStoreID = "6759401280"
    static let versionURL = URL(string: "https://gist.githubusercontent.com/mkonopinski810/dc598476815a301faeccde950194ece9/raw/version.json")!

    struct VersionInfo: Decodable {
        let minimum_version: String
        let message: String
    }

    /// Returns (needsUpdate, message) — checks remote version.json against the running app version.
    static func check() async -> (needsUpdate: Bool, message: String) {
        do {
            let (data, _) = try await URLSession.shared.data(from: versionURL)
            let info = try JSONDecoder().decode(VersionInfo.self, from: data)

            let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

            if compareVersions(current, isOlderThan: info.minimum_version) {
                return (true, info.message)
            }
        } catch {
            // If the check fails (no network, etc.), don't block the user
        }
        return (false, "")
    }

    static var appStoreURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)")!
    }

    /// Returns true if version `a` is strictly older than version `b`.
    private static func compareVersions(_ a: String, isOlderThan b: String) -> Bool {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }
        let count = max(aParts.count, bParts.count)
        for i in 0..<count {
            let aVal = i < aParts.count ? aParts[i] : 0
            let bVal = i < bParts.count ? bParts[i] : 0
            if aVal < bVal { return true }
            if aVal > bVal { return false }
        }
        return false
    }
}
