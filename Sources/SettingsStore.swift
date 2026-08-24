import Foundation

final class SettingsStore {
    static let shared = SettingsStore()

    private enum Key {
        static let enabled = "enabled"
        static let overrideGreenButton = "overrideGreenButton"
        static let titleBarDoubleClick = "titleBarDoubleClick"
        static let overrideFullscreenShortcut = "overrideFullscreenShortcut"
        static let aeroSnapEnabled = "aeroSnapEnabled"
        static let layoutShortcutsEnabled = "layoutShortcutsEnabled"
        static let menuVaultEnabled = "menuVaultEnabled"
        static let showWindowOnLaunch = "showWindowOnLaunch"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let settingsSchemaVersion = "settingsSchemaVersion"
    }

    private static let registeredDefaults: [String: Any] = [
        Key.enabled: true,
        Key.overrideGreenButton: true,
        Key.titleBarDoubleClick: true,
        Key.overrideFullscreenShortcut: true,
        Key.aeroSnapEnabled: true,
        Key.layoutShortcutsEnabled: true,
        Key.menuVaultEnabled: true,
        Key.showWindowOnLaunch: false,
        Key.hasCompletedOnboarding: false,
        Key.settingsSchemaVersion: WinMaxSettingsProfile.currentSchemaVersion
    ]

    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: Self.registeredDefaults)
        migrateIfNeeded()
    }

    var enabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { defaults.set(newValue, forKey: Key.enabled); notify() }
    }

    var overrideGreenButton: Bool {
        get { defaults.bool(forKey: Key.overrideGreenButton) }
        set { defaults.set(newValue, forKey: Key.overrideGreenButton); notify() }
    }

    var titleBarDoubleClick: Bool {
        get { defaults.bool(forKey: Key.titleBarDoubleClick) }
        set { defaults.set(newValue, forKey: Key.titleBarDoubleClick); notify() }
    }

    var overrideFullscreenShortcut: Bool {
        get { defaults.bool(forKey: Key.overrideFullscreenShortcut) }
        set { defaults.set(newValue, forKey: Key.overrideFullscreenShortcut); notify() }
    }

    var aeroSnapEnabled: Bool {
        get { defaults.bool(forKey: Key.aeroSnapEnabled) }
        set { defaults.set(newValue, forKey: Key.aeroSnapEnabled); notify() }
    }

    var layoutShortcutsEnabled: Bool {
        get { defaults.bool(forKey: Key.layoutShortcutsEnabled) }
        set { defaults.set(newValue, forKey: Key.layoutShortcutsEnabled); notify() }
    }

    var menuVaultEnabled: Bool {
        get { defaults.bool(forKey: Key.menuVaultEnabled) }
        set { defaults.set(newValue, forKey: Key.menuVaultEnabled); notify() }
    }

    var showWindowOnLaunch: Bool {
        get { defaults.bool(forKey: Key.showWindowOnLaunch) }
        set { defaults.set(newValue, forKey: Key.showWindowOnLaunch); notify() }
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding) }
    }

    var profile: WinMaxSettingsProfile {
        WinMaxSettingsProfile(
            enabled: enabled,
            overrideGreenButton: overrideGreenButton,
            titleBarDoubleClick: titleBarDoubleClick,
            overrideFullscreenShortcut: overrideFullscreenShortcut,
            aeroSnapEnabled: aeroSnapEnabled,
            menuVaultEnabled: menuVaultEnabled,
            showWindowOnLaunch: showWindowOnLaunch,
            layoutShortcutsEnabled: layoutShortcutsEnabled
        )
    }

    func exportProfileData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(profile)
    }

    func importProfileData(_ data: Data) throws {
        let profile = try JSONDecoder().decode(WinMaxSettingsProfile.self, from: data).validated()
        apply(profile)
    }

    func apply(_ profile: WinMaxSettingsProfile) {
        defaults.set(profile.enabled, forKey: Key.enabled)
        defaults.set(profile.overrideGreenButton, forKey: Key.overrideGreenButton)
        defaults.set(profile.titleBarDoubleClick, forKey: Key.titleBarDoubleClick)
        defaults.set(profile.overrideFullscreenShortcut, forKey: Key.overrideFullscreenShortcut)
        defaults.set(profile.aeroSnapEnabled, forKey: Key.aeroSnapEnabled)
        defaults.set(profile.layoutShortcutsEnabled, forKey: Key.layoutShortcutsEnabled)
        defaults.set(profile.menuVaultEnabled, forKey: Key.menuVaultEnabled)
        defaults.set(profile.showWindowOnLaunch, forKey: Key.showWindowOnLaunch)
        defaults.set(WinMaxSettingsProfile.currentSchemaVersion, forKey: Key.settingsSchemaVersion)
        notify()
    }

    func resetBehaviorToDefaults() {
        for key in [
            Key.enabled,
            Key.overrideGreenButton,
            Key.titleBarDoubleClick,
            Key.overrideFullscreenShortcut,
            Key.aeroSnapEnabled,
            Key.layoutShortcutsEnabled,
            Key.menuVaultEnabled,
            Key.showWindowOnLaunch
        ] {
            defaults.removeObject(forKey: key)
        }
        defaults.set(WinMaxSettingsProfile.currentSchemaVersion, forKey: Key.settingsSchemaVersion)
        notify()
    }

    private func migrateIfNeeded() {
        let stored = defaults.integer(forKey: Key.settingsSchemaVersion)
        if stored < WinMaxSettingsProfile.currentSchemaVersion {
            // New settings use registered defaults unless a previous value already exists.
            defaults.set(WinMaxSettingsProfile.currentSchemaVersion, forKey: Key.settingsSchemaVersion)
        }
    }

    private func notify() {
        NotificationCenter.default.post(name: .winMaxSettingsChanged, object: nil)
    }
}

extension Notification.Name {
    static let winMaxSettingsChanged = Notification.Name("WinMaxSettingsChanged")
    static let winMaxRuntimeStateChanged = Notification.Name("WinMaxRuntimeStateChanged")
}
