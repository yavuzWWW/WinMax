import Cocoa
import ApplicationServices

final class MenuVaultController: NSObject, NSSearchFieldDelegate {
    static let shared = MenuVaultController()

    private struct VaultItem {
        let element: AXUIElement
        let pid: pid_t
        let appName: String
        let bundleIdentifier: String
        let title: String
        let detail: String
        let icon: NSImage?
        let x: CGFloat
    }

    private var panel: NSPanel?
    private var searchField: NSSearchField?
    private var stack: NSStackView?
    private var statusLabel: NSTextField?
    private var items: [VaultItem] = []
    private var refreshTimer: Timer?
    private let settings = SettingsStore.shared

    private override init() {
        super.init()
    }

    func start() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
            guard let self, self.panel?.isVisible == true else { return }
            self.refresh()
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        panel?.orderOut(nil)
    }

    func show() {
        guard settings.menuVaultEnabled else { return }
        if panel == nil { buildPanel() }
        refresh()
        positionPanel()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        searchField?.becomeFirstResponder()
    }

    func toggle() {
        if panel?.isVisible == true { panel?.orderOut(nil) }
        else { show() }
    }

    func refresh() {
        guard settings.menuVaultEnabled else {
            panel?.orderOut(nil)
            return
        }
        items = discoverItems()
        rebuildRows()
    }

    private func buildPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 520),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Menu Vault"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.backgroundColor = NSColor(calibratedWhite: 0.055, alpha: 1)

        guard let content = panel.contentView else { return }
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor(calibratedWhite: 0.055, alpha: 1).cgColor

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 12
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)

        let eyebrow = NSTextField(labelWithString: "WINMAX · MENU VAULT")
        eyebrow.font = .systemFont(ofSize: 10, weight: .bold)
        eyebrow.textColor = accent

        let title = NSTextField(labelWithString: "Your menu bar, without the space limit.")
        title.font = .systemFont(ofSize: 20, weight: .bold)
        title.textColor = .white

        let subtitle = NSTextField(wrappingLabelWithString: "Search and open menu-bar controls from running apps, including items that are difficult to reach around the notch.")
        subtitle.font = .systemFont(ofSize: 11.5)
        subtitle.textColor = NSColor(calibratedWhite: 0.68, alpha: 1)
        subtitle.maximumNumberOfLines = 2

        let search = NSSearchField(frame: .zero)
        search.placeholderString = "Search menu-bar items"
        search.target = self
        search.action = #selector(searchChanged)
        search.sendsSearchStringImmediately = true
        search.translatesAutoresizingMaskIntoConstraints = false
        search.heightAnchor.constraint(equalToConstant: 30).isActive = true
        self.searchField = search

        let status = NSTextField(labelWithString: "Scanning…")
        status.font = .systemFont(ofSize: 10.5, weight: .medium)
        status.textColor = NSColor(calibratedWhite: 0.58, alpha: 1)
        self.statusLabel = status

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let document = NSView()
        document.translatesAutoresizingMaskIntoConstraints = false
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        scroll.documentView = document
        self.stack = stack

        root.addArrangedSubview(eyebrow)
        root.addArrangedSubview(title)
        root.addArrangedSubview(subtitle)
        root.addArrangedSubview(search)
        root.addArrangedSubview(status)
        root.addArrangedSubview(scroll)

        [eyebrow, title, subtitle, search, status, scroll].forEach {
            $0.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        }

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            root.topAnchor.constraint(equalTo: content.topAnchor, constant: 22),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            stack.topAnchor.constraint(equalTo: document.topAnchor),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor)
        ])

        self.panel = panel
    }

    private func positionPanel() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        var frame = panel.frame
        frame.origin.x = min(max(mouse.x - frame.width + 24, visible.minX + 10), visible.maxX - frame.width - 10)
        frame.origin.y = visible.maxY - frame.height - 8
        panel.setFrame(frame, display: false)
    }

    private func rebuildRows() {
        guard let stack else { return }
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let query = searchField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let filtered = items.enumerated().filter { _, item in
            query.isEmpty || item.title.lowercased().contains(query) || item.appName.lowercased().contains(query) || item.detail.lowercased().contains(query)
        }

        statusLabel?.stringValue = items.isEmpty
            ? "No accessible menu-bar items found."
            : "\(filtered.count) of \(items.count) menu-bar items"

        if filtered.isEmpty {
            let empty = NSTextField(wrappingLabelWithString: query.isEmpty ? "Open a few menu-bar apps and press Refresh from the WinMax menu." : "No items match your search.")
            empty.font = .systemFont(ofSize: 12)
            empty.textColor = NSColor(calibratedWhite: 0.62, alpha: 1)
            stack.addArrangedSubview(empty)
            empty.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            return
        }

        for (index, item) in filtered {
            let row = VaultRowButton(index: index, target: self, action: #selector(openItem(_:)))
            row.translatesAutoresizingMaskIntoConstraints = false
            row.heightAnchor.constraint(equalToConstant: 52).isActive = true
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            row.wantsLayer = true
            row.layer?.backgroundColor = NSColor(calibratedWhite: 0.09, alpha: 1).cgColor
            row.layer?.borderColor = NSColor(calibratedWhite: 0.16, alpha: 1).cgColor
            row.layer?.borderWidth = 1
            row.layer?.cornerRadius = 10

            let icon = NSImageView()
            icon.image = item.icon ?? NSImage(systemSymbolName: "menubar.rectangle", accessibilityDescription: nil)
            icon.imageScaling = .scaleProportionallyUpOrDown
            icon.translatesAutoresizingMaskIntoConstraints = false

            let title = NSTextField(labelWithString: item.title)
            title.font = .systemFont(ofSize: 12.5, weight: .semibold)
            title.textColor = .white
            title.lineBreakMode = .byTruncatingTail
            title.translatesAutoresizingMaskIntoConstraints = false

            let detail = NSTextField(labelWithString: item.detail.isEmpty ? item.appName : "\(item.appName) · \(item.detail)")
            detail.font = .systemFont(ofSize: 10.5)
            detail.textColor = NSColor(calibratedWhite: 0.58, alpha: 1)
            detail.lineBreakMode = .byTruncatingTail
            detail.translatesAutoresizingMaskIntoConstraints = false

            let arrow = NSImageView(image: NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil) ?? NSImage())
            arrow.contentTintColor = NSColor(calibratedWhite: 0.48, alpha: 1)
            arrow.translatesAutoresizingMaskIntoConstraints = false

            [icon, title, detail, arrow].forEach(row.addSubview)
            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
                icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 28),
                icon.heightAnchor.constraint(equalToConstant: 28),
                title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
                title.topAnchor.constraint(equalTo: row.topAnchor, constant: 9),
                title.trailingAnchor.constraint(lessThanOrEqualTo: arrow.leadingAnchor, constant: -10),
                detail.leadingAnchor.constraint(equalTo: title.leadingAnchor),
                detail.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2),
                detail.trailingAnchor.constraint(lessThanOrEqualTo: arrow.leadingAnchor, constant: -10),
                arrow.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
                arrow.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                arrow.widthAnchor.constraint(equalToConstant: 10),
                arrow.heightAnchor.constraint(equalToConstant: 14)
            ])
            stack.addArrangedSubview(row)
        }
    }

    private func discoverItems() -> [VaultItem] {
        guard AXIsProcessTrusted() else { return [] }
        let selfPID = ProcessInfo.processInfo.processIdentifier
        var results: [VaultItem] = []

        for app in NSWorkspace.shared.runningApplications where !app.isTerminated && app.processIdentifier != selfPID {
            let pid = app.processIdentifier
            let axApp = AXUIElementCreateApplication(pid)
            let appName = app.localizedName ?? app.bundleIdentifier ?? "Unknown app"
            let bundleID = app.bundleIdentifier ?? "pid.\(pid)"
            let icon = app.icon

            var roots: [AXUIElement] = []
            if let extras = element(axApp, "AXExtrasMenuBar") { roots.append(extras) }

            // Some apps expose status items through AXMenuBar rather than AXExtrasMenuBar.
            if roots.isEmpty, let menuBar = element(axApp, kAXMenuBarAttribute) { roots.append(menuBar) }

            for root in roots {
                collectMenuItems(from: root, depth: 0).forEach { element in
                    guard let rect = frame(element), rect.width > 0, rect.height > 0 else { return }
                    let role = string(element, kAXRoleAttribute) ?? ""
                    guard role == (kAXMenuBarItemRole as String) || role == "AXMenuBarItem" else { return }

                    let rawTitle = firstNonEmpty([
                        string(element, kAXTitleAttribute),
                        string(element, kAXDescriptionAttribute),
                        string(element, kAXHelpAttribute),
                        string(element, "AXIdentifier")
                    ])
                    let title = rawTitle ?? appName
                    let detail = rawTitle == nil ? "Menu bar control" : "Menu bar item"
                    results.append(VaultItem(
                        element: element,
                        pid: pid,
                        appName: appName,
                        bundleIdentifier: bundleID,
                        title: title,
                        detail: detail,
                        icon: icon,
                        x: rect.minX
                    ))
                }
            }
        }

        var seen = Set<String>()
        return results
            .sorted { lhs, rhs in
                if lhs.x == rhs.x { return lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending }
                return lhs.x < rhs.x
            }
            .filter { item in
                let signature = "\(item.bundleIdentifier)|\(item.title)|\(Int(item.x.rounded()))"
                return seen.insert(signature).inserted
            }
    }

    private func collectMenuItems(from root: AXUIElement, depth: Int) -> [AXUIElement] {
        guard depth <= 3 else { return [] }
        var collected: [AXUIElement] = []
        let role = string(root, kAXRoleAttribute) ?? ""
        if role == (kAXMenuBarItemRole as String) || role == "AXMenuBarItem" { collected.append(root) }
        for child in elements(root, kAXChildrenAttribute) {
            collected.append(contentsOf: collectMenuItems(from: child, depth: depth + 1))
        }
        return collected
    }

    @objc private func searchChanged() {
        rebuildRows()
    }

    @objc private func openItem(_ sender: VaultRowButton) {
        guard items.indices.contains(sender.itemIndex) else { return }
        let item = items[sender.itemIndex]
        guard NSRunningApplication(processIdentifier: item.pid) != nil else {
            refresh()
            return
        }

        let result = AXUIElementPerformAction(item.element, kAXPressAction as CFString)
        if result != .success {
            // The AX element may have been recreated. Refresh once and let the user retry.
            WinMaxLogger.shared.warning("Menu Vault AXPress failed for \(item.bundleIdentifier): \(result.rawValue)")
            refresh()
            return
        }
        panel?.orderOut(nil)
    }

    private func element(_ source: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(source, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func elements(_ source: AXUIElement, _ attribute: String) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(source, attribute as CFString, &value) == .success,
              let array = value as? [AXUIElement] else { return [] }
        return array
    }

    private func string(_ source: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(source, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func frame(_ source: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(source, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(source, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue,
              let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(unsafeBitCast(positionValue, to: AXValue.self), .cgPoint, &point),
              AXValueGetValue(unsafeBitCast(sizeValue, to: AXValue.self), .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }

    private func firstNonEmpty(_ values: [String?]) -> String? {
        for value in values {
            if let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty { return value }
        }
        return nil
    }

    private var accent: NSColor {
        NSColor(calibratedRed: 0.27, green: 0.83, blue: 0.74, alpha: 1)
    }
}

private final class VaultRowButton: NSButton {
    let itemIndex: Int

    init(index: Int, target: AnyObject?, action: Selector?) {
        itemIndex = index
        super.init(frame: .zero)
        self.target = target
        self.action = action
        self.title = ""
        self.isBordered = false
        self.setButtonType(.momentaryChange)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
