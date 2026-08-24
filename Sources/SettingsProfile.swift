import Foundation

struct WinMaxSettingsProfile: Codable, Equatable {
    static let currentSchemaVersion = 3

    let schemaVersion: Int
    let enabled: Bool
    let overrideGreenButton: Bool
    let titleBarDoubleClick: Bool
    let overrideFullscreenShortcut: Bool
    let aeroSnapEnabled: Bool
    let menuVaultEnabled: Bool
    let showWindowOnLaunch: Bool
    let layoutShortcutsEnabled: Bool
    let menuBarHiddenSectionEnabled: Bool

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        enabled: Bool,
        overrideGreenButton: Bool,
        titleBarDoubleClick: Bool,
        overrideFullscreenShortcut: Bool,
        aeroSnapEnabled: Bool,
        menuVaultEnabled: Bool,
        showWindowOnLaunch: Bool,
        layoutShortcutsEnabled: Bool = true,
        menuBarHiddenSectionEnabled: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.enabled = enabled
        self.overrideGreenButton = overrideGreenButton
        self.titleBarDoubleClick = titleBarDoubleClick
        self.overrideFullscreenShortcut = overrideFullscreenShortcut
        self.aeroSnapEnabled = aeroSnapEnabled
        self.menuVaultEnabled = menuVaultEnabled
        self.showWindowOnLaunch = showWindowOnLaunch
        self.layoutShortcutsEnabled = layoutShortcutsEnabled
        self.menuBarHiddenSectionEnabled = menuBarHiddenSectionEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        enabled = try container.decode(Bool.self, forKey: .enabled)
        overrideGreenButton = try container.decode(Bool.self, forKey: .overrideGreenButton)
        titleBarDoubleClick = try container.decode(Bool.self, forKey: .titleBarDoubleClick)
        overrideFullscreenShortcut = try container.decode(Bool.self, forKey: .overrideFullscreenShortcut)
        aeroSnapEnabled = try container.decode(Bool.self, forKey: .aeroSnapEnabled)
        menuVaultEnabled = try container.decode(Bool.self, forKey: .menuVaultEnabled)
        showWindowOnLaunch = try container.decode(Bool.self, forKey: .showWindowOnLaunch)
        layoutShortcutsEnabled = try container.decodeIfPresent(Bool.self, forKey: .layoutShortcutsEnabled) ?? true
        menuBarHiddenSectionEnabled = try container.decodeIfPresent(Bool.self, forKey: .menuBarHiddenSectionEnabled) ?? false
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
