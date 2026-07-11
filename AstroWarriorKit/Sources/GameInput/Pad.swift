import GameSim

// A device-neutral SMS pad: the 8 logical inputs both the ROM and our sim understand.
// Keyboard, on-screen, and GameController all resolve down to a Set<PadButton>.
public enum PadButton: String, CaseIterable, Sendable, Codable {
    case up, down, left, right      // D-pad
    case button1, button2           // the two controller buttons (fire / secondary)
    case pause, reset               // SMS *console* buttons (not on the pad)
}

public extension Set where Element == PadButton {
    /// D-pad as a logical axis (+Y up), for our sim's directional input.
    var axis: Vec2 {
        Vec2((contains(.right) ? 1 : 0) - (contains(.left) ? 1 : 0),
             (contains(.up)    ? 1 : 0) - (contains(.down) ? 1 : 0))
    }
}

// Remappable key → button table. Codable so a Settings screen can persist edits later.
// Tokens are normalized key names ("leftArrow", "z", …) produced by the UI layer.
public struct KeyBindings: Sendable, Codable, Equatable {
    public var tokenForButton: [PadButton: String]
    public init(_ map: [PadButton: String]) { tokenForButton = map }

    public static let defaults = KeyBindings([
        .up: "upArrow", .down: "downArrow", .left: "leftArrow", .right: "rightArrow",
        .button1: "z", .button2: "x",       // fire / secondary
        .pause: "q", .reset: "w",            // console pause / reset
    ])

    /// Which button (if any) a normalized key token is bound to.
    public func button(forToken token: String) -> PadButton? {
        for (button, boundToken) in tokenForButton where boundToken == token { return button }
        return nil
    }

    public func token(for button: PadButton) -> String? { tokenForButton[button] }
}
