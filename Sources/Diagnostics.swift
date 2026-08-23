import Cocoa
import ApplicationServices

struct Diagnostics {
    static func report() -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info["CFBundleVersion"] as? String ?? "unknown"
        let arch: String
        #if arch(arm64)
        arch = "arm64"
        #elseif arch(x86_64)
        arch = "x86_64"
        #else
        arch = "unknown"
        #endif

        let settings = SettingsStore.shared
        let launchStatus = LaunchAtLoginManager.shared.requiresApproval
            ? "requires approval"
            : (LaunchAtLoginManager.shared.isEnabled ? "enabled" : "disabled")

        return """
        WinMax diagnostics
        ------------------
        Version: \(version) (\(build))
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Architecture: \(arch)
        Bundle: \(Bundle.main.bundlePath)
        Accessibility trusted: \(AXIsProcessTrusted() ? "yes" : "no")
        Event tap installed: \(WindowController.shared.isEventTapInstalled ? "yes" : "no")
        Event tap active: \(WindowController.shared.isEventTapActive ? "yes" : "no")
        Window control enabled: \(settings.enabled ? "yes" : "no")
        Green button override: \(settings.overrideGreenButton ? "yes" : "no")
        Title-bar double click: \(settings.titleBarDoubleClick ? "yes" : "no")
        Fullscreen shortcut override: \(settings.overrideFullscreenShortcut ? "yes" : "no")
        Aero Snap: \(settings.aeroSnapEnabled ? "enabled" : "disabled")
        Managed window layouts: \(WindowLayoutStore.shared.managedWindowCount)
        Menu Vault: \(settings.menuVaultEnabled ? "enabled" : "disabled")
        Menu Vault indexed items: \(MenuVaultController.shared.indexedItemCount)
        Launch at login: \(launchStatus)
        Log: \(WinMaxLogger.shared.logFile.path)
        """
    }
}
