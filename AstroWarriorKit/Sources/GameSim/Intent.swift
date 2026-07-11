// Player input, normalized into logical terms before it reaches the sim (§7).
// The sim NEVER sees a UITouch / NSEvent / controller — only this.
public struct Intent: Sendable {
    public var moveTarget: Vec2?       // logical point the ship eases toward (pointer/touch)
    public var moveAxis: Vec2          // -1…1 directional input (keyboard / stick)
    public var fire: Bool              // auto-fire on in play
    public var special: Bool
    public var pause: Bool

    public init(moveTarget: Vec2? = nil, moveAxis: Vec2 = .zero,
                fire: Bool = true, special: Bool = false, pause: Bool = false) {
        self.moveTarget = moveTarget
        self.moveAxis = moveAxis
        self.fire = fire
        self.special = special
        self.pause = pause
    }
}
