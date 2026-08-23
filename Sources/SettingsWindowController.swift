import Cocoa
import ApplicationServices

private enum Brand {
    static let background = NSColor(calibratedWhite: 0.055, alpha: 1)
    static let panel = NSColor(calibratedWhite: 0.085, alpha: 1)
    static let border = NSColor(calibratedWhite: 0.16, alpha: 1)
    static let text = NSColor(calibratedWhite: 0.96, alpha: 1)
    static let secondary = NSColor(calibratedWhite: 0.64, alpha: 1)
    static let accent = NSColor(calibratedRed: 0.27, green: 0.83, blue: 0.74, alpha: 1)
    static let warning = NSColor(calibratedRed: 1.0, green: 0.68, blue: 0.20, alpha: 1)
}

final class SettingsWindowController: NSWindowController {
    private let settings = SettingsStore.shared
    private let statusDot = NSView()
    private let statusTitle = NSTextField(labelWithString: "Checking…")
    private let statusDetail = NSTextField(wrappingLabelWithString: "")
    private let permissionButton = NSButton(frame: .zero)
    private let enabledSwitch = NSSwitch(frame: .zero)
    private let greenSwitch = NSSwitch(frame: .zero)
    private let titleSwitch = NSSwitch(frame: .zero)
    private let shortcutSwitch = NSSwitch(frame: .zero)
    private let loginSwitch = NSSwitch(frame: .zero)

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 610),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "WinMax"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = Brand.background
        window.center()
        super.init(window: window)
        buildUI()
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .winMaxRuntimeStateChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .winMaxSettingsChanged, object: nil)
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { NotificationCenter.default.removeObserver(self) }

    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        refresh()
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        content.wantsLayer = true
        content.layer?.backgroundColor = Brand.background.cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -32),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 30),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -22)
        ])

        [header(), statusCard(), controlsCard(), startupCard(), diagnosticsCard(), footer()].forEach {
            stack.addArrangedSubview($0)
            $0.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
    }

    private func header() -> NSView {
        let view = NSView(); view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 76).isActive = true
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "rectangle.inset.filled", accessibilityDescription: "WinMax")?
            .withSymbolConfiguration(.init(pointSize: 34, weight: .semibold))
        icon.contentTintColor = Brand.accent
        icon.translatesAutoresizingMaskIntoConstraints = false
        let title = label("WinMax", 29, .bold, Brand.text)
        let subtitle = label("Windows-style maximize for macOS", 13, .medium, Brand.secondary)
        let brand = label("VAST HOSTING", 10, .bold, Brand.accent)
        [icon, title, subtitle, brand].forEach(view.addSubview)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: view.leadingAnchor), icon.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 52), icon.heightAnchor.constraint(equalToConstant: 52),
            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 16), title.topAnchor.constraint(equalTo: icon.topAnchor),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor), subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 3),
            brand.trailingAnchor.constraint(equalTo: view.trailingAnchor), brand.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        return view
    }

    private func statusCard() -> NSView {
        let card = CardView(); card.heightAnchor.constraint(equalToConstant: 110).isActive = true
        statusDot.wantsLayer = true; statusDot.layer?.cornerRadius = 5; statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusTitle.font = .systemFont(ofSize: 15, weight: .semibold); statusTitle.textColor = Brand.text; statusTitle.translatesAutoresizingMaskIntoConstraints = false
        statusDetail.font = .systemFont(ofSize: 12); statusDetail.textColor = Brand.secondary; statusDetail.maximumNumberOfLines = 2; statusDetail.translatesAutoresizingMaskIntoConstraints = false
        permissionButton.target = self; permissionButton.action = #selector(permissionAction); permissionButton.bezelStyle = .rounded; permissionButton.translatesAutoresizingMaskIntoConstraints = false
        [statusDot, statusTitle, statusDetail, permissionButton].forEach(card.addSubview)
        NSLayoutConstraint.activate([
            statusDot.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20), statusDot.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            statusDot.widthAnchor.constraint(equalToConstant: 10), statusDot.heightAnchor.constraint(equalToConstant: 10),
            statusTitle.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 10), statusTitle.centerYAnchor.constraint(equalTo: statusDot.centerYAnchor),
            statusDetail.leadingAnchor.constraint(equalTo: statusTitle.leadingAnchor), statusDetail.topAnchor.constraint(equalTo: statusTitle.bottomAnchor, constant: 8),
            statusDetail.trailingAnchor.constraint(lessThanOrEqualTo: permissionButton.leadingAnchor, constant: -16),
            permissionButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20), permissionButton.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])
        return card
    }

    private func controlsCard() -> NSView {
        let card = CardView(); card.heightAnchor.constraint(equalToConstant: 205).isActive = true
        let heading = section("WINDOW CONTROL")
        let rows = NSStackView(); rows.orientation = .vertical; rows.spacing = 13; rows.translatesAutoresizingMaskIntoConstraints = false
        rows.addArrangedSubview(toggleRow("WinMax enabled", "Pause all overrides without quitting.", enabledSwitch, #selector(toggleEnabled)))
        rows.addArrangedSubview(toggleRow("Green button = maximize", "Stay on the desktop instead of creating a fullscreen Space.", greenSwitch, #selector(toggleGreen)))
        rows.addArrangedSubview(toggleRow("Double-click title bar", "Maximize or restore like Windows.", titleSwitch, #selector(toggleTitle)))
        rows.addArrangedSubview(toggleRow("Override ⌃⌘F", "Use desktop maximize instead of native fullscreen.", shortcutSwitch, #selector(toggleShortcut)))
        card.addSubview(heading); card.addSubview(rows)
        NSLayoutConstraint.activate([
            heading.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20), heading.topAnchor.constraint(equalTo: card.topAnchor, constant: 15),
            rows.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20), rows.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            rows.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 10)
        ])
        return card
    }

    private func startupCard() -> NSView {
        let card = CardView(); card.heightAnchor.constraint(equalToConstant: 84).isActive = true
        let heading = section("STARTUP")
        let row = toggleRow("Launch WinMax at login", "Start automatically after signing in to macOS.", loginSwitch, #selector(toggleLogin))
        card.addSubview(heading); card.addSubview(row)
        NSLayoutConstraint.activate([
            heading.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20), heading.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20), row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            row.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 9)
        ])
        return card
    }

    private func diagnosticsCard() -> NSView {
        let card = CardView(); card.heightAnchor.constraint(equalToConstant: 76).isActive = true
        let title = label("Having trouble?", 14, .semibold, Brand.text)
        let detail = label("Local debug logs only. No telemetry or window titles are recorded.", 11, .regular, Brand.secondary)
        let copy = NSButton(title: "Copy diagnostics", target: self, action: #selector(copyDiagnostics)); copy.bezelStyle = .rounded; copy.translatesAutoresizingMaskIntoConstraints = false
        let logs = NSButton(title: "Open logs", target: self, action: #selector(openLogs)); logs.bezelStyle = .rounded; logs.translatesAutoresizingMaskIntoConstraints = false
        [title, detail, copy, logs].forEach(card.addSubview)
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20), title.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            detail.leadingAnchor.constraint(equalTo: title.leadingAnchor), detail.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 5),
            logs.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18), logs.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            copy.trailingAnchor.constraint(equalTo: logs.leadingAnchor, constant: -8), copy.centerYAnchor.constraint(equalTo: logs.centerYAnchor)
        ])
        return card
    }

    private func footer() -> NSView {
        let view = NSView(); view.heightAnchor.constraint(equalToConstant: 22).isActive = true
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        let text = label("WinMax v\(version) · Free and open source · Built by Vast Hosting", 10, .regular, Brand.secondary)
        view.addSubview(text)
        NSLayoutConstraint.activate([text.leadingAnchor.constraint(equalTo: view.leadingAnchor), text.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
        return view
    }

    private func toggleRow(_ title: String, _ detail: String, _ toggle: NSSwitch, _ action: Selector) -> NSView {
        let row = NSView(); row.translatesAutoresizingMaskIntoConstraints = false; row.heightAnchor.constraint(equalToConstant: 33).isActive = true
        let t = label(title, 13, .medium, Brand.text); let d = label(detail, 10.5, .regular, Brand.secondary)
        toggle.target = self; toggle.action = action; toggle.translatesAutoresizingMaskIntoConstraints = false
        [t, d, toggle].forEach(row.addSubview)
        NSLayoutConstraint.activate([
            t.leadingAnchor.constraint(equalTo: row.leadingAnchor), t.topAnchor.constraint(equalTo: row.topAnchor),
            d.leadingAnchor.constraint(equalTo: t.leadingAnchor), d.topAnchor.constraint(equalTo: t.bottomAnchor, constant: 1), d.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12),
            toggle.trailingAnchor.constraint(equalTo: row.trailingAnchor), toggle.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        return row
    }

    private func label(_ text: String, _ size: CGFloat, _ weight: NSFont.Weight, _ color: NSColor) -> NSTextField {
        let value = NSTextField(labelWithString: text); value.font = .systemFont(ofSize: size, weight: weight); value.textColor = color; value.translatesAutoresizingMaskIntoConstraints = false; return value
    }

    private func section(_ text: String) -> NSTextField { label(text, 10, .bold, Brand.accent) }

    @objc private func refresh() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            statusDot.layer?.backgroundColor = Brand.warning.cgColor; statusTitle.stringValue = "Accessibility permission required"
            statusDetail.stringValue = "WinMax needs Accessibility access to detect and resize other apps' windows."; permissionButton.title = "Grant Access"
        } else if !WindowController.shared.isEventTapInstalled {
            statusDot.layer?.backgroundColor = Brand.warning.cgColor; statusTitle.stringValue = "Starting window controller…"
            statusDetail.stringValue = "Permission is granted. WinMax is preparing the event interceptor."; permissionButton.title = "Check Again"
        } else if !settings.enabled {
            statusDot.layer?.backgroundColor = Brand.warning.cgColor; statusTitle.stringValue = "WinMax is paused"
            statusDetail.stringValue = "Window overrides are disabled. Your settings are preserved."; permissionButton.title = "Accessibility"
        } else {
            statusDot.layer?.backgroundColor = Brand.accent.cgColor; statusTitle.stringValue = "WinMax is active"
            statusDetail.stringValue = "Green-button fullscreen is replaced with normal desktop maximize."; permissionButton.title = "Accessibility"
            settings.hasCompletedOnboarding = true
        }
        enabledSwitch.state = settings.enabled ? .on : .off; greenSwitch.state = settings.overrideGreenButton ? .on : .off
        titleSwitch.state = settings.titleBarDoubleClick ? .on : .off; shortcutSwitch.state = settings.overrideFullscreenShortcut ? .on : .off
        loginSwitch.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off
    }

    @objc private func permissionAction() {
        if AXIsProcessTrusted() { WindowController.shared.openAccessibilitySettings() }
        else { WindowController.shared.requestAccessibilityPrompt(); WindowController.shared.openAccessibilitySettings() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in self?.refresh() }
    }
    @objc private func toggleEnabled() { settings.enabled = enabledSwitch.state == .on }
    @objc private func toggleGreen() { settings.overrideGreenButton = greenSwitch.state == .on }
    @objc private func toggleTitle() { settings.titleBarDoubleClick = titleSwitch.state == .on }
    @objc private func toggleShortcut() { settings.overrideFullscreenShortcut = shortcutSwitch.state == .on }
    @objc private func toggleLogin() {
        do { try LaunchAtLoginManager.shared.setEnabled(loginSwitch.state == .on) }
        catch { loginSwitch.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off; showError("Could not change login setting", error.localizedDescription) }
    }
    @objc private func copyDiagnostics() { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(Diagnostics.report(), forType: .string) }
    @objc private func openLogs() { NSWorkspace.shared.open(WinMaxLogger.shared.logDirectory) }
    private func showError(_ title: String, _ detail: String) { let alert = NSAlert(); alert.alertStyle = .warning; alert.messageText = title; alert.informativeText = detail; alert.runModal() }
}

private final class CardView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame); translatesAutoresizingMaskIntoConstraints = false; wantsLayer = true
        layer?.backgroundColor = Brand.panel.cgColor; layer?.borderColor = Brand.border.cgColor; layer?.borderWidth = 1; layer?.cornerRadius = 13
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
