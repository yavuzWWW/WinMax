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
        Enabled: \(settings.enabled ? "yes" : "no")
        Green button override: \(settings.overrideGreenButton ? "yes" : "no")
        Title-bar double click: \(settings.titleBarDoubleClick ? "yes" : "no")
        Fullscreen shortcut override: \(settings.overrideFullscreenShortcut ? "yes" : "no")
        Launch at login: \(LaunchAtLoginManager.shared.isEnabled ? "yes" : "no")
        Log: \(WinMaxLogger.shared.logFile.path)
        """
    }
}
