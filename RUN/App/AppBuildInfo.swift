import Foundation

struct AppBuildInfo: Sendable, Equatable {
    let appName: String
    let version: String
    let buildNumber: String
    let commitSHA: String
    let bundleIdentifier: String

    var versionDisplay: String {
        "\(version) (\(buildNumber))"
    }

    static func current(bundle: Bundle = .main) -> AppBuildInfo {
        let info = bundle.infoDictionary ?? [:]
        let appName = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? "RUN"
        let version = (info["CFBundleShortVersionString"] as? String) ?? "1.0.0"
        let buildNumber = (info["CFBundleVersion"] as? String) ?? "1"
        let rawSHA = (info["RunGitCommitSHA"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let commitSHA = (rawSHA?.isEmpty == false ? rawSHA : nil) ?? "dev"
        let bundleID = bundle.bundleIdentifier ?? "com.kiddo56.run"

        return AppBuildInfo(
            appName: appName,
            version: version,
            buildNumber: buildNumber,
            commitSHA: commitSHA,
            bundleIdentifier: bundleID
        )
    }
}
