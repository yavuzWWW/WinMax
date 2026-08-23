import CoreGraphics

enum DisplayTransferGeometry {
    static func transferredFrame(
        _ frame: CGRect,
        from source: CGRect,
        to destination: CGRect
    ) -> CGRect {
        guard isUsable(source), isUsable(destination), !frame.isNull else {
            return frame
        }

        let width = min(max(1, frame.width), destination.width)
        let height = min(max(1, frame.height), destination.height)

        let sourceTravelX = max(0, source.width - frame.width)
        let sourceTravelY = max(0, source.height - frame.height)

        let relativeX = sourceTravelX > 0
            ? clamp((frame.minX - source.minX) / sourceTravelX)
            : 0.5
        let relativeY = sourceTravelY > 0
            ? clamp((frame.minY - source.minY) / sourceTravelY)
            : 0.5

        let destinationTravelX = max(0, destination.width - width)
        let destinationTravelY = max(0, destination.height - height)

        return CGRect(
            x: destination.minX + destinationTravelX * relativeX,
            y: destination.minY + destinationTravelY * relativeY,
            width: width,
            height: height
        ).integral
    }

    private static func isUsable(_ rect: CGRect) -> Bool {
        !rect.isNull && rect.width > 0 && rect.height > 0
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(1, max(0, value))
    }
}
