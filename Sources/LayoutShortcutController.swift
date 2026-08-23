import Cocoa

final class LayoutShortcutController {
    static let shared = LayoutShortcutController()

    private var globalMonitor: Any?
    private var localMonitor: Any?

    private init() {}

    func start() {
        guard globalMonitor == nil, localMonitor == nil else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            _ = Self.handle(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            Self.handle(event) ? nil : event
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
    }

    @discardableResult
    private static func handle(_ event: NSEvent) -> Bool {
        guard SettingsStore.shared.enabled,
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
        }
        return true
    }
}
