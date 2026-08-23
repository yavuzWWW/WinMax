import CoreGraphics
import Foundation

@main
struct DisplayTransferTests {
    static func main() {
        let source = CGRect(x: 0, y: 24, width: 1920, height: 1056)
        let destination = CGRect(x: 1920, y: 24, width: 2560, height: 1416)

        let centered = CGRect(x: 560, y: 252, width: 800, height: 600)
        let moved = DisplayTransferGeometry.transferredFrame(centered, from: source, to: destination)
        expect(moved.minX >= destination.minX, "moved frame starts on destination")
        expect(moved.maxX <= destination.maxX, "moved frame ends on destination")
        expect(moved.minY >= destination.minY, "moved frame respects destination top")
        expect(moved.maxY <= destination.maxY, "moved frame respects destination bottom")
        expect(moved.size == centered.size, "normal frame keeps size when it fits")

        let left = CGRect(x: source.minX, y: source.minY, width: 900, height: 700)
        let leftMoved = DisplayTransferGeometry.transferredFrame(left, from: source, to: destination)
        expect(leftMoved.minX == destination.minX, "left-aligned frame stays left-aligned")
        expect(leftMoved.minY == destination.minY, "top-aligned frame stays top-aligned")

        let oversized = CGRect(x: 0, y: 0, width: 4000, height: 3000)
        let smallDestination = CGRect(x: -1280, y: 0, width: 1280, height: 720)
        let fitted = DisplayTransferGeometry.transferredFrame(oversized, from: source, to: smallDestination)
        expect(fitted.width == smallDestination.width, "oversized width is clamped")
        expect(fitted.height == smallDestination.height, "oversized height is clamped")
        expect(fitted.origin == smallDestination.origin, "oversized frame fills destination")

        let negativeSource = CGRect(x: -1440, y: -200, width: 1440, height: 900)
        let negativeWindow = CGRect(x: -1400, y: -150, width: 700, height: 500)
        let primary = CGRect(x: 0, y: 24, width: 1920, height: 1056)
        let fromNegative = DisplayTransferGeometry.transferredFrame(negativeWindow, from: negativeSource, to: primary)
        expect(primary.contains(CGPoint(x: fromNegative.midX, y: fromNegative.midY)), "negative-coordinate display transfers correctly")

        let invalid = CGRect.null
        expect(DisplayTransferGeometry.transferredFrame(centered, from: invalid, to: destination) == centered, "invalid source leaves frame unchanged")

        print("Display transfer tests passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("Display transfer test failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
