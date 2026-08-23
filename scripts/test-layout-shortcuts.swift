import Foundation

@main
struct LayoutShortcutTests {
    static func main() {
        expect(resolve(123) == .leftHalf, "left arrow")
        expect(resolve(124) == .rightHalf, "right arrow")
        expect(resolve(125) == .restore, "down arrow")
        expect(resolve(126) == .maximize, "up arrow")
        expect(resolve(12) == nil, "unrelated key")

        expect(resolve(123, shift: true) == .previousDisplay, "shift-left moves to previous display")
        expect(resolve(124, shift: true) == .nextDisplay, "shift-right moves to next display")
        expect(resolve(125, shift: true) == nil, "shift-down remains unclaimed")
        expect(resolve(126, shift: true) == nil, "shift-up remains unclaimed")

        expect(LayoutShortcut.command(
            keyCode: 123,
            control: false,
            option: true,
            command: true,
            shift: false
        ) == nil, "control is required")

        expect(LayoutShortcut.command(
            keyCode: 123,
            control: true,
            option: false,
            command: true,
            shift: false
        ) == nil, "option is required")

        expect(LayoutShortcut.command(
            keyCode: 123,
            control: true,
            option: true,
            command: false,
            shift: false
        ) == nil, "command is required")

        print("Layout shortcut tests passed")
    }

    private static func resolve(_ keyCode: UInt16, shift: Bool = false) -> LayoutShortcutCommand? {
        LayoutShortcut.command(
            keyCode: keyCode,
            control: true,
            option: true,
            command: true,
            shift: shift
        )
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("Layout shortcut test failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
