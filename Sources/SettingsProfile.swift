import Foundation

struct WinMaxSettingsProfile: Codable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let enabled: Bool
    let overrideGreenButton: Bool
    let titleBarDoubleClick: Bool
    let overrideFullscreenShortcut: Bool
    let aeroSnapEnabled: Bool
    let menuVaultEnabled: Bool
    let showWindowOnLaunch: Bool

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        enabled: Bool,
        overrideGreenButton: Bool,
        titleBarDoubleClick: Bool,
        overrideFullscreenShortcut: Bool,
        aeroSnapEnabled: Bool,
        menuVaultEnabled: Bool,
        showWindowOnLaunch: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.enabled = enabled
        self.overrideGreenButton = overrideGreenButton
        self.titleBarDoubleClick = titleBarDoubleClick
        self.overrideFullscreenShortcut = overrideFullscreenShortcut
        self.aeroSnapEnabled = aeroSnapEnabled
        self.menuVaultEnabled = menuVaultEnabled
        self.showWindowOnLaunch = showWindowOnLaunch
    }

    func validated() throws -> WinMaxSettingsProfile {
        guard schemaVersion > 0 else {
            throw WinMaxSettingsProfileError.invalidSchema
        }
        guard schemaVersion <= Self.currentSchemaVersion else {
            throw WinMaxSettingsProfileError.newerSchema(schemaVersion)
        }
        return self
    }
}

enum WinMaxSettingsProfileError: LocalizedError, Equatable {
    case invalidSchema
    case newerSchema(Int)

    var errorDescription: String? {
        switch self {
        case .invalidSchema:
            return "This WinMax settings file has an invalid schema version."
        case .newerSchema(let version):
            return "This settings file uses schema \(version), which is newer than this version of WinMax supports."
        }
    }
}
