import Cocoa
import ApplicationServices
import CoreGraphics

final class WindowController {
    static let shared = WindowController()

    private struct DragCandidate {
        let window: AXUIElement
        let start: CGPoint
        let managedFrame: CGRect
        let restoreFrame: CGRect
    }

    private var eventTap: CFMachPort?
    private var source: CFRunLoopSource?
    private var trustTimer: Timer?
    private var swallowingMouse = false
    private var dragCandidate: DragCandidate?
    private var lastTrusted = false

    private let systemWide = AXUIElementCreateSystemWide()
    private let settings = SettingsStore.shared
    private let layoutStore = WindowLayoutStore.shared
    private let logger = WinMaxLogger.shared

    private(set) var isEventTapInstalled = false
    private(set) var isEventTapActive = false

    private init() {}

    func start() {
        lastTrusted = AXIsProcessTrusted()
        logger.info("Window controller starting; accessibility trusted=\(lastTrusted)")
        if lastTrusted { installEventTap() }

        trustTimer?.invalidate()
        trustTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshTrust()
        }
    }

    func stop() {
        trustTimer?.invalidate()
        trustTimer = nil
        uninstallEventTap()
    }

    func requestAccessibilityPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func toggleFrontmostWindow() {
        guard settings.enabled, let window = focusedWindow() else { return }
        toggleMaximize(window)
    }

    func restoreFrontmostWindow() {
        guard let window = focusedWindow(), let current = frame(window) else { return }
        guard let previous = layoutStore.takeRestoreFrame(for: window, currentFrame: current) else { return }
        if setFrame(window, previous) {
            _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        }
    }

    private func refreshTrust() {
        let trusted = AXIsProcessTrusted()

        if trusted != lastTrusted {
            lastTrusted = trusted
            logger.info("Accessibility trust changed: \(trusted)")
            trusted ? installEventTap() : uninstallEventTap()
            notifyState()
            return
        }

        if trusted, eventTap == nil {
            installEventTap()
        } else if let eventTap, !CGEvent.tapIsEnabled(tap: eventTap) {
            logger.warning("Window event tap was disabled; re-enabling")
            CGEvent.tapEnable(tap: eventTap, enable: true)
            isEventTapActive = true
            notifyState()
        }
    }

    private func installEventTap() {
        guard eventTap == nil, AXIsProcessTrusted() else { return }

        let mask = CGEventMask(
            (1 << CGEventType.leftMouseDown.rawValue)
                | (1 << CGEventType.leftMouseUp.rawValue)
                | (1 << CGEventType.leftMouseDragged.rawValue)
                | (1 << CGEventType.keyDown.rawValue)
        )

        let callback: CGEventTapCallBack = { _, type, event, info in
            guard let info else { return Unmanaged.passUnretained(event) }
            return Unmanaged<WindowController>
                .fromOpaque(info)
                .takeUnretainedValue()
                .handle(type, event)
        }

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap else {
            isEventTapInstalled = false
            isEventTapActive = false
            logger.error("Failed to create window event tap")
            notifyState()
            return
        }

        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let source {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }

        CGEvent.tapEnable(tap: eventTap, enable: true)
        isEventTapInstalled = true
        isEventTapActive = true
        logger.info("Window event tap installed")
        notifyState()
    }

    private func uninstallEventTap() {
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }

        source = nil
        eventTap = nil
        isEventTapInstalled = false
        isEventTapActive = false
        swallowingMouse = false
        dragCandidate = nil
        AeroSnapManager.shared.cancel()
        notifyState()
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
                isEventTapActive = true
                notifyState()
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown,
           settings.menuVaultEnabled,
           isMenuVaultShortcut(event) {
            DispatchQueue.main.async {
                MenuVaultController.shared.toggle()
            }
            return nil
        }

        guard settings.enabled else {
            swallowingMouse = false
            dragCandidate = nil
            AeroSnapManager.shared.cancel()
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown,
           settings.overrideFullscreenShortcut,
           isFullscreenShortcut(event) {
            DispatchQueue.main.async { [weak self] in
                self?.toggleFrontmostWindow()
            }
            return nil
        }

        if swallowingMouse {
            if type == .leftMouseUp {
                swallowingMouse = false
                dragCandidate = nil
            }
            if type == .leftMouseUp || type == .leftMouseDragged {
                return nil
            }
        }

        if type == .leftMouseDragged {
            if settings.aeroSnapEnabled {
                AeroSnapManager.shared.drag(to: event.location)
            }

            if let candidate = dragCandidate {
                let point = event.location
                if hypot(point.x - candidate.start.x, point.y - candidate.start.y) >= 6 {
                    restoreFromDrag(candidate, at: point)
                    dragCandidate = nil
                }
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .leftMouseUp {
            if settings.aeroSnapEnabled {
                AeroSnapManager.shared.finish(at: event.location)
            } else {
                AeroSnapManager.shared.cancel()
            }
            dragCandidate = nil
            return Unmanaged.passUnretained(event)
        }

        guard type == .leftMouseDown else {
            return Unmanaged.passUnretained(event)
        }

        let point = event.location
        guard let window = window(at: point) ?? focusedWindow(),
              let windowFrame = frame(window) else {
            return Unmanaged.passUnretained(event)
        }

        if settings.overrideGreenButton,
           let button = element(window, kAXZoomButtonAttribute),
           let buttonFrame = frame(button),
           buttonFrame.insetBy(dx: -3, dy: -3).contains(point) {
            swallowingMouse = true
            AeroSnapManager.shared.cancel()
            DispatchQueue.main.async { [weak self] in
                self?.toggleMaximize(window)
            }
            return nil
        }

        if settings.titleBarDoubleClick,
           event.getIntegerValueField(.mouseEventClickState) >= 2,
           isTitleBar(point, window, windowFrame) {
            swallowingMouse = true
            dragCandidate = nil
            AeroSnapManager.shared.cancel()
            DispatchQueue.main.async { [weak self] in
                self?.toggleMaximize(window)
            }
            return nil
        }

        if settings.aeroSnapEnabled,
           event.getIntegerValueField(.mouseEventClickState) == 1,
           isTitleBar(point, window, windowFrame) {
            AeroSnapManager.shared.begin(
                window: window,
                frame: windowFrame,
                at: point
            )
        } else {
            AeroSnapManager.shared.cancel()
        }

        if !settings.aeroSnapEnabled,
           event.getIntegerValueField(.mouseEventClickState) == 1,
           isTitleBar(point, window, windowFrame),
           let state = layoutStore.validState(for: window, currentFrame: windowFrame) {
            dragCandidate = DragCandidate(
                window: window,
                start: point,
                managedFrame: state.managedFrame,
                restoreFrame: state.restoreFrame
            )
        } else {
            dragCandidate = nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func toggleMaximize(_ window: AXUIElement) {
        guard isStandard(window) else { return }

        if isFullscreen(window) {
            guard setFullscreen(window, false) else {
                logger.warning("Could not leave native fullscreen before maximizing")
                return
            }
            waitForFullscreenExit(window, attemptsRemaining: 10)
            return
        }

        guard isMovableAndResizable(window),
              let current = frame(window),
              let target = visibleFrame(current) else {
            return
        }

        if approximatelyEqual(current, target) {
            guard let restore = layoutStore.takeRestoreFrame(
                for: window,
                currentFrame: current
            ) else {
                return
            }
            if setFrame(window, restore) {
                _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            }
            return
        }

        layoutStore.record(
            window: window,
            currentFrame: current,
            targetFrame: target,
            mode: .maximized
        )

        if setFrame(window, target) {
            if let actual = frame(window) {
                layoutStore.updateManagedFrame(for: window, frame: actual)
            }
            _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        } else {
            layoutStore.clear(window)
        }
    }

    private func waitForFullscreenExit(_ window: AXUIElement, attemptsRemaining: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }

            if !self.isFullscreen(window) {
                self.toggleMaximize(window)
                return
            }

            guard attemptsRemaining > 1 else {
                self.logger.warning("Timed out waiting for native fullscreen to exit")
                return
            }

            self.waitForFullscreenExit(window, attemptsRemaining: attemptsRemaining - 1)
        }
    }

    private func restoreFromDrag(_ candidate: DragCandidate, at point: CGPoint) {
        var rect = candidate.restoreFrame
        let ratio = max(
            0.12,
            min(
                0.88,
                (candidate.start.x - candidate.managedFrame.minX)
                    / max(1, candidate.managedFrame.width)
            )
        )
        let titleOffset = max(
            10,
            min(28, candidate.start.y - candidate.managedFrame.minY)
        )

        rect.origin = CGPoint(
            x: point.x - rect.width * ratio,
            y: point.y - titleOffset
        )

        if let visible = visibleFrame(
            CGRect(origin: point, size: CGSize(width: 1, height: 1))
        ) {
            rect.origin.x = min(
                max(rect.origin.x, visible.minX - rect.width + 80),
                visible.maxX - 80
            )
            rect.origin.y = min(
                max(rect.origin.y, visible.minY),
                visible.maxY - 28
            )
        }

        if setFrame(candidate.window, rect) {
            layoutStore.clear(candidate.window)
        }
    }

    private func window(at point: CGPoint) -> AXUIElement? {
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(
            systemWide,
            Float(point.x),
            Float(point.y),
            &hit
        ) == .success else {
            return nil
        }

        var current = hit
        for _ in 0..<12 {
            guard let candidate = current else { return nil }
            if string(candidate, kAXRoleAttribute) == (kAXWindowRole as String) {
                return candidate
            }
            current = element(candidate, kAXParentAttribute)
        }
        return nil
    }

    private func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return nil
        }
        return element(
            AXUIElementCreateApplication(app.processIdentifier),
            kAXFocusedWindowAttribute
        )
    }

    private func isTitleBar(
        _ point: CGPoint,
        _ window: AXUIElement,
        _ rect: CGRect
    ) -> Bool {
        let height: CGFloat
        if let zoom = element(window, kAXZoomButtonAttribute),
           let zoomFrame = frame(zoom) {
            height = max(28, min(48, zoomFrame.maxY - rect.minY + 8))
        } else {
            height = 32
        }

        for attribute in [
            kAXCloseButtonAttribute,
            kAXMinimizeButtonAttribute,
            kAXZoomButtonAttribute
        ] {
            if let button = element(window, attribute),
               let buttonFrame = frame(button),
               buttonFrame.insetBy(dx: -4, dy: -4).contains(point) {
                return false
            }
        }

        return CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: min(height, rect.height)
        ).contains(point)
    }

    private func isFullscreenShortcut(_ event: CGEvent) -> Bool {
        let flags = event.flags
        return event.getIntegerValueField(.keyboardEventKeycode) == 3
            && flags.contains(.maskCommand)
            && flags.contains(.maskControl)
            && !flags.contains(.maskAlternate)
            && !flags.contains(.maskShift)
    }

    private func isMenuVaultShortcut(_ event: CGEvent) -> Bool {
        let flags = event.flags
        return event.getIntegerValueField(.keyboardEventKeycode) == 9
            && flags.contains(.maskCommand)
            && flags.contains(.maskControl)
            && flags.contains(.maskAlternate)
            && !flags.contains(.maskShift)
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

    private func isFullscreen(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            window,
            kAXFullScreenAttribute as CFString,
            &value
        ) == .success else {
            return false
        }
        return (value as? Bool) ?? false
    }

    private func setFullscreen(_ window: AXUIElement, _ enabled: Bool) -> Bool {
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(
            window,
            kAXFullScreenAttribute as CFString,
            &settable
        ) == .success,
        settable.boolValue else {
            return false
        }

        return AXUIElementSetAttributeValue(
            window,
            kAXFullScreenAttribute as CFString,
            enabled ? kCFBooleanTrue : kCFBooleanFalse
        ) == .success
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

    @discardableResult
    private func setFrame(_ window: AXUIElement, _ rect: CGRect) -> Bool {
        var point = rect.origin
        var size = rect.size

        guard let pointValue = AXValueCreate(.cgPoint, &point),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            return false
        }

        let positionResult = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            pointValue
        )
        let sizeResult = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            sizeValue
        )
        let finalPositionResult = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            pointValue
        )

        let success = positionResult == .success
            && sizeResult == .success
            && finalPositionResult == .success

        if !success {
            logger.warning(
                "AX resize failed: position=\(positionResult.rawValue), "
                    + "size=\(sizeResult.rawValue), "
                    + "finalPosition=\(finalPositionResult.rawValue)"
            )
        }

        return success
    }

    private func visibleFrame(_ rect: CGRect) -> CGRect? {
        guard let primary = NSScreen.screens.first else { return nil }
        let primaryHeight = primary.frame.height

        let screens = NSScreen.screens.map {
            (
                full: toAX($0.frame, primaryHeight),
                visible: toAX($0.visibleFrame, primaryHeight)
            )
        }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        if let screen = screens.first(where: { $0.full.contains(center) }) {
            return screen.visible.integral
        }

        return screens.max {
            area($0.full.intersection(rect)) < area($1.full.intersection(rect))
        }?.visible.integral
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

    private func approximatelyEqual(
        _ lhs: CGRect,
        _ rhs: CGRect,
        _ tolerance: CGFloat = 4
    ) -> Bool {
        abs(lhs.minX - rhs.minX) <= tolerance
            && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }

    private func notifyState() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .winMaxRuntimeStateChanged,
                object: nil
            )
        }
    }
}
