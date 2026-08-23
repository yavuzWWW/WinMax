import Cocoa

final class AboutWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 410),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About WinMax"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(calibratedWhite: 0.055, alpha: 1)
        window.center()
        super.init(window: window)
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        let icon = NSImageView()
        icon.image = NSApp.applicationIconImage
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 92).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 92).isActive = true

        let title = label(WinMaxProduct.name, size: 30, weight: .bold, secondary: false)
        let version = label("Version \(WinMaxProduct.displayVersion)", size: 12, weight: .medium, secondary: true)
        let tagline = label(WinMaxProduct.tagline, size: 14, weight: .semibold, secondary: false)

        let body = NSTextField(wrappingLabelWithString:
            "Native window control, Aero Snap and Menu Vault for macOS. Built to stay lightweight, local and predictable."
        )
        body.font = .systemFont(ofSize: 12)
        body.textColor = NSColor(calibratedWhite: 0.68, alpha: 1)
        body.alignment = .center
        body.maximumNumberOfLines = 0
        body.translatesAutoresizingMaskIntoConstraints = false
        body.widthAnchor.constraint(equalToConstant: 410).isActive = true

        let brand = label("A \(WinMaxProduct.company) open-source product", size: 11, weight: .medium, secondary: true)

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 8
        let website = NSButton(title: "Website", target: self, action: #selector(openWebsite))
        let releases = NSButton(title: "Releases", target: self, action: #selector(openReleases))
        let source = NSButton(title: "Source Code", target: self, action: #selector(openSource))
        for button in [website, releases, source] {
            button.bezelStyle = .rounded
            buttons.addArrangedSubview(button)
        }

        [icon, title, version, tagline, body, brand, buttons].forEach(stack.addArrangedSubview)
        stack.setCustomSpacing(18, after: icon)
        stack.setCustomSpacing(18, after: tagline)
        stack.setCustomSpacing(18, after: brand)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: content.leadingAnchor, constant: 30),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -30),
            stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor, constant: 6)
        ])
    }

    private func label(_ value: String, size: CGFloat, weight: NSFont.Weight, secondary: Bool) -> NSTextField {
        let label = NSTextField(labelWithString: value)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = secondary
            ? NSColor(calibratedWhite: 0.62, alpha: 1)
            : NSColor(calibratedWhite: 0.96, alpha: 1)
        label.alignment = .center
        return label
    }

    @objc private func openWebsite() {
        NSWorkspace.shared.open(WinMaxProduct.websiteURL)
    }

    @objc private func openReleases() {
        NSWorkspace.shared.open(WinMaxProduct.releasesURL)
    }

    @objc private func openSource() {
        NSWorkspace.shared.open(WinMaxProduct.repositoryURL)
    }
}
