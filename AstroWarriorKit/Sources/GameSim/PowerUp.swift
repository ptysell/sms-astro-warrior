// Pickup that travels down the centre after enough blocks are destroyed (§5.7, App. A).
public final class PowerUp: Entity {
    public let kind: PowerUpKind
    public init(at p: Vec2, kind: PowerUpKind) {
        self.kind = kind
        super.init(at: p, velocity: Vec2(0, -1), sprite: SpriteRef("powerup"), hitbox: .circle(r: 5))
    }
}
