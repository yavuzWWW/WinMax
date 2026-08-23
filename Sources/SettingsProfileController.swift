import Cocoa
import UniformTypeIdentifiers

final class SettingsProfileController {
    static let shared = SettingsProfileController()

    private let settings = SettingsStore.shared
    private let maximumImportSize = 64 * 1024

    private init() {}

    func exportSettings(presenting window: NSWindow?) {
        let panel = NSSavePanel()
        panel.title = "Export WinMax Settings"
        panel.nameFieldStringValue = "WinMax-Settings.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        present(panel, window: window) { [weak self] response in
            guard response == .OK, let destination = panel.url, let self else { return }
            do {
                let data = try self.settings.exportProfileData()
                try data.write(to: destination, options: .atomic)
                self.showInfo(
                    "Settings exported",
                    detail: "Your WinMax behavior settings were saved successfully.",
                    window: window
                )
            } catch {
                self.showError("Couldn’t export settings", detail: error.localizedDescription, window: window)
            }
        }
    }

    func importSettings(presenting window: NSWindow?) {
        let panel = NSOpenPanel()
        panel.title = "Import WinMax Settings"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        present(panel, window: window) { [weak self] response in
            guard response == .OK, let source = panel.url, let self else { return }
            do {
                let resourceValues = try source.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                guard resourceValues.isRegularFile == true else {
                    throw SettingsProfileUIError.notRegularFile
                }
                if let size = resourceValues.fileSize, size > self.maximumImportSize {
                    throw SettingsProfileUIError.fileTooLarge
                }

                let data = try Data(contentsOf: source, options: [.mappedIfSafe])
                guard data.count <= self.maximumImportSize else {
                    throw SettingsProfileUIError.fileTooLarge
                }
                try self.settings.importProfileData(data)
                self.showInfo(
                    "Settings imported",
                    detail: "Your WinMax behavior settings are now active.",
                    window: window
                )
            } catch {
                self.showError("Couldn’t import settings", detail: error.localizedDescription, window: window)
            }
        }
    }

    func resetSettings(presenting window: NSWindow?) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Reset WinMax settings?"
        alert.informativeText = "This restores window-control and Menu Vault behavior to defaults. Accessibility permission, onboarding state and Launch at Login are not changed."
        alert.addButton(withTitle: "Reset Settings")
        alert.addButton(withTitle: "Cancel")

        present(alert, window: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            self.settings.resetBehaviorToDefaults()
            AeroSnapManager.shared.cancel()
            self.showInfo(
                "Settings reset",
                detail: "WinMax behavior settings were restored to their defaults.",
                window: window
            )
        }
    }

    private func present(_ panel: NSSavePanel, window: NSWindow?, completion: @escaping (NSApplication.ModalResponse) -> Void) {
        if let window, window.isVisible {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(panel.runModal())
        }
    }

    private func present(_ alert: NSAlert, window: NSWindow?, completion: @escaping (NSApplication.ModalResponse) -> Void) {
        if let window, window.isVisible {
            alert.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(alert.runModal())
        }
    }

    private func showInfo(_ title: String, detail: String, window: NSWindow?) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: "OK")
        present(alert, window: window) { _ in }
    }

    private func showError(_ title: String, detail: String, window: NSWindow?) {
        WinMaxLogger.shared.warning("Settings profile operation failed")
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: "OK")
        present(alert, window: window) { _ in }
    }
}

private enum SettingsProfileUIError: LocalizedError {
    case notRegularFile
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .notRegularFile:
            return "The selected settings file is not a regular file."
        case .fileTooLarge:
            return "The selected settings file is unexpectedly large and was not opened."
        }
    }
}
