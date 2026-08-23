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

        // Corners must win over their overlapping half/maximize zones.
        expect(.topLeft, at: CGPoint(x: 18, y: 18), full: full, visible: visible)
        expect(.topRight, at: CGPoint(x: 1422, y: 18), full: full, visible: visible)

        // The trigger is inclusive at 18 px and inactive immediately outside it.
        expect(.leftHalf, at: CGPoint(x: 18, y: 450), full: full, visible: visible)
        expectNil(at: CGPoint(x: 19, y: 450), full: full, visible: visible)
        expect(.maximize, at: CGPoint(x: 720, y: 18), full: full, visible: visible)
        expectNil(at: CGPoint(x: 720, y: 19), full: full, visible: visible)

        expectNil(at: CGPoint(x: 720, y: 450), full: full, visible: visible)

        let odd = CGRect(x: 17, y: 31, width: 1001, height: 701)
        let left = SnapGeometry.frame(for: .leftHalf, visibleFrame: odd)
        let right = SnapGeometry.frame(for: .rightHalf, visibleFrame: odd)
        precondition(left.minX == odd.integral.minX, "Left half must start at visible minX")
        precondition(right.maxX == odd.integral.maxX, "Right half must end at visible maxX")
        precondition(left.maxX == right.minX, "Half-screen targets must meet without a gap")

        let topLeft = SnapGeometry.frame(for: .topLeft, visibleFrame: odd)
        let topRight = SnapGeometry.frame(for: .topRight, visibleFrame: odd)
        let bottomLeft = SnapGeometry.frame(for: .bottomLeft, visibleFrame: odd)
        let bottomRight = SnapGeometry.frame(for: .bottomRight, visibleFrame: odd)
        precondition(topLeft.maxY == bottomLeft.minY, "Left quarter targets must meet without a gap")
        precondition(topRight.maxY == bottomRight.minY, "Right quarter targets must meet without a gap")
        precondition(topLeft.maxX == topRight.minX, "Top quarter targets must meet without a gap")
        precondition(bottomLeft.maxX == bottomRight.minX, "Bottom quarter targets must meet without a gap")
        precondition(topLeft.minY == odd.integral.minY, "Top quarter must respect menu-bar offset")
        precondition(bottomLeft.maxY == odd.integral.maxY, "Bottom quarter must respect Dock offset")

        // External/left-side displays can use negative global X coordinates.
        let externalFull = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let externalVisible = CGRect(x: -1920, y: 25, width: 1920, height: 1015)
        expect(
            .leftHalf,
            at: CGPoint(x: -1919, y: 500),
            full: externalFull,
            visible: externalVisible
        )
        let externalRight = SnapGeometry.frame(for: .rightHalf, visibleFrame: externalVisible)
        precondition(externalRight.maxX == 0, "Negative-coordinate display must preserve its right edge")

        // Broken display data must never create a snap target.
        expectNil(
            at: CGPoint(x: 0, y: 0),
            full: CGRect(x: 0, y: 0, width: 0, height: 900),
            visible: visible
        )
        expectNil(
            at: CGPoint(x: 0, y: 0),
            full: full,
            visible: CGRect(x: 0, y: 0, width: 1440, height: 0)
        )

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
        precondition(
            result?.zone == zone,
            "Expected \(zone), got \(String(describing: result?.zone)) at \(point)"
        )
    }

    private static func expectNil(
        at point: CGPoint,
        full: CGRect,
        visible: CGRect
    ) {
        let result = SnapGeometry.target(
            at: point,
            fullFrame: full,
            visibleFrame: visible
        )
        precondition(result == nil, "Expected no snap target, got \(String(describing: result))")
    }
}
