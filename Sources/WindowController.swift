import Cocoa
import ApplicationServices
import CoreGraphics

final class WindowController {
    static let shared = WindowController()

    private struct DragCandidate {
        let window: AXUIElement
        let start: CGPoint
        let maximized: CGRect
        let restore: CGRect
    }

    private var eventTap: CFMachPort?
    private var source: CFRunLoopSource?
    private var trustTimer: Timer?
    private var restoreFrames: [String: CGRect] = [:]
    private var swallowingMouse = false
    private var dragCandidate: DragCandidate?
    private var lastTrusted = false
    private let systemWide = AXUIElementCreateSystemWide()
    private let settings = SettingsStore.shared
    private let logger = WinMaxLogger.shared

    private(set) var isEventTapInstalled = false
    private(set) var isEventTapActive = false
    private init() {}

    func start() {
        lastTrusted = AXIsProcessTrusted()
        logger.info("Window controller starting; accessibility trusted=\(lastTrusted)")
        if lastTrusted { installEventTap() }
        trustTimer?.invalidate()
        trustTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refreshTrust() }
    }

    func stop() { trustTimer?.invalidate(); trustTimer = nil; uninstallEventTap() }

    func requestAccessibilityPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    func toggleFrontmostWindow() {
        guard settings.enabled, let window = focusedWindow() else { return }
        toggleMaximize(window)
    }

    func restoreFrontmostWindow() {
        guard let window = focusedWindow() else { return }
        restore(window)
    }

    private func refreshTrust() {
        let trusted = AXIsProcessTrusted()
        if trusted != lastTrusted {
            lastTrusted = trusted
            logger.info("Accessibility trust changed: \(trusted)")
            trusted ? installEventTap() : uninstallEventTap()
            notifyState()
        } else if trusted, eventTap == nil {
            installEventTap()
        } else if let eventTap, !CGEvent.tapIsEnabled(tap: eventTap) {
            logger.warning("Event tap was disabled; re-enabling")
            CGEvent.tapEnable(tap: eventTap, enable: true)
            isEventTapActive = true
            notifyState()
        }
    }

    private func installEventTap() {
        guard eventTap == nil, AXIsProcessTrusted() else { return }
        let mask = CGEventMask(
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.keyDown.rawValue)
        )
        let callback: CGEventTapCallBack = { _, type, event, info in
            guard let info else { return Unmanaged.passUnretained(event) }
            return Unmanaged<WindowController>.fromOpaque(info).takeUnretainedValue().handle(type, event)
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
            isEventTapInstalled = false; isEventTapActive = false
            logger.error("Failed to create event tap"); notifyState(); return
        }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        isEventTapInstalled = true; isEventTapActive = true
        logger.info("Event tap installed"); notifyState()
    }

    private func uninstallEventTap() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false); CFMachPortInvalidate(eventTap) }
        source = nil; eventTap = nil; isEventTapInstalled = false; isEventTapActive = false
        swallowingMouse = false; dragCandidate = nil; notifyState()
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true); isEventTapActive = true; notifyState() }
            return Unmanaged.passUnretained(event)
        }
        guard settings.enabled else { return Unmanaged.passUnretained(event) }

        if type == .keyDown, settings.overrideFullscreenShortcut, isFullscreenShortcut(event) {
            DispatchQueue.main.async { [weak self] in self?.toggleFrontmostWindow() }
            return nil
        }

        if swallowingMouse {
            if type == .leftMouseUp { swallowingMouse = false; dragCandidate = nil }
            if type == .leftMouseUp || type == .leftMouseDragged { return nil }
        }

        if type == .leftMouseDragged, let candidate = dragCandidate {
            let point = event.location
            if hypot(point.x - candidate.start.x, point.y - candidate.start.y) >= 6 {
                restoreFromDrag(candidate, at: point); dragCandidate = nil
            }
            return Unmanaged.passUnretained(event)
        }
        if type == .leftMouseUp { dragCandidate = nil; return Unmanaged.passUnretained(event) }
        guard type == .leftMouseDown else { return Unmanaged.passUnretained(event) }

        let point = event.location
        guard let window = window(at: point) ?? focusedWindow(), let windowFrame = frame(window) else {
            return Unmanaged.passUnretained(event)
        }

        if settings.overrideGreenButton,
           let button = element(window, kAXZoomButtonAttribute), let rect = frame(button),
           rect.insetBy(dx: -3, dy: -3).contains(point) {
            swallowingMouse = true
            DispatchQueue.main.async { [weak self] in self?.toggleMaximize(window) }
            return nil
        }

        if settings.titleBarDoubleClick,
           event.getIntegerValueField(.mouseEventClickState) >= 2,
           isTitleBar(point, window, windowFrame) {
            swallowingMouse = true; dragCandidate = nil
            DispatchQueue.main.async { [weak self] in self?.toggleMaximize(window) }
            return nil
        }

        if event.getIntegerValueField(.mouseEventClickState) == 1,
           isTitleBar(point, window, windowFrame),
           let target = visibleFrame(windowFrame), approximatelyEqual(windowFrame, target),
           let restore = restoreFrames[key(window)] {
            dragCandidate = DragCandidate(window: window, start: point, maximized: windowFrame, restore: restore)
        } else { dragCandidate = nil }
        return Unmanaged.passUnretained(event)
    }

    private func toggleMaximize(_ window: AXUIElement) {
        guard isStandard(window) else { return }
        if isFullscreen(window) {
            guard setFullscreen(window, false) else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self, !self.isFullscreen(window) else { return }
                self.toggleMaximize(window)
            }
            return
        }
        guard isResizable(window), let current = frame(window), let target = visibleFrame(current) else { return }
        let id = key(window)
        if approximatelyEqual(current, target) {
            if let previous = restoreFrames.removeValue(forKey: id) { setFrame(window, previous) }
        } else {
            restoreFrames[id] = current
            setFrame(window, target)
        }
        _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }

    private func restore(_ window: AXUIElement) {
        guard let previous = restoreFrames.removeValue(forKey: key(window)) else { return }
        setFrame(window, previous); _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }

    private func restoreFromDrag(_ candidate: DragCandidate, at point: CGPoint) {
        var rect = candidate.restore
        let ratio = max(0.12, min(0.88, (candidate.start.x - candidate.maximized.minX) / max(1, candidate.maximized.width)))
        let titleOffset = max(10, min(28, candidate.start.y - candidate.maximized.minY))
        rect.origin = CGPoint(x: point.x - rect.width * ratio, y: point.y - titleOffset)
        if let visible = visibleFrame(CGRect(origin: point, size: CGSize(width: 1, height: 1))) {
            rect.origin.x = min(max(rect.origin.x, visible.minX - rect.width + 80), visible.maxX - 80)
            rect.origin.y = min(max(rect.origin.y, visible.minY), visible.maxY - 28)
        }
        setFrame(candidate.window, rect); restoreFrames.removeValue(forKey: key(candidate.window))
    }

    private func window(at point: CGPoint) -> AXUIElement? {
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &hit) == .success else { return nil }
        var current = hit
        for _ in 0..<12 {
            guard let candidate = current else { return nil }
            if string(candidate, kAXRoleAttribute) == (kAXWindowRole as String) { return candidate }
            current = element(candidate, kAXParentAttribute)
        }
        return nil
    }

    private func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        return element(AXUIElementCreateApplication(app.processIdentifier), kAXFocusedWindowAttribute)
    }

    private func isTitleBar(_ point: CGPoint, _ window: AXUIElement, _ rect: CGRect) -> Bool {
        let height: CGFloat
        if let zoom = element(window, kAXZoomButtonAttribute), let zr = frame(zoom) { height = max(28, min(48, zr.maxY - rect.minY + 8)) }
        else { height = 32 }
        for attribute in [kAXCloseButtonAttribute, kAXMinimizeButtonAttribute, kAXZoomButtonAttribute] {
            if let button = element(window, attribute), let br = frame(button), br.insetBy(dx: -4, dy: -4).contains(point) { return false }
        }
        return CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: min(height, rect.height)).contains(point)
    }

    private func isFullscreenShortcut(_ event: CGEvent) -> Bool {
        let flags = event.flags
        return event.getIntegerValueField(.keyboardEventKeycode) == 3 && flags.contains(.maskCommand) && flags.contains(.maskControl)
            && !flags.contains(.maskAlternate) && !flags.contains(.maskShift)
    }

    private func isStandard(_ window: AXUIElement) -> Bool {
        guard string(window, kAXRoleAttribute) == (kAXWindowRole as String) else { return false }
        guard let subrole = string(window, kAXSubroleAttribute) else { return true }
        return subrole == (kAXStandardWindowSubrole as String) || subrole == (kAXDialogSubrole as String)
    }

    private func isResizable(_ window: AXUIElement) -> Bool {
        var value = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &value) == .success && value.boolValue
    }

    private func isFullscreen(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXFullScreenAttribute as CFString, &value) == .success else { return false }
        return (value as? Bool) ?? false
    }

    private func setFullscreen(_ window: AXUIElement, _ enabled: Bool) -> Bool {
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(window, kAXFullScreenAttribute as CFString, &settable) == .success, settable.boolValue else { return false }
        return AXUIElementSetAttributeValue(window, kAXFullScreenAttribute as CFString, enabled ? kCFBooleanTrue : kCFBooleanFalse) == .success
    }

    private func element(_ source: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(source, attribute as CFString, &value) == .success, let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func string(_ source: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(source, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func frame(_ source: AXUIElement) -> CGRect? {
        var pv: CFTypeRef?; var sv: CFTypeRef?
        guard AXUIElementCopyAttributeValue(source, kAXPositionAttribute as CFString, &pv) == .success,
              AXUIElementCopyAttributeValue(source, kAXSizeAttribute as CFString, &sv) == .success,
              let pv, let sv, CFGetTypeID(pv) == AXValueGetTypeID(), CFGetTypeID(sv) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero; var size = CGSize.zero
        guard AXValueGetValue(unsafeBitCast(pv, to: AXValue.self), .cgPoint, &point),
              AXValueGetValue(unsafeBitCast(sv, to: AXValue.self), .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }

    private func setFrame(_ window: AXUIElement, _ rect: CGRect) {
        var point = rect.origin; var size = rect.size
        guard let pv = AXValueCreate(.cgPoint, &point), let sv = AXValueCreate(.cgSize, &size) else { return }
        let pr = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pv)
        let sr = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sv)
        _ = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pv)
        if pr != .success || sr != .success { logger.warning("AX resize failed: position=\(pr.rawValue), size=\(sr.rawValue)") }
    }

    private func visibleFrame(_ rect: CGRect) -> CGRect? {
        guard let primary = NSScreen.screens.first else { return nil }
        let primaryHeight = primary.frame.height
        let screens = NSScreen.screens.map { (full: toAX($0.frame, primaryHeight), visible: toAX($0.visibleFrame, primaryHeight)) }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        if let screen = screens.first(where: { $0.full.contains(center) }) { return screen.visible.integral }
        return screens.max(by: { area($0.full.intersection(rect)) < area($1.full.intersection(rect)) })?.visible.integral
    }

    private func toAX(_ rect: CGRect, _ primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }
    private func area(_ rect: CGRect) -> CGFloat { rect.isNull ? 0 : rect.width * rect.height }
    private func approximatelyEqual(_ a: CGRect, _ b: CGRect, _ t: CGFloat = 4) -> Bool {
        abs(a.minX-b.minX) <= t && abs(a.minY-b.minY) <= t && abs(a.width-b.width) <= t && abs(a.height-b.height) <= t
    }
    private func key(_ window: AXUIElement) -> String { var pid: pid_t = 0; AXUIElementGetPid(window, &pid); return "\(pid):\(CFHash(window))" }
    private func notifyState() { DispatchQueue.main.async { NotificationCenter.default.post(name: .winMaxRuntimeStateChanged, object: nil) } }
}
