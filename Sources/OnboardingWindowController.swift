import Cocoa
import ApplicationServices

final class OnboardingWindowController: NSWindowController {
    private let settings = SettingsStore.shared
    private let contentStack = NSStackView()
    private let primaryButton = NSButton(frame: .zero)
    private let secondaryButton = NSButton(frame: .zero)
    private let permissionStatus = NSTextField(labelWithString: "")
    private var step = 0

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to WinMax"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(calibratedWhite: 0.055, alpha: 1)
        window.center()
        super.init(window: window)
        buildUI()
        renderStep()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        step = 0
        renderStep()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor(calibratedWhite: 0.055, alpha: 1).cgColor

        let shell = NSStackView()
        shell.orientation = .vertical
        shell.alignment = .leading
        shell.spacing = 20
        shell.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(shell)

        let brand = NSTextField(labelWithString: "VAST HOSTING")
        brand.font = .systemFont(ofSize: 11, weight: .bold)
        brand.textColor = NSColor(calibratedRed: 0.27, green: 0.83, blue: 0.74, alpha: 1)
        brand.translatesAutoresizingMaskIntoConstraints = false

        let hero = NSStackView()
        hero.orientation = .horizontal
        hero.alignment = .centerY
        hero.spacing = 16
        hero.translatesAutoresizingMaskIntoConstraints = false

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "rectangle.inset.filled", accessibilityDescription: "WinMax")?
            .withSymbolConfiguration(.init(pointSize: 44, weight: .semibold))
        icon.contentTintColor = NSColor(calibratedRed: 0.27, green: 0.83, blue: 0.74, alpha: 1)
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 62).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 62).isActive = true

        let heroText = NSStackView()
        heroText.orientation = .vertical
        heroText.alignment = .leading
        heroText.spacing = 3
        let title = text("WinMax", size: 34, weight: .bold)
        let subtitle = text("Windows-style window control for macOS", size: 14, weight: .medium, secondary: true)
        heroText.addArrangedSubview(title)
        heroText.addArrangedSubview(subtitle)
        hero.addArrangedSubview(icon)
        hero.addArrangedSubview(heroText)

        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 10
        buttons.translatesAutoresizingMaskIntoConstraints = false
        secondaryButton.target = self
        secondaryButton.action = #selector(secondaryAction)
        secondaryButton.bezelStyle = .rounded
        primaryButton.target = self
        primaryButton.action = #selector(primaryAction)
        primaryButton.bezelStyle = .rounded
        primaryButton.keyEquivalent = "\r"
        buttons.addArrangedSubview(secondaryButton)
        buttons.addArrangedSubview(primaryButton)

        shell.addArrangedSubview(brand)
        shell.addArrangedSubview(hero)
        shell.addArrangedSubview(separator())
        shell.addArrangedSubview(contentStack)

        let buttonContainer = NSView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.heightAnchor.constraint(equalToConstant: 44).isActive = true
        buttonContainer.addSubview(buttons)
        NSLayoutConstraint.activate([
            buttons.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),
            buttons.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor)
        ])
        shell.addArrangedSubview(buttonContainer)
        buttonContainer.widthAnchor.constraint(equalTo: shell.widthAnchor).isActive = true

        NSLayoutConstraint.activate([
            shell.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 40),
            shell.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -40),
            shell.topAnchor.constraint(equalTo: content.topAnchor, constant: 34),
            shell.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -28),
            contentStack.widthAnchor.constraint(equalTo: shell.widthAnchor)
        ])
    }

    private func renderStep() {
        contentStack.arrangedSubviews.forEach { view in
            contentStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        switch step {
        case 0:
            contentStack.addArrangedSubview(stepTitle("Make macOS windows behave the way you expect."))
            contentStack.addArrangedSubview(body("WinMax replaces the green-button fullscreen workflow with normal desktop maximize and restore. No separate fullscreen Space. Other windows and dialogs can still appear above the maximized window."))
            contentStack.addArrangedSubview(feature("Green button → maximize / restore"))
            contentStack.addArrangedSubview(feature("Double-click title bar → maximize / restore"))
            contentStack.addArrangedSubview(feature("⌃⌘F → desktop maximize instead of fullscreen Space"))
            contentStack.addArrangedSubview(feature("Native, lightweight and open source"))
            secondaryButton.isHidden = true
            primaryButton.title = "Get Started"

        case 1:
            contentStack.addArrangedSubview(stepTitle("Allow Accessibility access"))
            contentStack.addArrangedSubview(body("WinMax needs macOS Accessibility permission to detect and resize other apps' windows. WinMax does not read document contents or send telemetry."))
            permissionStatus.font = .systemFont(ofSize: 13, weight: .semibold)
            permissionStatus.translatesAutoresizingMaskIntoConstraints = false
            updatePermissionStatus()
            contentStack.addArrangedSubview(permissionStatus)
            contentStack.addArrangedSubview(body("Click Open Settings, enable WinMax under Privacy & Security → Accessibility, then return here."))
            secondaryButton.isHidden = false
            secondaryButton.title = "Back"
            primaryButton.title = AXIsProcessTrusted() ? "Continue" : "Open Settings"

        default:
            contentStack.addArrangedSubview(stepTitle("You're ready."))
            contentStack.addArrangedSubview(body("WinMax will stay in your menu bar and handle window maximize/restore in the background. You can change every behavior later from Settings."))
            contentStack.addArrangedSubview(feature("WinMax enabled"))
            contentStack.addArrangedSubview(feature("Green-button override enabled"))
            contentStack.addArrangedSubview(feature("Double-click title-bar override enabled"))
            contentStack.addArrangedSubview(feature("Fullscreen shortcut override enabled"))
            secondaryButton.isHidden = false
            secondaryButton.title = "Back"
            primaryButton.title = "Start WinMax"
        }
    }

    @objc private func primaryAction() {
        switch step {
        case 0:
            step = 1
            renderStep()
        case 1:
            if AXIsProcessTrusted() {
                step = 2
                renderStep()
            } else {
                WindowController.shared.requestAccessibilityPrompt()
                WindowController.shared.openAccessibilitySettings()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    self?.updatePermissionStatus()
                    self?.primaryButton.title = AXIsProcessTrusted() ? "Continue" : "Open Settings"
                }
            }
        default:
            settings.enabled = true
            settings.overrideGreenButton = true
            settings.titleBarDoubleClick = true
            settings.overrideFullscreenShortcut = true
            settings.hasCompletedOnboarding = true
            window?.close()
            NotificationCenter.default.post(name: .winMaxSettingsChanged, object: nil)
        }
    }

    @objc private func secondaryAction() {
        guard step > 0 else { return }
        step -= 1
        renderStep()
    }

    private func updatePermissionStatus() {
        let trusted = AXIsProcessTrusted()
        permissionStatus.stringValue = trusted ? "✓ Accessibility permission granted" : "● Accessibility permission required"
        permissionStatus.textColor = trusted
            ? NSColor(calibratedRed: 0.27, green: 0.83, blue: 0.74, alpha: 1)
            : NSColor(calibratedRed: 1.0, green: 0.68, blue: 0.20, alpha: 1)
    }

    private func stepTitle(_ value: String) -> NSTextField { text(value, size: 22, weight: .bold) }

    private func body(_ value: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: value)
        label.font = .systemFont(ofSize: 13)
        label.textColor = NSColor(calibratedWhite: 0.72, alpha: 1)
        label.maximumNumberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 650).isActive = true
        return label
    }

    private func feature(_ value: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        let icon = NSImageView(image: NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = NSColor(calibratedRed: 0.27, green: 0.83, blue: 0.74, alpha: 1)
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 18).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 18).isActive = true
        row.addArrangedSubview(icon)
        row.addArrangedSubview(text(value, size: 13, weight: .medium))
        return row
    }

    private func text(_ value: String, size: CGFloat, weight: NSFont.Weight, secondary: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: value)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = secondary ? NSColor(calibratedWhite: 0.68, alpha: 1) : NSColor(calibratedWhite: 0.96, alpha: 1)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func separator() -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(calibratedWhite: 0.16, alpha: 1).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return view
    }
}
