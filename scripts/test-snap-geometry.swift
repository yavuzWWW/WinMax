import CoreGraphics

@main
struct SnapGeometryTests {
    static func main() {
        let full = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let visible = CGRect(x: 0, y: 24, width: 1440, height: 836)

        expect(.maximize, at: CGPoint(x: 720, y: 1), full: full, visible: visible)
        expect(.leftHalf, at: CGPoint(x: 1, y: 450), full: full, visible: visible)
        expect(.rightHalf, at: CGPoint(x: 1439, y: 450), full: full, visible: visible)
        expect(.topLeft, at: CGPoint(x: 1, y: 1), full: full, visible: visible)
        expect(.topRight, at: CGPoint(x: 1439, y: 1), full: full, visible: visible)
        expect(.bottomLeft, at: CGPoint(x: 1, y: 899), full: full, visible: visible)
        expect(.bottomRight, at: CGPoint(x: 1439, y: 899), full: full, visible: visible)

        precondition(SnapGeometry.target(
            at: CGPoint(x: 720, y: 450),
            fullFrame: full,
            visibleFrame: visible
        ) == nil, "Center must not snap")

        let odd = CGRect(x: 17, y: 31, width: 1001, height: 701)
        let left = SnapGeometry.frame(for: .leftHalf, visibleFrame: odd)
        let right = SnapGeometry.frame(for: .rightHalf, visibleFrame: odd)
        precondition(left.minX == odd.integral.minX, "Left half must start at visible minX")
        precondition(right.maxX == odd.integral.maxX, "Right half must end at visible maxX")
        precondition(left.maxX == right.minX, "Half-screen targets must meet without a gap")

        let topLeft = SnapGeometry.frame(for: .topLeft, visibleFrame: odd)
        let bottomLeft = SnapGeometry.frame(for: .bottomLeft, visibleFrame: odd)
        precondition(topLeft.maxY == bottomLeft.minY, "Quarter targets must meet without a gap")
        precondition(topLeft.minY == odd.integral.minY, "Top quarter must respect menu-bar offset")
        precondition(bottomLeft.maxY == odd.integral.maxY, "Bottom quarter must respect Dock offset")

        print("SnapGeometry tests passed")
    }

    private static func expect(
        _ zone: SnapZone,
        at point: CGPoint,
        full: CGRect,
        visible: CGRect
    ) {
        let result = SnapGeometry.target(
            at: point,
            fullFrame: full,
            visibleFrame: visible
        )
        precondition(result?.zone == zone, "Expected \(zone), got \(String(describing: result?.zone))")
    }
}
