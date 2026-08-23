import Cocoa
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var enabledItem: NSMenuItem!
    private var statusItemLabel: NSMenuItem!
    private var settingsWindowController: SettingsWindowController!
    private var onboardingWindowController: OnboardingWindowController!
    private let aboutWindowController = AboutWindowController.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        WinMaxLogger.shared.info("Application launched")

        settingsWindowController = SettingsWindowController()
        onboardingWindowController = OnboardingWindowController()
        setupMenuBar()

        WindowController.shared.start()
        AeroSnapManager.shared.start()
        MenuVaultController.shared.start()
        LayoutShortcutController.shared.start()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshMenu),
            name: .winMaxSettingsChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshMenu),
            name: .winMaxRuntimeStateChanged,
            object: nil
        )

        let settings = SettingsStore.shared
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !settings.hasCompletedOnboarding {
                self.onboardingWindowController.show()
            } else if settings.showWindowOnLaunch || !AXIsProcessTrusted() {
                self.settingsWindowController.show()
            }
        }
        refreshMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        LayoutShortcutController.shared.stop()
        MenuVaultController.shared.stop()
        AeroSnapManager.shared.stop()
        WindowController.shared.stop()
        WinMaxLogger.shared.info("Application terminating")
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = "WinMax.Main"
        if let image = NSImage(
            systemSymbolName: "rectangle.inset.filled",
            accessibilityDescription: "WinMax"
        ) {
            image.isTemplate = true
            statusItem.button?.image = image
        } else {
            statusItem.button?.title = "W"
        }
        statusItem.button?.toolTip = "WinMax"

        let menu = NSMenu()
        let open = NSMenuItem(title: "Open WinMax", action: #selector(openSettings), keyEquivalent: ",")
        open.target = self
        menu.addItem(open)

        let vault = NSMenuItem(title: "Open Menu Vault…", action: #selector(openMenuVault), keyEquivalent: "")
        vault.target = self
        menu.addItem(vault)

        let setup = NSMenuItem(title: "Run Setup Again…", action: #selector(openOnboarding), keyEquivalent: "")
        setup.target = self
        menu.addItem(setup)

        statusItemLabel = NSMenuItem(title: "Status", action: nil, keyEquivalent: "")
        statusItemLabel.isEnabled = false
        menu.addItem(statusItemLabel)
        menu.addItem(.separator())

        enabledItem = NSMenuItem(title: "Window Control Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.target = self
        menu.addItem(enabledItem)

        let layouts = NSMenuItem(title: "Window Layout", action: nil, keyEquivalent: "")
        let layoutMenu = NSMenu(title: "Window Layout")
        addLayoutItem("Left Half", action: #selector(layoutLeft), shortcut: "⌃⌥⌘←", to: layoutMenu)
        addLayoutItem("Right Half", action: #selector(layoutRight), shortcut: "⌃⌥⌘→", to: layoutMenu)
        addLayoutItem("Maximize", action: #selector(layoutMaximize), shortcut: "⌃⌥⌘↑", to: layoutMenu)
        addLayoutItem("Restore", action: #selector(layoutRestore), shortcut: "⌃⌥⌘↓", to: layoutMenu)
        layoutMenu.addItem(.separator())
        addLayoutItem("Previous Display", action: #selector(movePreviousDisplay), shortcut: "⇧⌃⌥⌘←", to: layoutMenu)
        addLayoutItem("Next Display", action: #selector(moveNextDisplay), shortcut: "⇧⌃⌥⌘→", to: layoutMenu)
        layouts.submenu = layoutMenu
        menu.addItem(layouts)

        let maximize = NSMenuItem(title: "Maximize / Restore Front Window", action: #selector(toggleFrontWindow), keyEquivalent: "")
        maximize.target = self
        menu.addItem(maximize)

        let restore = NSMenuItem(title: "Restore Front Window", action: #selector(restoreFrontWindow), keyEquivalent: "")
        restore.target = self
        menu.addItem(restore)

        menu.addItem(.separator())
        let settingsManagement = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        let settingsSubmenu = NSMenu(title: "Settings")

        let export = NSMenuItem(title: "Export Settings…", action: #selector(exportSettings), keyEquivalent: "")
        export.target = self
        settingsSubmenu.addItem(export)

        let importItem = NSMenuItem(title: "Import Settings…", action: #selector(importSettings), keyEquivalent: "")
        importItem.target = self
        settingsSubmenu.addItem(importItem)
        settingsSubmenu.addItem(.separator())

        let reset = NSMenuItem(title: "Reset to Defaults…", action: #selector(resetSettings), keyEquivalent: "")
        reset.target = self
        settingsSubmenu.addItem(reset)
        settingsManagement.submenu = settingsSubmenu
        menu.addItem(settingsManagement)

        let permissions = NSMenuItem(title: "Accessibility Settings…", action: #selector(openAccessibility), keyEquivalent: "")
        permissions.target = self
        menu.addItem(permissions)

        let logs = NSMenuItem(title: "Open Debug Logs", action: #selector(openLogs), keyEquivalent: "")
        logs.target = self
        menu.addItem(logs)

        menu.addItem(.separator())
        let updates = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        updates.target = self
        menu.addItem(updates)

        let support = NSMenuItem(title: "Support…", action: #selector(openSupport), keyEquivalent: "")
        support.target = self
        menu.addItem(support)

        let about = NSMenuItem(title: "About WinMax", action: #selector(openAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit WinMax", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    private func addLayoutItem(_ title: String, action: Selector, shortcut: String, to menu: NSMenu) {
        let item = NSMenuItem(title: "\(title)    \(shortcut)", action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    @objc private func refreshMenu() {
        let settings = SettingsStore.shared
        enabledItem?.state = settings.enabled ? .on : .off

        if !AXIsProcessTrusted() {
            statusItemLabel?.title = "● Accessibility needed"
        } else if !WindowController.shared.isEventTapInstalled {
            statusItemLabel?.title = "● Starting…"
        } else if !settings.enabled {
            statusItemLabel?.title = settings.menuVaultEnabled
                ? "● Window control paused · Vault available"
                : "● Paused"
        } else {
            statusItemLabel?.title = "● Active"
        }
    }

    @objc private func openSettings() {
        settingsWindowController.show()
    }

    @objc private func openMenuVault() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            MenuVaultController.shared.show()
        }
    }

    @objc private func openOnboarding() {
        onboardingWindowController.show()
    }

    @objc private func openAbout() {
        aboutWindowController.show()
    }

    @objc private func checkForUpdates() {
        UpdateChecker.shared.checkForUpdates(presenting: settingsWindowController.window)
    }

    @objc private func openSupport() {
        NSWorkspace.shared.open(WinMaxProduct.supportURL)
    }

    @objc private func exportSettings() {
        SettingsProfileController.shared.exportSettings(presenting: settingsWindowController.window)
    }

    @objc private func importSettings() {
        SettingsProfileController.shared.importSettings(presenting: settingsWindowController.window)
    }

    @objc private func resetSettings() {
        SettingsProfileController.shared.resetSettings(presenting: settingsWindowController.window)
    }

    @objc private func layoutLeft() {
        WindowLayoutCommandController.shared.apply(.leftHalf)
    }

    @objc private func layoutRight() {
        WindowLayoutCommandController.shared.apply(.rightHalf)
    }

    @objc private func layoutMaximize() {
        WindowLayoutCommandController.shared.apply(.maximize)
    }

    @objc private func layoutRestore() {
        WindowLayoutCommandController.shared.restore()
    }

    @objc private func movePreviousDisplay() {
        WindowLayoutCommandController.shared.moveToDisplay(.previous)
    }

    @objc private func moveNextDisplay() {
        WindowLayoutCommandController.shared.moveToDisplay(.next)
    }

    @objc private func toggleEnabled() {
        SettingsStore.shared.enabled.toggle()
        WinMaxLogger.shared.info(
            "Window control toggled from menu: \(SettingsStore.shared.enabled)"
        )
    }

    @objc private func toggleFrontWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            WindowController.shared.toggleFrontmostWindow()
        }
    }

    @objc private func restoreFrontWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            WindowController.shared.restoreFrontmostWindow()
        }
    }

    @objc private func openAccessibility() {
        WindowController.shared.openAccessibilitySettings()
    }

    @objc private func openLogs() {
        NSWorkspace.shared.open(WinMaxLogger.shared.logDirectory)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
