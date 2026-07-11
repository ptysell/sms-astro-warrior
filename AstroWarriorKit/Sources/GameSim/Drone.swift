// Follower drone / option (§5.7). Mirrors player offset; fires with the player.
public final class Drone: Entity {
    public weak var owner: Player?
    public var offset: Vec2                          // fixed logical offset from the ship
    public init(owner: Player, offset: Vec2) {
        self.owner = owner; self.offset = offset
        super.init(at: owner.position + offset, sprite: SpriteRef("drone"), hitbox: .circle(r: 3))
    }
    public override func update(_ ctx: SimContext) {
        if let o = owner { position = o.position + offset }
    }
    public func fire(_ ctx: SimContext) {
        // TODO(S4): mirror the owner's weapon. [extract]
    }
}
