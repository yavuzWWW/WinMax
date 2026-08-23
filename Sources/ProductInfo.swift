import Foundation

enum WinMaxProduct {
    static let name = "WinMax"
    static let tagline = "Windows-style desktop control for macOS"
    static let company = "Vast Hosting"
    static let websiteURL = URL(string: "https://vasthosting.cloud")!
    static let repositoryURL = URL(string: "https://github.com/yavuzWWW/WinMax")!
    static let releasesURL = URL(string: "https://github.com/yavuzWWW/WinMax/releases")!
    static let supportURL = URL(string: "https://github.com/yavuzWWW/WinMax/issues")!
    static let latestReleaseAPIURL = URL(string: "https://api.github.com/repos/yavuzWWW/WinMax/releases/latest")!

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "dev"
    }

    static var displayVersion: String {
        "\(version) (\(build))"
    }
}

enum WinMaxFeatureTier: String {
    case core = "Core"
    case advanced = "Advanced"
}

struct WinMaxFeatureDefinition {
    let id: String
    let name: String
    let tier: WinMaxFeatureTier
}

enum WinMaxFeatureCatalog {
    // This is product metadata only. No feature is paywalled in the current release.
    static let all: [WinMaxFeatureDefinition] = [
        .init(id: "desktop-maximize", name: "Desktop Maximize", tier: .core),
        .init(id: "aero-snap", name: "Aero Snap", tier: .core),
        .init(id: "menu-vault", name: "Menu Vault", tier: .core),
        .init(id: "launch-at-login", name: "Launch at Login", tier: .core)
    ]
}
