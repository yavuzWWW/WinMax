import Cocoa

let output = CommandLine.arguments.dropFirst().first ?? "WinMax-DMG.png"
let size = NSSize(width: 720, height: 430)
let image = NSImage(size: size)

image.lockFocus()
let rect = NSRect(origin: .zero, size: size)
NSColor(calibratedWhite: 0.055, alpha: 1).setFill()
rect.fill()

let accent = NSColor(calibratedRed: 0.27, green: 0.83, blue: 0.74, alpha: 1)
let text = NSColor(calibratedWhite: 0.96, alpha: 1)
let secondary = NSColor(calibratedWhite: 0.64, alpha: 1)

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center

("WinMax" as NSString).draw(
    in: NSRect(x: 0, y: 330, width: size.width, height: 52),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: 34, weight: .bold),
        .foregroundColor: text,
        .paragraphStyle: paragraph
    ]
)

("Windows-style maximize for macOS" as NSString).draw(
    in: NSRect(x: 0, y: 302, width: size.width, height: 28),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: 14, weight: .medium),
        .foregroundColor: secondary,
        .paragraphStyle: paragraph
    ]
)

("Drag WinMax to Applications" as NSString).draw(
    in: NSRect(x: 0, y: 105, width: size.width, height: 30),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
        .foregroundColor: text,
        .paragraphStyle: paragraph
    ]
)

("VAST HOSTING" as NSString).draw(
    in: NSRect(x: 0, y: 30, width: size.width, height: 22),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: 11, weight: .bold),
        .foregroundColor: accent,
        .paragraphStyle: paragraph
    ]
)

let arrow = NSBezierPath()
arrow.lineWidth = 5
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
accent.setStroke()
arrow.move(to: NSPoint(x: 310, y: 215))
arrow.line(to: NSPoint(x: 410, y: 215))
arrow.line(to: NSPoint(x: 391, y: 232))
arrow.move(to: NSPoint(x: 410, y: 215))
arrow.line(to: NSPoint(x: 391, y: 198))
arrow.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Failed to render DMG background\n", stderr)
    exit(1)
}

try png.write(to: URL(fileURLWithPath: output))
