import Cocoa

final class MenuBarSectionController {
    static let shared = MenuBarSectionController()

    private let expandedLength: CGFloat = 18
    private let minimumCollapsedLength: CGFloat = 500
    private let maximumCollapsedLength: CGFloat = 10_000

    private var separatorItem: NSStatusItem?
    private var settingsObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?

    private(set) var isCollapsed = false

    private init() {}

    func start() {
        createSeparatorIfNeeded()

        if settingsObserver == nil {
            settingsObserver = NotificationCenter.default.addObserver(
                forName: .winMaxSettingsChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.applySettings()
            }
        }

        if screenObserver == nil {
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.screenConfigurationChanged()
            }
        }

        // Always launch expanded. This avoids swallowing status items from apps
        // that start later during login. Collapsing is an explicit user action.
        expand()
        applySettings()
    }

    func stop() {
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        settingsObserver = nil
        screenObserver = nil

        if let separatorItem {
            NSStatusBar.system.removeStatusItem(separatorItem)
        }
        separatorItem = nil
        isCollapsed = false
    }

    func toggle() {
        guard SettingsStore.shared.menuBarHiddenSectionEnabled else { return }
        isCollapsed ? expand() : collapse()
    }

    func collapse() {
        guard SettingsStore.shared.menuBarHiddenSectionEnabled else { return }
        createSeparatorIfNeeded()
        separatorItem?.length = collapsedLength()
        separatorItem?.button?.title = ""
        separatorItem?.button?.image = nil
        separatorItem?.button?.isEnabled = false
        isCollapsed = true
        notifyStateChanged()
    }

    func expand() {
        createSeparatorIfNeeded()
        separatorItem?.length = expandedLength
        configureExpandedButton()
        isCollapsed = false
        notifyStateChanged()
    }

    private func createSeparatorIfNeeded() {
        guard separatorItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: expandedLength)
        item.autosaveName = "WinMax.MenuVault.HiddenBoundary"
        item.isVisible = true
        separatorItem = item
        configureExpandedButton()
    }

    private func configureExpandedButton() {
        guard let button = separatorItem?.button else { return }
        button.title = "│"
        button.image = nil
        button.font = .systemFont(ofSize: 12, weight: .medium)
        button.toolTip = "WinMax hidden-item boundary — Command-drag menu-bar items to its left"
        button.target = self
        button.action = #selector(separatorPressed)
        button.isEnabled = true
    }

    private func applySettings() {
        createSeparatorIfNeeded()
        let enabled = SettingsStore.shared.menuBarHiddenSectionEnabled
        separatorItem?.isVisible = enabled
        if !enabled && isCollapsed {
            expand()
            separatorItem?.isVisible = false
        } else if !enabled {
            separatorItem?.isVisible = false
        } else {
            separatorItem?.isVisible = true
        }
        notifyStateChanged()
    }

    private func screenConfigurationChanged() {
        guard isCollapsed else { return }
        separatorItem?.length = collapsedLength()
    }

    private func collapsedLength() -> CGFloat {
        let widest = NSScreen.screens.map(\.frame.width).max() ?? minimumCollapsedLength
        return max(
            minimumCollapsedLength,
            min(widest * 2, maximumCollapsedLength)
        )
    }

    private func notifyStateChanged() {
        NotificationCenter.default.post(name: .winMaxMenuBarSectionStateChanged, object: nil)
    }

    @objc private func separatorPressed() {
        collapse()
    }
}

extension Notification.Name {
    static let winMaxMenuBarSectionStateChanged = Notification.Name("WinMaxMenuBarSectionStateChanged")
}
