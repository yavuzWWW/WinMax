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

        let relevant = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let required: NSEvent.ModifierFlags = [.control, .option, .command]
        guard relevant == required else { return false }

        switch event.keyCode {
        case 123: // Left Arrow
            WindowLayoutCommandController.shared.apply(.leftHalf)
        case 124: // Right Arrow
            WindowLayoutCommandController.shared.apply(.rightHalf)
        case 125: // Down Arrow
            WindowLayoutCommandController.shared.restore()
        case 126: // Up Arrow
            WindowLayoutCommandController.shared.apply(.maximize)
        default:
            return false
        }
        return true
    }
}
