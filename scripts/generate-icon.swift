import AppKit
import Foundation

let arguments = CommandLine.arguments
let output = arguments.count > 1 ? arguments[1] : "build/WinMax.iconset"
let outputURL = URL(fileURLWithPath: output, isDirectory: true)
try? FileManager.default.removeItem(at: outputURL)
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

func render(size: Int, name: String) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "WinMaxIcon", code: 1)
    }

    bitmap.size = NSSize(width: size, height: size)
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "WinMaxIcon", code: 2)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    bounds.fill()

    NSColor(calibratedWhite: 0.055, alpha: 1).setFill()
    NSBezierPath(
        roundedRect: bounds.insetBy(dx: CGFloat(size) * 0.06, dy: CGFloat(size) * 0.06),
        xRadius: CGFloat(size) * 0.22,
        yRadius: CGFloat(size) * 0.22
    ).fill()

    let accent = NSColor(calibratedRed: 0.27, green: 0.83, blue: 0.74, alpha: 1)
    accent.setStroke()
    let outer = NSBezierPath(
        roundedRect: bounds.insetBy(dx: CGFloat(size) * 0.22, dy: CGFloat(size) * 0.25),
        xRadius: CGFloat(size) * 0.06,
        yRadius: CGFloat(size) * 0.06
    )
    outer.lineWidth = max(2, CGFloat(size) * 0.045)
    outer.stroke()

    let line = NSBezierPath()
    line.move(to: NSPoint(x: CGFloat(size) * 0.25, y: CGFloat(size) * 0.63))
    line.line(to: NSPoint(x: CGFloat(size) * 0.75, y: CGFloat(size) * 0.63))
    line.lineWidth = max(2, CGFloat(size) * 0.035)
    line.stroke()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: CGFloat(size) * 0.24, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph
    ]
    ("W" as NSString).draw(
        in: NSRect(x: 0, y: CGFloat(size) * 0.26, width: CGFloat(size), height: CGFloat(size) * 0.3),
        withAttributes: attrs
    )

    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "WinMaxIcon", code: 3)
    }
    try png.write(to: outputURL.appendingPathComponent(name))
}

for (pixels, name) in [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
] {
    try render(size: pixels, name: name)
}
