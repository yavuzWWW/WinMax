import Cocoa
import ApplicationServices

final class WindowLayoutCommandController {
    static let shared = WindowLayoutCommandController()

    enum DisplayDirection {
        case previous
        case next
    }

    private struct ScreenInfo {
        let full: CGRect
        let visible: CGRect
    }

    private let settings = SettingsStore.shared
    private let layoutStore = WindowLayoutStore.shared
    private let logger = WinMaxLogger.shared

    private init() {}

    func apply(_ zone: SnapZone) {
        guard settings.enabled,
              AXIsProcessTrusted(),
              let window = focusedWindow(),
              isStandard(window),
              isMovableAndResizable(window),
              let current = frame(window),
              let visible = visibleFrame(for: current) else {
            return
        }

        let target = SnapGeometry.frame(for: zone, visibleFrame: visible)
        if approximatelyEqual(current, target) {
            return
        }

        layoutStore.record(
            window: window,
            currentFrame: current,
            targetFrame: target,
            mode: zone == .maximize ? .maximized : .snapped(zone)
        )

        if setFrame(window, target) {
            if let actual = frame(window) {
                layoutStore.updateManagedFrame(for: window, frame: actual)
            }
            _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        } else {
            layoutStore.clear(window)
            logger.warning("Keyboard layout command could not apply target frame")
        }
    }

    func restore() {
        guard settings.enabled,
              AXIsProcessTrusted(),
              let window = focusedWindow(),
              let current = frame(window),
              let restore = layoutStore.takeRestoreFrame(for: window, currentFrame: current) else {
            return
        }

        if setFrame(window, restore) {
            _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        } else {
            logger.warning("Keyboard layout command could not restore window")
        }
    }

    func moveToDisplay(_ direction: DisplayDirection) {
        guard settings.enabled,
              AXIsProcessTrusted(),
              let window = focusedWindow(),
              isStandard(window),
              isMovableAndResizable(window),
              let current = frame(window) else {
            return
        }

        let screens = screenInfos()
        guard screens.count > 1,
              let sourceIndex = screenIndex(for: current, in: screens) else {
            return
        }

        let destinationIndex: Int
        switch direction {
        case .previous:
            destinationIndex = sourceIndex == 0 ? screens.count - 1 : sourceIndex - 1
        case .next:
            destinationIndex = sourceIndex == screens.count - 1 ? 0 : sourceIndex + 1
        }

        let source = screens[sourceIndex]
        let destination = screens[destinationIndex]
        let managedState = layoutStore.validState(for: window, currentFrame: current)

        let target: CGRect
        let transferredRestore: CGRect?

        if let managedState {
            switch managedState.mode {
            case .maximized:
                target = SnapGeometry.frame(for: .maximize, visibleFrame: destination.visible)
            case .snapped(let zone):
                target = SnapGeometry.frame(for: zone, visibleFrame: destination.visible)
            }
            transferredRestore = DisplayTransferGeometry.transferredFrame(
                managedState.restoreFrame,
                from: source.visible,
                to: destination.visible
            )
        } else {
            target = DisplayTransferGeometry.transferredFrame(
                current,
                from: source.visible,
                to: destination.visible
            )
            transferredRestore = nil
        }

        guard setFrame(window, target) else {
            logger.warning("Could not move window to another display")
            return
        }

        if let managedState {
            layoutStore.record(
                window: window,
                currentFrame: current,
                targetFrame: target,
                mode: managedState.mode,
                preferredRestoreFrame: transferredRestore
            )
            if let actual = frame(window) {
                layoutStore.updateManagedFrame(for: window, frame: actual)
            }
        } else {
            layoutStore.clear(window)
        }

        _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }

    private func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return nil
        }

        var value: CFTypeRef?
        let application = AXUIElementCreateApplication(app.processIdentifier)
        guard AXUIElementCopyAttributeValue(
            application,
            kAXFocusedWindowAttribute as CFString,
            &value
        ) == .success,
        let value,
        CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func isStandard(_ window: AXUIElement) -> Bool {
        guard string(window, kAXRoleAttribute) == (kAXWindowRole as String) else {
            return false
        }
        guard let subrole = string(window, kAXSubroleAttribute) else {
            return true
        }
        return subrole == (kAXStandardWindowSubrole as String)
            || subrole == (kAXDialogSubrole as String)
    }

    private func isMovableAndResizable(_ window: AXUIElement) -> Bool {
        var sizeSettable = DarwinBoolean(false)
        var positionSettable = DarwinBoolean(false)
        let sizeResult = AXUIElementIsAttributeSettable(
            window,
            kAXSizeAttribute as CFString,
            &sizeSettable
        )
        let positionResult = AXUIElementIsAttributeSettable(
            window,
            kAXPositionAttribute as CFString,
            &positionSettable
        )
        return sizeResult == .success
            && positionResult == .success
            && sizeSettable.boolValue
            && positionSettable.boolValue
    }

    private func string(_ source: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(source, attribute as CFString, &value) == .success else {
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

    @discardableResult
    private func setFrame(_ window: AXUIElement, _ rect: CGRect) -> Bool {
        var point = rect.origin
        var size = rect.size
        guard let pointValue = AXValueCreate(.cgPoint, &point),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            return false
        }

        let position = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            pointValue
        )
        let sizeResult = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            sizeValue
        )
        let finalPosition = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            pointValue
        )
        return position == .success
            && sizeResult == .success
            && finalPosition == .success
    }

    private func visibleFrame(for rect: CGRect) -> CGRect? {
        let screens = screenInfos()
        guard let index = screenIndex(for: rect, in: screens) else { return nil }
        return screens[index].visible.integral
    }

    private func screenInfos() -> [ScreenInfo] {
        guard let primary = NSScreen.screens.first else { return [] }
        let primaryHeight = primary.frame.height

        return NSScreen.screens.map {
            ScreenInfo(
                full: toAX($0.frame, primaryHeight),
                visible: toAX($0.visibleFrame, primaryHeight).integral
            )
        }.sorted {
            if abs($0.full.minX - $1.full.minX) > 1 {
                return $0.full.minX < $1.full.minX
            }
            return $0.full.minY < $1.full.minY
        }
    }

    private func screenIndex(for rect: CGRect, in screens: [ScreenInfo]) -> Int? {
        guard !screens.isEmpty else { return nil }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        if let exact = screens.firstIndex(where: { $0.full.contains(center) }) {
            return exact
        }

        return screens.indices.max {
            area(screens[$0].full.intersection(rect)) < area(screens[$1].full.intersection(rect))
        }
    }

    private func toAX(_ rect: CGRect, _ primaryHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: primaryHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    private func area(_ rect: CGRect) -> CGFloat {
        rect.isNull ? 0 : rect.width * rect.height
    }

    private func approximatelyEqual(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat = 4) -> Bool {
        abs(lhs.minX - rhs.minX) <= tolerance
            && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }
}
