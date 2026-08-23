import Cocoa
import ApplicationServices

/// Windows-style drag snapping. Mouse events are supplied by WindowController so
/// WinMax keeps a single CoreGraphics event tap for all window interactions.
final class AeroSnapManager {
    static let shared = AeroSnapManager()

    private struct Session {
        let window: AXUIElement
        let mouseDown: CGPoint
        let frameAtMouseDown: CGRect
        let managedStateAtMouseDown: WindowLayoutStore.State?
        var restoredDuringDrag = false
        var didDrag = false
    }

    private var session: Session?
    private let layoutStore = WindowLayoutStore.shared
    private let logger = WinMaxLogger.shared
    private let preview = SnapPreviewWindow()

    private init() {}

    func start() {}

    func stop() {
        cancel()
    }

    func begin(window: AXUIElement, frame currentFrame: CGRect, at point: CGPoint) {
        guard SettingsStore.shared.enabled,
              SettingsStore.shared.aeroSnapEnabled,
              isMovableAndResizable(window) else {
            cancel()
            return
        }

        session = Session(
            window: window,
            mouseDown: point,
            frameAtMouseDown: currentFrame,
            managedStateAtMouseDown: layoutStore.validState(
                for: window,
                currentFrame: currentFrame
            )
        )
    }

    func drag(to point: CGPoint) {
        guard SettingsStore.shared.enabled,
              SettingsStore.shared.aeroSnapEnabled,
              var active = session else {
            cancel()
            return
        }

        let distance = hypot(
            point.x - active.mouseDown.x,
            point.y - active.mouseDown.y
        )
        guard distance >= 5 else { return }
        active.didDrag = true

        if !active.restoredDuringDrag,
           let state = active.managedStateAtMouseDown {
            var restore = state.restoreFrame
            let ratio = max(
                0.12,
                min(
                    0.88,
                    (active.mouseDown.x - active.frameAtMouseDown.minX)
                        / max(1, active.frameAtMouseDown.width)
                )
            )
            let titleOffset = max(
                10,
                min(28, active.mouseDown.y - active.frameAtMouseDown.minY)
            )

            restore.origin = CGPoint(
                x: point.x - restore.width * ratio,
                y: point.y - titleOffset
            )

            if let visible = screenInfo(forAXPoint: point)?.visible {
                restore.origin.x = min(
                    max(restore.origin.x, visible.minX - restore.width + 80),
                    visible.maxX - 80
                )
                restore.origin.y = min(
                    max(restore.origin.y, visible.minY),
                    visible.maxY - 28
                )
            }

            if setFrame(active.window, restore) {
                layoutStore.clear(active.window)
                active.restoredDuringDrag = true
            } else {
                logger.warning("Aero Snap could not restore managed window during drag")
            }
        }

        session = active

        guard let target = target(at: point) else {
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

        guard SettingsStore.shared.enabled,
              SettingsStore.shared.aeroSnapEnabled,
              let active = session,
              active.didDrag,
              let target = target(at: point),
              let current = frame(active.window) else {
            return
        }

        layoutStore.record(
            window: active.window,
            currentFrame: current,
            targetFrame: target.frame,
            mode: target.zone == .maximize ? .maximized : .snapped(target.zone)
        )

        if setFrame(active.window, target.frame) {
            if let actual = frame(active.window) {
                layoutStore.updateManagedFrame(for: active.window, frame: actual)
            }
            _ = AXUIElementPerformAction(active.window, kAXRaiseAction as CFString)
        } else {
            layoutStore.clear(active.window)
            logger.warning("Aero Snap could not apply target frame")
        }
    }

    func cancel() {
        preview.hide()
        session = nil
    }

    private func target(at point: CGPoint) -> SnapTarget? {
        guard let screen = screenInfo(forAXPoint: point) else { return nil }
        return SnapGeometry.target(
            at: point,
            fullFrame: screen.full,
            visibleFrame: screen.visible
        )
    }

    private func screenInfo(forAXPoint point: CGPoint) -> (full: CGRect, visible: CGRect)? {
        guard let primary = NSScreen.screens.first else { return nil }
        let primaryHeight = primary.frame.height
        let screens = NSScreen.screens.map {
            (
                full: toAX($0.frame, primaryHeight),
                visible: toAX($0.visibleFrame, primaryHeight)
            )
        }

        if let exact = screens.first(where: { $0.full.contains(point) }) {
            return exact
        }

        return screens.min {
            distance(from: point, to: $0.full) < distance(from: point, to: $1.full)
        }
    }

    private func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return hypot(dx, dy)
    }

    private func toAX(_ rect: CGRect, _ primaryHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: primaryHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
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
        view.layer?.backgroundColor = NSColor(
            calibratedRed: 0.27,
            green: 0.83,
            blue: 0.74,
            alpha: 0.18
        ).cgColor
        view.layer?.borderColor = NSColor(
            calibratedRed: 0.27,
            green: 0.83,
            blue: 0.74,
            alpha: 0.82
        ).cgColor
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

        if panel.frame != cocoaFrame {
            panel.setFrame(cocoaFrame, display: true)
        }
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    func hide() {
        if panel.isVisible {
            panel.orderOut(nil)
        }
    }
}
