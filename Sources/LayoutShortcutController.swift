import Cocoa
import ApplicationServices

final class LayoutShortcutController {
    static let shared = LayoutShortcutController()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var runtimeObserver: NSObjectProtocol?
    private var settingsObserver: NSObjectProtocol?

    private init() {}

    func start() {
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                Self.handle(event) ? nil : event
            }
        }

        if runtimeObserver == nil {
            runtimeObserver = NotificationCenter.default.addObserver(
                forName: .winMaxRuntimeStateChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refreshGlobalMonitor()
            }
        }

        if settingsObserver == nil {
            settingsObserver = NotificationCenter.default.addObserver(
                forName: .winMaxSettingsChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refreshGlobalMonitor()
            }
        }

        refreshGlobalMonitor()
    }

    func stop() {
        removeGlobalMonitor()
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        if let runtimeObserver {
            NotificationCenter.default.removeObserver(runtimeObserver)
        }
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
        localMonitor = nil
        runtimeObserver = nil
        settingsObserver = nil
    }

    private func refreshGlobalMonitor() {
        if AXIsProcessTrusted(), SettingsStore.shared.layoutShortcutsEnabled {
            installGlobalMonitorIfNeeded()
        } else {
            removeGlobalMonitor()
        }
    }

    private func installGlobalMonitorIfNeeded() {
        guard globalMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            _ = Self.handle(event)
        }
    }

    private func removeGlobalMonitor() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        globalMonitor = nil
    }

    @discardableResult
    private static func handle(_ event: NSEvent) -> Bool {
        guard SettingsStore.shared.enabled,
              SettingsStore.shared.layoutShortcutsEnabled,
              AXIsProcessTrusted(),
              event.type == .keyDown,
              event.isARepeat == false else {
            return false
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard let command = LayoutShortcut.command(
            keyCode: event.keyCode,
            control: flags.contains(.control),
            option: flags.contains(.option),
            command: flags.contains(.command),
            shift: flags.contains(.shift)
        ) else {
            return false
        }

        switch command {
        case .leftHalf:
            WindowLayoutCommandController.shared.apply(.leftHalf)
        case .rightHalf:
            WindowLayoutCommandController.shared.apply(.rightHalf)
        case .maximize:
            WindowLayoutCommandController.shared.apply(.maximize)
        case .restore:
            WindowLayoutCommandController.shared.restore()
        case .previousDisplay:
            WindowLayoutCommandController.shared.moveToDisplay(.previous)
        case .nextDisplay:
            WindowLayoutCommandController.shared.moveToDisplay(.next)
        }
        return true
    }
}
