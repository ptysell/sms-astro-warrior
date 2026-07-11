// Logical units throughout. One isolation domain (§9) — plain classes, no Sendable churn.

public enum Side: Sendable { case player, enemy, neutral }

public protocol Faction: AnyObject { var side: Side { get } }

public protocol Damageable: AnyObject {
    var hp: Int { get set }
    func takeDamage(_ amount: Int, _ ctx: SimContext)
}

open class Entity {
    public var position: Vec2
    public var velocity: Vec2          // logical units / tick
    public var hitbox: Hitbox
    public var sprite: SpriteRef
    public var isDead = false

    public init(at p: Vec2, velocity: Vec2 = .zero, sprite: SpriteRef, hitbox: Hitbox) {
        self.position = p
        self.velocity = velocity
        self.sprite = sprite
        self.hitbox = hitbox
    }

    /// Advance one tick. Default integrates velocity (§5.3).
    open func update(_ ctx: SimContext) { position += velocity }

    open func onHit(by other: Entity, _ ctx: SimContext) {}
}
