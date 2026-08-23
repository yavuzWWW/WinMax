import Foundation

enum LayoutShortcutCommand: Equatable {
    case leftHalf
    case rightHalf
    case maximize
    case restore
    case previousDisplay
    case nextDisplay
}

enum LayoutShortcut {
    static func command(
        keyCode: UInt16,
        control: Bool,
        option: Bool,
        command: Bool,
        shift: Bool
    ) -> LayoutShortcutCommand? {
        guard control, option, command else { return nil }

        if shift {
            switch keyCode {
            case 123:
                return .previousDisplay
            case 124:
                return .nextDisplay
            default:
                return nil
            }
        }

        switch keyCode {
        case 123:
            return .leftHalf
        case 124:
            return .rightHalf
        case 125:
            return .restore
        case 126:
            return .maximize
        default:
            return nil
        }
    }
}
