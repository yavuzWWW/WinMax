import CoreGraphics

enum SnapZone: String, CaseIterable {
    case maximize
    case leftHalf
    case rightHalf
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

struct SnapTarget: Equatable {
    let zone: SnapZone
    let frame: CGRect
}

enum SnapGeometry {
    static func target(
        at point: CGPoint,
        fullFrame: CGRect,
        visibleFrame: CGRect,
        edgeThreshold: CGFloat = 18
    ) -> SnapTarget? {
        guard !fullFrame.isNull,
              !visibleFrame.isNull,
              fullFrame.width > 0,
              fullFrame.height > 0,
              visibleFrame.width > 0,
              visibleFrame.height > 0 else {
            return nil
        }

        let nearLeft = point.x <= fullFrame.minX + edgeThreshold
        let nearRight = point.x >= fullFrame.maxX - edgeThreshold
        let nearTop = point.y <= fullFrame.minY + edgeThreshold
        let nearBottom = point.y >= fullFrame.maxY - edgeThreshold

        if nearTop && nearLeft {
            return SnapTarget(zone: .topLeft, frame: frame(for: .topLeft, visibleFrame: visibleFrame))
        }
        if nearTop && nearRight {
            return SnapTarget(zone: .topRight, frame: frame(for: .topRight, visibleFrame: visibleFrame))
        }
        if nearBottom && nearLeft {
            return SnapTarget(zone: .bottomLeft, frame: frame(for: .bottomLeft, visibleFrame: visibleFrame))
        }
        if nearBottom && nearRight {
            return SnapTarget(zone: .bottomRight, frame: frame(for: .bottomRight, visibleFrame: visibleFrame))
        }
        if nearLeft {
            return SnapTarget(zone: .leftHalf, frame: frame(for: .leftHalf, visibleFrame: visibleFrame))
        }
        if nearRight {
            return SnapTarget(zone: .rightHalf, frame: frame(for: .rightHalf, visibleFrame: visibleFrame))
        }
        if nearTop {
            return SnapTarget(zone: .maximize, frame: visibleFrame.integral)
        }

        return nil
    }

    static func frame(for zone: SnapZone, visibleFrame: CGRect) -> CGRect {
        let visible = visibleFrame.integral
        let leftWidth = floor(visible.width / 2)
        let rightWidth = visible.width - leftWidth
        let topHeight = floor(visible.height / 2)
        let bottomHeight = visible.height - topHeight

        switch zone {
        case .maximize:
            return visible
        case .leftHalf:
            return CGRect(
                x: visible.minX,
                y: visible.minY,
                width: leftWidth,
                height: visible.height
            )
        case .rightHalf:
            return CGRect(
                x: visible.maxX - rightWidth,
                y: visible.minY,
                width: rightWidth,
                height: visible.height
            )
        case .topLeft:
            return CGRect(
                x: visible.minX,
                y: visible.minY,
                width: leftWidth,
                height: topHeight
            )
        case .topRight:
            return CGRect(
                x: visible.maxX - rightWidth,
                y: visible.minY,
                width: rightWidth,
                height: topHeight
            )
        case .bottomLeft:
            return CGRect(
                x: visible.minX,
                y: visible.maxY - bottomHeight,
                width: leftWidth,
                height: bottomHeight
            )
        case .bottomRight:
            return CGRect(
                x: visible.maxX - rightWidth,
                y: visible.maxY - bottomHeight,
                width: rightWidth,
                height: bottomHeight
            )
        }
    }
}
