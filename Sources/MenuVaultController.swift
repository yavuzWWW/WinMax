import Cocoa
import ApplicationServices

final class MenuVaultController: NSObject {
    static let shared = MenuVaultController()

    private struct AppSnapshot {
        let pid: pid_t
        let appName: String
        let bundleIdentifier: String
    }

    private struct Locator {
        let pid: pid_t
        let bundleIdentifier: String
        let ordinal: Int
        let identifier: String?
        let title: String?
        let description: String?
        let help: String?
    }

    private struct VaultItem {
        let locator: Locator
        let appName: String
        let title: String
        let detail: String
        let x: CGFloat?
    }

    private var panel: NSPanel?
    private var searchField: NSSearchField?
    private var stack: NSStackView?
    private var statusLabel: NSTextField?
    private var statusItem: NSStatusItem?
    private var refreshTimer: Timer?
    private var settingsObserver: NSObjectProtocol?
    private var items: [VaultItem] = []
    private var refreshGeneration = 0

    private let settings = SettingsStore.shared
    private let scanQueue = DispatchQueue(
        label: "cloud.vasthosting.winmax.menuvault.scan",
        qos: .userInitiated
    )

    private(set) var indexedItemCount = 0

    private override init() {
        super.init()
    }

    deinit {
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }

    func start() {
        createStatusItemIfNeeded()
        applySettings()

        if settingsObserver == nil {
            settingsObserver = NotificationCenter.default.addObserver(
                forName: .winMaxSettingsChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.applySettings()
            }
        }

        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { [weak self] _ in
            guard let self, self.panel?.isVisible == true else { return }
            self.refresh()
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        panel?.orderOut(nil)
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    func show() {
        guard settings.menuVaultEnabled else { return }
        if panel == nil { buildPanel() }
        positionPanel()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        searchField?.becomeFirstResponder()
        refresh()
    }

    func toggle() {
        if panel?.isVisible == true {
            panel?.orderOut(nil)
        } else {
            show()
        }
    }

    func refresh() {
        guard settings.menuVaultEnabled else {
            panel?.orderOut(nil)
            return
        }

        guard AXIsProcessTrusted() else {
            refreshGeneration += 1
            items = []
            indexedItemCount = 0
            rebuildRows(statusOverride: "Accessibility permission is required.")
            return
        }

        refreshGeneration += 1
        let generation = refreshGeneration
        statusLabel?.stringValue = "Scanning menu-bar items…"

        let selfPID = ProcessInfo.processInfo.processIdentifier
        let apps = NSWorkspace.shared.runningApplications.compactMap { app -> AppSnapshot? in
            guard !app.isTerminated,
                  app.processIdentifier != selfPID else {
                return nil
            }
            return AppSnapshot(
                pid: app.processIdentifier,
                appName: app.localizedName ?? app.bundleIdentifier ?? "Unknown app",
                bundleIdentifier: app.bundleIdentifier ?? "pid.\(app.processIdentifier)"
            )
        }

        scanQueue.async { [weak self] in
            guard let self else { return }
            let discovered = self.discoverItems(in: apps)
            DispatchQueue.main.async { [weak self] in
                guard let self, generation == self.refreshGeneration else { return }
                self.items = discovered
                self.indexedItemCount = discovered.count
                self.rebuildRows()
            }
        }
    }

    private func createStatusItemIfNeeded() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "WinMax.MenuVault"
        if let image = NSImage(
            systemSymbolName: "ellipsis.circle",
            accessibilityDescription: "WinMax Menu Vault"
        ) {
            image.isTemplate = true
            item.button?.image = image
        } else {
            item.button?.title = "•••"
        }
        item.button?.toolTip = "WinMax Menu Vault"
        item.button?.target = self
        item.button?.action = #selector(toggleFromStatusItem)
        statusItem = item
    }

    private func applySettings() {
        createStatusItemIfNeeded()
        statusItem?.isVisible = settings.menuVaultEnabled
        if !settings.menuVaultEnabled {
            panel?.orderOut(nil)
            refreshGeneration += 1
            items = []
            indexedItemCount = 0
        } else if panel?.isVisible == true {
            refresh()
        }
    }

    private func buildPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 540),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Menu Vault"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.backgroundColor = background

        guard let content = panel.contentView else { return }
        content.wantsLayer = true
        content.layer?.backgroundColor = background.cgColor

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 11
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)

        let eyebrow = label("WINMAX · MENU VAULT", 10, .bold, accent)
        let title = label("Your menu bar, without the space limit.", 20, .bold, textColor)
        let subtitle = NSTextField(
            wrappingLabelWithString: "Search and open Accessibility-exposed status items, including controls that are difficult to reach around the notch."
        )
        subtitle.font = .systemFont(ofSize: 11.5)
        subtitle.textColor = secondary
        subtitle.maximumNumberOfLines = 2
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        let search = NSSearchField(frame: .zero)
        search.placeholderString = "Search menu-bar items"
        search.target = self
        search.action = #selector(searchChanged)
        search.sendsSearchStringImmediately = true
        search.translatesAutoresizingMaskIntoConstraints = false
        search.heightAnchor.constraint(equalToConstant: 30).isActive = true
        searchField = search

        let status = label("Scanning…", 10.5, .medium, secondary)
        statusLabel = status

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let document = NSView()
        document.translatesAutoresizingMaskIntoConstraints = false
        let rows = NSStackView()
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 7
        rows.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(rows)
        scroll.documentView = document
        stack = rows

        let footer = NSStackView()
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 8
        footer.translatesAutoresizingMaskIntoConstraints = false
        let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(refreshAction))
        refreshButton.bezelStyle = .rounded
        let accessibilityButton = NSButton(
            title: "Accessibility",
            target: self,
            action: #selector(openAccessibility)
        )
        accessibilityButton.bezelStyle = .rounded
        let hint = label("Shortcut: ⌃⌥⌘V", 10, .regular, secondary)
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        footer.addArrangedSubview(refreshButton)
        footer.addArrangedSubview(accessibilityButton)
        footer.addArrangedSubview(spacer)
        footer.addArrangedSubview(hint)
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        [eyebrow, title, subtitle, search, status, scroll, footer].forEach {
            root.addArrangedSubview($0)
            $0.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        }

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            root.topAnchor.constraint(equalTo: content.topAnchor, constant: 22),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 310),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            rows.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            rows.topAnchor.constraint(equalTo: document.topAnchor),
            rows.bottomAnchor.constraint(equalTo: document.bottomAnchor)
        ])

        self.panel = panel
    }

    private func positionPanel() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }

        var frame = panel.frame
        frame.origin.x = min(
            max(mouse.x - frame.width + 24, visible.minX + 10),
            visible.maxX - frame.width - 10
        )
        frame.origin.y = visible.maxY - frame.height - 8
        panel.setFrame(frame, display: false)
    }

    private func rebuildRows(statusOverride: String? = nil) {
        guard let stack else { return }
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let query = searchField?.stringValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        let filtered = items.enumerated().filter { _, item in
            query.isEmpty
                || item.title.lowercased().contains(query)
                || item.appName.lowercased().contains(query)
                || item.detail.lowercased().contains(query)
        }

        if let statusOverride {
            statusLabel?.stringValue = statusOverride
        } else if items.isEmpty {
            statusLabel?.stringValue = "No accessible status items found."
        } else {
            statusLabel?.stringValue = "\(filtered.count) of \(items.count) status items"
        }

        if filtered.isEmpty {
            let message: String
            if !AXIsProcessTrusted() {
                message = "Enable WinMax in Privacy & Security → Accessibility, then press Refresh."
            } else if query.isEmpty {
                message = "No third-party or system status items are currently exposed through macOS Accessibility."
            } else {
                message = "No items match your search."
            }
            let empty = NSTextField(wrappingLabelWithString: message)
            empty.font = .systemFont(ofSize: 12)
            empty.textColor = secondary
            empty.maximumNumberOfLines = 0
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
            row.layer?.backgroundColor = panelColor.cgColor
            row.layer?.borderColor = border.cgColor
            row.layer?.borderWidth = 1
            row.layer?.cornerRadius = 10

            let icon = NSImageView()
            icon.image = iconForItem(item)
                ?? NSImage(systemSymbolName: "menubar.rectangle", accessibilityDescription: nil)
            icon.imageScaling = .scaleProportionallyUpOrDown
            icon.translatesAutoresizingMaskIntoConstraints = false

            let title = label(item.title, 12.5, .semibold, textColor)
            title.lineBreakMode = .byTruncatingTail
            let detail = label(item.detail, 10.5, .regular, secondary)
            detail.lineBreakMode = .byTruncatingTail
            let arrow = NSImageView(
                image: NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil) ?? NSImage()
            )
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

    private func discoverItems(in apps: [AppSnapshot]) -> [VaultItem] {
        var results: [VaultItem] = []

        for app in apps {
            let axApp = AXUIElementCreateApplication(app.pid)
            _ = AXUIElementSetMessagingTimeout(axApp, 0.25)

            guard let extras = element(axApp, "AXExtrasMenuBar") else { continue }
            let menuItems = collectMenuItems(from: extras, depth: 0)

            for (ordinal, menuItem) in menuItems.enumerated() {
                guard supportsPress(menuItem) else { continue }

                let identifier = normalized(string(menuItem, "AXIdentifier"))
                let title = normalized(string(menuItem, kAXTitleAttribute))
                let description = normalized(string(menuItem, kAXDescriptionAttribute))
                let help = normalized(string(menuItem, kAXHelpAttribute))
                let rect = frame(menuItem)

                let displayTitle = firstNonEmpty([title, description, help])
                    ?? "\(app.appName) status item"
                let detail = firstNonEmpty([description, help])
                    .map { "\(app.appName) · \($0)" }
                    ?? app.appName

                results.append(
                    VaultItem(
                        locator: Locator(
                            pid: app.pid,
                            bundleIdentifier: app.bundleIdentifier,
                            ordinal: ordinal,
                            identifier: identifier,
                            title: title,
                            description: description,
                            help: help
                        ),
                        appName: app.appName,
                        title: displayTitle,
                        detail: detail,
                        x: rect?.minX
                    )
                )
            }
        }

        var seen = Set<String>()
        return results
            .sorted { lhs, rhs in
                switch (lhs.x, rhs.x) {
                case let (l?, r?) where l != r:
                    return l < r
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    return lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending
                }
            }
            .filter { item in
                let locator = item.locator
                let identity = firstNonEmpty([
                    locator.identifier,
                    locator.title,
                    locator.description,
                    locator.help
                ]) ?? "ordinal:\(locator.ordinal)"
                let signature = "\(locator.bundleIdentifier)|\(identity)|\(locator.ordinal)"
                return seen.insert(signature).inserted
            }
    }

    private func collectMenuItems(from root: AXUIElement, depth: Int) -> [AXUIElement] {
        guard depth <= 4 else { return [] }
        var result: [AXUIElement] = []
        let role = string(root, kAXRoleAttribute) ?? ""
        if role == (kAXMenuBarItemRole as String) || role == "AXMenuBarItem" {
            result.append(root)
        }
        for child in elements(root, kAXChildrenAttribute) {
            result.append(contentsOf: collectMenuItems(from: child, depth: depth + 1))
        }
        return result
    }

    private func resolve(_ locator: Locator) -> AXUIElement? {
        let pid: pid_t
        if let running = NSRunningApplication(processIdentifier: locator.pid),
           !running.isTerminated,
           (running.bundleIdentifier ?? "pid.\(locator.pid)") == locator.bundleIdentifier {
            pid = locator.pid
        } else if let replacement = NSRunningApplication
            .runningApplications(withBundleIdentifier: locator.bundleIdentifier)
            .first(where: { !$0.isTerminated }) {
            pid = replacement.processIdentifier
        } else {
            return nil
        }

        let axApp = AXUIElementCreateApplication(pid)
        _ = AXUIElementSetMessagingTimeout(axApp, 0.4)
        guard let extras = element(axApp, "AXExtrasMenuBar") else { return nil }
        let candidates = collectMenuItems(from: extras, depth: 0)
            .filter { supportsPress($0) }

        var best: (score: Int, element: AXUIElement)?
        for (ordinal, element) in candidates.enumerated() {
            let identifier = normalized(string(element, "AXIdentifier"))
            let title = normalized(string(element, kAXTitleAttribute))
            let description = normalized(string(element, kAXDescriptionAttribute))
            let help = normalized(string(element, kAXHelpAttribute))
            var score = 0

            if let expected = locator.identifier, expected == identifier { score += 100 }
            if let expected = locator.title, expected == title { score += 45 }
            if let expected = locator.description, expected == description { score += 30 }
            if let expected = locator.help, expected == help { score += 20 }
            if locator.ordinal == ordinal { score += 8 }

            if best == nil || score > best!.score {
                best = (score, element)
            }
        }

        let hasIdentity = firstNonEmpty([
            locator.identifier,
            locator.title,
            locator.description,
            locator.help
        ]) != nil
        if hasIdentity {
            return (best?.score ?? 0) >= 20 ? best?.element : nil
        }
        guard candidates.indices.contains(locator.ordinal) else { return nil }
        return candidates[locator.ordinal]
    }

    private func activate(_ locator: Locator) -> Bool {
        guard let element = resolve(locator) else { return false }
        return AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
    }

    private func iconForItem(_ item: VaultItem) -> NSImage? {
        if let app = NSRunningApplication(processIdentifier: item.locator.pid),
           !app.isTerminated {
            return app.icon
        }
        return NSRunningApplication
            .runningApplications(withBundleIdentifier: item.locator.bundleIdentifier)
            .first?.icon
    }

    private func supportsPress(_ element: AXUIElement) -> Bool {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success,
              let actions = names as? [String] else {
            return false
        }
        return actions.contains(kAXPressAction as String)
    }

    private func element(_ source: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            source,
            attribute as CFString,
            &value
        ) == .success,
        let value,
        CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func elements(_ source: AXUIElement, _ attribute: String) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            source,
            attribute as CFString,
            &value
        ) == .success,
        let array = value as? [AXUIElement] else {
            return []
        }
        return array
    }

    private func string(_ source: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            source,
            attribute as CFString,
            &value
        ) == .success else {
            return nil
        }
        return value as? String
    }

    private func frame(_ source: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            source,
            kAXPositionAttribute as CFString,
            &positionValue
        ) == .success,
        AXUIElementCopyAttributeValue(
            source,
            kAXSizeAttribute as CFString,
            &sizeValue
        ) == .success,
        let positionValue,
        let sizeValue,
        CFGetTypeID(positionValue) == AXValueGetTypeID(),
        CFGetTypeID(sizeValue) == AXValueGetTypeID() else {
            return nil
        }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(
            unsafeBitCast(positionValue, to: AXValue.self),
            .cgPoint,
            &point
        ),
        AXValueGetValue(
            unsafeBitCast(sizeValue, to: AXValue.self),
            .cgSize,
            &size
        ) else {
            return nil
        }
        return CGRect(origin: point, size: size)
    }

    private func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private func firstNonEmpty(_ values: [String?]) -> String? {
        for value in values {
            if let value = normalized(value) { return value }
        }
        return nil
    }

    private func label(
        _ value: String,
        _ size: CGFloat,
        _ weight: NSFont.Weight,
        _ color: NSColor
    ) -> NSTextField {
        let label = NSTextField(labelWithString: value)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    @objc private func toggleFromStatusItem() {
        toggle()
    }

    @objc private func searchChanged() {
        rebuildRows()
    }

    @objc private func refreshAction() {
        refresh()
    }

    @objc private func openAccessibility() {
        WindowController.shared.openAccessibilitySettings()
    }

    @objc private func openItem(_ sender: VaultRowButton) {
        guard items.indices.contains(sender.itemIndex) else { return }
        let item = items[sender.itemIndex]
        panel?.orderOut(nil)

        scanQueue.async { [weak self] in
            guard let self else { return }
            let success = self.activate(item.locator)
            guard !success else { return }
            WinMaxLogger.shared.warning(
                "Menu Vault could not activate status item for \(item.locator.bundleIdentifier)"
            )
            DispatchQueue.main.async { [weak self] in
                self?.show()
            }
        }
    }

    private var background: NSColor { NSColor(calibratedWhite: 0.055, alpha: 1) }
    private var panelColor: NSColor { NSColor(calibratedWhite: 0.09, alpha: 1) }
    private var border: NSColor { NSColor(calibratedWhite: 0.16, alpha: 1) }
    private var textColor: NSColor { NSColor(calibratedWhite: 0.96, alpha: 1) }
    private var secondary: NSColor { NSColor(calibratedWhite: 0.62, alpha: 1) }
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
        title = ""
        isBordered = false
        setButtonType(.momentaryChange)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
