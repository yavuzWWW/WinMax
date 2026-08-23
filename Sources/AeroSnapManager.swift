import Cocoa
import ApplicationServices
import CoreGraphics

final class AeroSnapManager {
    static let shared = AeroSnapManager()

    enum Zone: Equatable {
        case maximize
        case leftHalf
        case rightHalf
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }

    private struct Session {
        let window: AXUIElement
        let key: String
        let mouseDown: CGPoint
        let frameAtMouseDown: CGRect
        let restoreFrame: CGRect?
        var restoredDuringDrag: Bool
    }

    private var eventTap: CFMachPort?
    private var source: CFRunLoopSource?
    private var permissionTimer: Timer?
    private var session: Session?
    private var restoreFrames: [String: CGRect] = [:]
    private let preview = SnapPreviewWindow()
    private let systemWide = AXUIElementCreateSystemWide()

    private init() {}

    func start() {
        installEventTapIfPossible()
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.installEventTapIfPossible()
        }
    }

    func stop() {
        permissionTimer?.invalidate()
        permissionTimer = nil
        cancel()
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        source = nil
        eventTap = nil
    }

    private func installEventTapIfPossible() {
        guard eventTap == nil, AXIsProcessTrusted() else { return }
        let mask = CGEventMask(
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue)
        )
        let callback: CGEventTapCallBack = { _, type, event, info in
            guard let info else { return Unmanaged.passUnretained(event) }
            let manager = Unmanaged<AeroSnapManager>.fromOpaque(info).takeUnretainedValue()
            manager.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        guard let eventTap else { return }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return
        }

        guard SettingsStore.shared.enabled, SettingsStore.shared.aeroSnapEnabled else {
            cancel()
            return
        }

        let point = event.location
        switch type {
        case .leftMouseDown:
            guard event.getIntegerValueField(.mouseEventClickState) == 1,
                  let window = window(at: point),
                  let windowFrame = frame(window),
                  isTitleBar(point, window: window, frame: windowFrame),
                  isResizable(window) else {
                cancel()
                return
            }
            begin(window: window, at: point)

        case .leftMouseDragged:
            drag(to: point)

        case .leftMouseUp:
            finish(at: point)

        default:
            break
        }
    }

    private func begin(window: AXUIElement, at point: CGPoint) {
        guard let current = frame(window) else { return }
        let id = key(window)
        session = Session(
            window: window,
            key: id,
            mouseDown: point,
            frameAtMouseDown: current,
            restoreFrame: restoreFrames[id],
            restoredDuringDrag: false
        )
    }

    private func drag(to point: CGPoint) {
        guard var active = session else {
            preview.hide()
            return
        }

        if !active.restoredDuringDrag,
           let restore = active.restoreFrame,
           hypot(point.x - active.mouseDown.x, point.y - active.mouseDown.y) >= 8 {
            var target = restore
            let ratio = max(0.12, min(0.88, (active.mouseDown.x - active.frameAtMouseDown.minX) / max(1, active.frameAtMouseDown.width)))
            let titleOffset = max(10, min(28, active.mouseDown.y - active.frameAtMouseDown.minY))
            target.origin.x = point.x - target.width * ratio
            target.origin.y = point.y - titleOffset
            if let visible = visibleFrame(forAXPoint: point) {
                target.origin.x = min(max(target.origin.x, visible.minX - target.width + 80), visible.maxX - 80)
                target.origin.y = min(max(target.origin.y, visible.minY), visible.maxY - 28)
            }
            setFrame(active.window, target)
            restoreFrames.removeValue(forKey: active.key)
            active.restoredDuringDrag = true
            session = active
        }

        guard let target = snapTarget(at: point) else {
            preview.hide()
            return
        }
        preview.show(axFrame: target.frame)
    }

    private func finish(at point: CGPoint) {
        defer {
            preview.hide()
            session = nil
        }
        guard let active = session,
              let target = snapTarget(at: point) else { return }

        if restoreFrames[active.key] == nil {
            if active.restoredDuringDrag, let current = frame(active.window) {
                restoreFrames[active.key] = current
            } else if let original = active.restoreFrame {
                restoreFrames[active.key] = original
            } else {
                restoreFrames[active.key] = active.frameAtMouseDown
            }
        }

        setFrame(active.window, target.frame)
        _ = AXUIElementPerformAction(active.window, kAXRaiseAction as CFString)
    }

    private func cancel() {
        preview.hide()
        session = nil
    }

    private func snapTarget(at point: CGPoint) -> (zone: Zone, frame: CGRect)? {
        guard let screen = screenInfo(forAXPoint: point) else { return nil }
        let full = screen.full
        let visible = screen.visible
        let edge: CGFloat = 18
        let cornerBand = min(max(100, visible.height * 0.20), 180)

        let nearLeft = point.x <= full.minX + edge
        let nearRight = point.x >= full.maxX - edge
        let nearTop = point.y <= full.minY + edge
        let nearBottom = point.y >= full.maxY - edge

        if nearTop && nearLeft && point.y <= full.minY + cornerBand {
            return (.topLeft, quarter(visible, left: true, top: true))
        }
        if nearTop && nearRight && point.y <= full.minY + cornerBand {
            return (.topRight, quarter(visible, left: false, top: true))
        }
        if nearBottom && nearLeft && point.y >= full.maxY - cornerBand {
            return (.bottomLeft, quarter(visible, left: true, top: false))
        }
        if nearBottom && nearRight && point.y >= full.maxY - cornerBand {
            return (.bottomRight, quarter(visible, left: false, top: false))
        }
        if nearLeft {
            return (.leftHalf, half(visible, left: true))
        }
        if nearRight {
            return (.rightHalf, half(visible, left: false))
        }
        if nearTop {
            return (.maximize, visible)
        }
        return nil
    }

    private func half(_ visible: CGRect, left: Bool) -> CGRect {
        let width = floor(visible.width / 2)
        return CGRect(
            x: left ? visible.minX : visible.maxX - width,
            y: visible.minY,
            width: width,
            height: visible.height
        )
    }

    private func quarter(_ visible: CGRect, left: Bool, top: Bool) -> CGRect {
        let width = floor(visible.width / 2)
        let height = floor(visible.height / 2)
        return CGRect(
            x: left ? visible.minX : visible.maxX - width,
            y: top ? visible.minY : visible.maxY - height,
            width: width,
            height: height
        )
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

    private func isTitleBar(_ point: CGPoint, window: AXUIElement, frame rect: CGRect) -> Bool {
        let titleHeight: CGFloat
        if let zoom = element(window, kAXZoomButtonAttribute), let zoomFrame = frame(zoom) {
            titleHeight = max(28, min(48, zoomFrame.maxY - rect.minY + 8))
        } else {
            titleHeight = 32
        }

        for attribute in [kAXCloseButtonAttribute, kAXMinimizeButtonAttribute, kAXZoomButtonAttribute] {
            if let button = element(window, attribute),
               let buttonFrame = frame(button),
               buttonFrame.insetBy(dx: -4, dy: -4).contains(point) {
                return false
            }
        }

        return CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: min(titleHeight, rect.height)).contains(point)
    }

    private func screenInfo(forAXPoint point: CGPoint) -> (full: CGRect, visible: CGRect)? {
        guard let primary = NSScreen.screens.first else { return nil }
        let primaryHeight = primary.frame.height
        let screens = NSScreen.screens.map {
            (full: toAX($0.frame, primaryHeight), visible: toAX($0.visibleFrame, primaryHeight))
        }
        return screens.first(where: { $0.full.contains(point) })
    }

    private func visibleFrame(forAXPoint point: CGPoint) -> CGRect? {
        screenInfo(forAXPoint: point)?.visible
    }

    private func toAX(_ rect: CGRect, _ primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    private func key(_ window: AXUIElement) -> String {
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        return "\(pid):\(CFHash(window))"
    }

    private func isResizable(_ window: AXUIElement) -> Bool {
        var value = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &value) == .success && value.boolValue
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

    private func setFrame(_ window: AXUIElement, _ rect: CGRect) {
        var point = rect.origin
        var size = rect.size
        guard let pointValue = AXValueCreate(.cgPoint, &point),
              let sizeValue = AXValueCreate(.cgSize, &size) else { return }
        _ = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pointValue)
        _ = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        _ = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pointValue)
    }

    private func element(_ source: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(source, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func string(_ source: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(source, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
}

private final class SnapPreviewWindow {
    private let panel: NSPanel

    init() {
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let view = NSView(frame: .zero)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(calibratedRed: 0.27, green: 0.83, blue: 0.74, alpha: 0.18).cgColor
        view.layer?.borderColor = NSColor(calibratedRed: 0.27, green: 0.83, blue: 0.74, alpha: 0.82).cgColor
        view.layer?.borderWidth = 2
        view.layer?.cornerRadius = 10
        panel.contentView = view
    }

    func show(axFrame: CGRect) {
        guard let primary = NSScreen.screens.first else { return }
        let cocoaFrame = CGRect(
            x: axFrame.minX,
            y: primary.frame.height - axFrame.maxY,
            width: axFrame.width,
            height: axFrame.height
        ).insetBy(dx: 4, dy: 4)
        panel.setFrame(cocoaFrame, display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}
