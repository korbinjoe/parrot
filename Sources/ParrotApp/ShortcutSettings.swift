import AppKit
import Carbon.HIToolbox

extension Notification.Name {
    static let parrotShortcutsDidChange = Notification.Name("parrotShortcutsDidChange")
}

enum ShortcutAction: String, CaseIterable, Identifiable {
    case selection
    case lookup
    case screenshot
    case input

    var id: String { rawValue }

    var title: String {
        switch self {
        case .selection: return "划词翻译"
        case .lookup: return "查词"
        case .screenshot: return "截图翻译"
        case .input: return "输入翻译"
        }
    }

    var defaultSpec: HotKeySpec {
        switch self {
        case .selection: return HotKeySpec(keyCode: UInt32(kVK_ANSI_D), modifiers: UInt32(optionKey))
        case .lookup: return HotKeySpec(keyCode: UInt32(kVK_ANSI_E), modifiers: UInt32(optionKey))
        case .screenshot: return HotKeySpec(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(optionKey))
        case .input: return HotKeySpec(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(optionKey))
        }
    }
}

struct HotKeySpec: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32

    var displayText: String {
        "\(modifierText)\(keyText)"
    }

    private var modifierText: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        return parts.joined()
    }

    private var keyText: String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_Space: return "Space"
        default: return "#\(keyCode)"
        }
    }

    static func from(event: NSEvent) -> HotKeySpec? {
        let carbon = event.modifierFlags.carbonHotKeyModifiers
        guard carbon != 0 else { return nil }
        return HotKeySpec(keyCode: UInt32(event.keyCode), modifiers: carbon)
    }
}

private extension NSEvent.ModifierFlags {
    var carbonHotKeyModifiers: UInt32 {
        var value: UInt32 = 0
        if contains(.control) { value |= UInt32(controlKey) }
        if contains(.option) { value |= UInt32(optionKey) }
        if contains(.command) { value |= UInt32(cmdKey) }
        if contains(.shift) { value |= UInt32(shiftKey) }
        return value
    }
}
