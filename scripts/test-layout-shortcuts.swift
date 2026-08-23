import Foundation

@main
struct LayoutShortcutTests {
    static func main() {
        expect(resolve(123) == .leftHalf, "left arrow")
        expect(resolve(124) == .rightHalf, "right arrow")
        expect(resolve(125) == .restore, "down arrow")
        expect(resolve(126) == .maximize, "up arrow")
        expect(resolve(12) == nil, "unrelated key")

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

        expect(LayoutShortcut.command(
            keyCode: 123,
            control: true,
            option: true,
            command: true,
            shift: true
        ) == nil, "shift variants remain unclaimed")

        print("Layout shortcut tests passed")
    }

    private static func resolve(_ keyCode: UInt16) -> LayoutShortcutCommand? {
        LayoutShortcut.command(
            keyCode: keyCode,
            control: true,
            option: true,
            command: true,
            shift: false
        )
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("Layout shortcut test failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
