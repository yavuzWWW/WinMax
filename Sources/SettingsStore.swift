import Foundation

final class SettingsStore {
    static let shared = SettingsStore()

    private enum Key {
        static let enabled = "enabled"
        static let overrideGreenButton = "overrideGreenButton"
        static let titleBarDoubleClick = "titleBarDoubleClick"
        static let overrideFullscreenShortcut = "overrideFullscreenShortcut"
        static let aeroSnapEnabled = "aeroSnapEnabled"
        static let menuVaultEnabled = "menuVaultEnabled"
        static let showWindowOnLaunch = "showWindowOnLaunch"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            Key.enabled: true,
            Key.overrideGreenButton: true,
            Key.titleBarDoubleClick: true,
            Key.overrideFullscreenShortcut: true,
            Key.aeroSnapEnabled: true,
            Key.menuVaultEnabled: true,
            Key.showWindowOnLaunch: false,
            Key.hasCompletedOnboarding: false
        ])
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

    private func notify() {
        NotificationCenter.default.post(name: .winMaxSettingsChanged, object: nil)
    }
}

extension Notification.Name {
    static let winMaxSettingsChanged = Notification.Name("WinMaxSettingsChanged")
    static let winMaxRuntimeStateChanged = Notification.Name("WinMaxRuntimeStateChanged")
}
