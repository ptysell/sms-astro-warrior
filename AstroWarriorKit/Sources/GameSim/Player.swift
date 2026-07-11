// The player ship (§5.3). 1-hit death; form swapped on power-up via composition.
public final class Player: Entity, Damageable {
    public var hp = 1                              // 1-hit death  [extract: confirm]
    public var speed: Double                       // [extract] raised by speed-up pickups
    public var weapon: Weapon                       // composition: swapped on power-up
    public var drones: [Drone] = []                 // 0…2 options
    public var blocksDestroyed = 0                  // power-up ladder counter (reset on death)
    public var form: Int = 1                        // 1 single / 2 triple / 3 laser
    private var fireCooldown: Double = 0            // ticks until the next shot

    public init(at p: Vec2, speed: Double, weapon: Weapon) {
        self.speed = speed
        self.weapon = weapon
        super.init(at: p, sprite: SpriteRef("ship", frame: 0), hitbox: .circle(r: 6))
    }

    public override func update(_ ctx: SimContext) {
        let axis = ctx.intent.moveAxis
        if axis.x != 0 || axis.y != 0 {             // directional (keys / stick)
            // Per-axis movement (the ROM moves `speed` on each axis independently — diagonal
            // is faster). MEASURED: 1.5 px/frame per axis.
            position.x += max(-1, min(1, axis.x)) * speed
            position.y += max(-1, min(1, axis.y)) * speed
        } else if let target = ctx.intent.moveTarget {   // ease toward the input point (§7)
            let d = target - position
            let len = d.length
            if len > speed { position += (d / len) * speed } else { position = target }
        }
        clampToField()
        // Fires on cadence while the fire input is held. The game holds it permanently
        // (auto-fire, §2); the parity debugger drives it from Button 1 so both sides share input.
        if fireCooldown > 0 { fireCooldown -= 1 }
        if ctx.intent.fire, fireCooldown <= 0 {
            fire(ctx)
            fireCooldown = Tuning.shipFireInterval
        }
    }

    public func fire(_ ctx: SimContext) {
        weapon.fire(from: position, ctx)
        for drone in drones { drone.fire(ctx) }
    }

    public func takeDamage(_ amount: Int, _ ctx: SimContext) {
        hp -= amount
        if hp <= 0 { die(ctx) }
    }

    private func clampToField() {
        position.x = min(max(position.x, 6), LOGICAL_WIDTH - 6)
        position.y = min(max(position.y, 6), LOGICAL_HEIGHT - 6)
    }

    func die(_ ctx: SimContext) {
        isDead = true
        ctx.world.emit(.playerHit(pos: position))
        // Reset ladder + form on death (§5.10 / Appendix A).
        blocksDestroyed = 0
        form = 1
        ctx.world.onPlayerDied()
    }
}
