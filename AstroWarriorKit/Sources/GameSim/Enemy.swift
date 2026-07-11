// One Enemy class configured with strategy objects + stats — composition over a deep
// inheritance tree (§5.3). New enemy = new configuration, not a new subclass.
public final class Enemy: Entity, Damageable, Faction {
    public let side = Side.enemy
    public var hp: Int                              // [extract] per type
    public let points: Int                          // [extract] per type
    public let movement: MovementBehavior
    public let attack: AttackBehavior
    public let indestructible: Bool                  // steel ball / invincible orb

    // Behavior scratch state (kept on the entity so strategies stay value types).
    public var age: Int = 0
    public var anchorX: Double = 0
    public var attackCooldown: Double = 0
    public var headingLocked = false               // for one-shot homing (Dive)

    public init(at p: Vec2, sprite: SpriteRef, hitbox: Hitbox,
                hp: Int, points: Int,
                movement: MovementBehavior, attack: AttackBehavior,
                indestructible: Bool = false) {
        self.hp = hp; self.points = points
        self.movement = movement; self.attack = attack
        self.indestructible = indestructible
        super.init(at: p, sprite: sprite, hitbox: hitbox)
        self.anchorX = p.x
    }

    public override func update(_ ctx: SimContext) {
        age += 1
        movement.step(self, ctx)
        attack.step(self, ctx)
    }

    public func takeDamage(_ amount: Int, _ ctx: SimContext) {
        guard !indestructible else { return }
        hp -= amount
        if hp <= 0 {
            ctx.world.addScore(points)
            ctx.world.emit(.explosion(pos: position))
            isDead = true
        }
    }
}
