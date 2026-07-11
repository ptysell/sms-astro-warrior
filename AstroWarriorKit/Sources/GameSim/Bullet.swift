// Projectile (§5.3). Side decides what it can damage.
public final class Bullet: Entity, Faction {
    public let side: Side
    public let damage: Int
    public init(at p: Vec2, velocity: Vec2, side: Side, damage: Int, sprite: SpriteRef) {
        self.side = side; self.damage = damage
        super.init(at: p, velocity: velocity, sprite: sprite, hitbox: .circle(r: 2))
    }
}
