import Cocoa
import ApplicationServices

final class WindowLayoutStore {
    static let shared = WindowLayoutStore()

    enum Mode: Equatable {
        case maximized
        case snapped(SnapZone)
    }

    struct State {
        let pid: pid_t
        let restoreFrame: CGRect
        var managedFrame: CGRect
        var mode: Mode
    }

    private var states: [String: State] = [:]
    private let tolerance: CGFloat = 12

    private init() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            self?.removeStates(for: app.processIdentifier)
        }
    }

    var managedWindowCount: Int {
        states.count
    }

    func validState(for window: AXUIElement, currentFrame: CGRect) -> State? {
        let id = key(window)
        guard let state = states[id] else { return nil }

        guard approximatelyEqual(currentFrame, state.managedFrame, tolerance: tolerance) else {
            states.removeValue(forKey: id)
            return nil
        }

        return state
    }

    func record(
        window: AXUIElement,
        currentFrame: CGRect,
        targetFrame: CGRect,
        mode: Mode,
        preferredRestoreFrame: CGRect? = nil
    ) {
        let id = key(window)
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)

        let existing = states[id]
        let existingIsCurrent = existing.map {
            approximatelyEqual(currentFrame, $0.managedFrame, tolerance: tolerance)
        } ?? false

        let restoreFrame = preferredRestoreFrame
            ?? (existingIsCurrent ? existing?.restoreFrame : nil)
            ?? currentFrame

        states[id] = State(
            pid: pid,
            restoreFrame: restoreFrame,
            managedFrame: targetFrame,
            mode: mode
        )
    }

    func updateManagedFrame(for window: AXUIElement, frame: CGRect) {
        let id = key(window)
        guard var state = states[id] else { return }
        state.managedFrame = frame
        states[id] = state
    }

    func takeRestoreFrame(for window: AXUIElement, currentFrame: CGRect) -> CGRect? {
        guard validState(for: window, currentFrame: currentFrame) != nil else { return nil }
        return states.removeValue(forKey: key(window))?.restoreFrame
    }

    func clear(_ window: AXUIElement) {
        states.removeValue(forKey: key(window))
    }

    private func removeStates(for pid: pid_t) {
        states = states.filter { $0.value.pid != pid }
    }

    private func key(_ window: AXUIElement) -> String {
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        return "\(pid):\(CFHash(window))"
    }

    private func approximatelyEqual(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat) -> Bool {
        abs(lhs.minX - rhs.minX) <= tolerance
            && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }
}
