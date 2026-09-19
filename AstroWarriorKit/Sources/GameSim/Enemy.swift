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

    // —— ROM magnitude+direction motion model (Wave-2a) ——————————————————————————
    // The ROM stores no signed velocity per enemy: it keeps per-axis step MAGNITUDES
    // (+0x0C/0D = |vy|, +0x0E/0F = |vx|) plus a 4-bit DIRECTION field (+0x02), and a single
    // shared integrator (0x0416, ported as Integrator.apply) applies them each frame with a
    // sign chosen by the direction bits. Handlers/behaviors set these; the integrator moves.
    public var stepX: Double = 0                   // |vx| px/frame (sim units)
    public var stepY: Double = 0                   // |vy| px/frame
    public var dirMask: UInt8 = 0                  // +0x02: bit0 up, bit1 down, bit2 left, bit3 right
    // FSM / flight-script scratch (per-enemy state the behaviors advance).
    public var motionPhase: Int = 0
    public var phaseTimer: Int = 0
    public var motionInited = false
    public var flightIndex: Int = 0                // current step in a flight script
    public var flightHold: Int = 0                 // frames left on the current flight step

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
        movement.step(self, ctx)      // handler: set stepX/stepY/dirMask (ROM model) or move directly (legacy)
        Integrator.apply(to: self)    // shared 0x0416 pass: apply magnitude×direction + off-screen despawn
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
