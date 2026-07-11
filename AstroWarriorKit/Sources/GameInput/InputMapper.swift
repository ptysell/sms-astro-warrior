import GameSim

// Maps platform input → Intent (§7). The sim never sees a UITouch / NSEvent / controller.
// Mac-first: pointer + keyboard + GameController paths all produce the same Intent.
public struct InputMapper {
    public init() {}

    /// Convert a pointer location (already in logical units) into an Intent.
    public func intent(pointerLogical: Vec2?, firing: Bool = true) -> Intent {
        Intent(moveTarget: pointerLogical, fire: firing)
    }

    // TODO(P3): touch drag-to-move (iOS), GameController stick/buttons, keyboard (Mac).
}
