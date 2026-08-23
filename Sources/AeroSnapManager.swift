import Cocoa
import ApplicationServices

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

    private var session: Session?
    private var restoreFrames: [String: CGRect] = [:]
    private let preview = SnapPreviewWindow()

    private init() {}

    func begin(window: AXUIElement, at point: CGPoint) {
        guard SettingsStore.shared.aeroSnapEnabled,
              isResizable(window),
              let current = frame(window) else {
            cancel()
            return
        }

        let id = key(window)
        let restore = restoreFrames[id]
        session = Session(
            window: window,
            key: id,
            mouseDown: point,
            frameAtMouseDown: current,
            restoreFrame: restore,
            restoredDuringDrag: false
        )
    }

    func drag(to point: CGPoint) {
        guard SettingsStore.shared.aeroSnapEnabled, var active = session else {
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

    func finish(at point: CGPoint) {
        defer {
            preview.hide()
            session = nil
        }
        guard SettingsStore.shared.aeroSnapEnabled,
              let active = session,
              let target = snapTarget(at: point) else { return }

        if restoreFrames[active.key] == nil {
            if active.restoredDuringDrag,
               let current = frame(active.window) {
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

    func cancel() {
        preview.hide()
        session = nil
    }

    private func snapTarget(at point: CGPoint) -> (zone: Zone, frame: CGRect)? {
        guard let screen = screenInfo(forAXPoint: point) else { return nil }
        let full = screen.full
        let visible = screen.visible
        let edge: CGFloat = 18
        let cornerBand = min(max(90, visible.height * 0.20), 180)

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
            return (.leftHalf, CGRect(x: visible.minX, y: visible.minY, width: floor(visible.width / 2), height: visible.height))
        }
        if nearRight {
            let width = floor(visible.width / 2)
            return (.rightHalf, CGRect(x: visible.maxX - width, y: visible.minY, width: width, height: visible.height))
        }
        if nearTop {
            return (.maximize, visible)
        }
        return nil
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
