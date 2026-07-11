// Collision in the logical sim — never SpriteKit physics (§5.6).
// Broad phase: uniform grid; narrow phase: circle/AABB in logical units.
struct CollisionSystem {
    // M1: brute-force pairs at low entity counts.
    // TODO(S7): uniform-grid broad phase; powerup/block pairs; AABB cases.
    func resolve(_ world: World, _ ctx: SimContext) {
        let enemies = world.entities.compactMap { $0 as? Enemy }
        let bullets = world.entities.compactMap { $0 as? Bullet }

        // player-bullet ↔ enemy → enemy takes damage
        for b in bullets where b.side == .player && !b.isDead {
            for e in enemies where !e.isDead {
                if overlaps(b, e) {
                    e.takeDamage(b.damage, ctx)
                    b.isDead = true
                    break
                }
            }
        }

        // enemy bullet ↔ player → player dies (1-hit)
        guard !world.player.isDead else { return }
        for b in bullets where b.side == .enemy && !b.isDead {
            if overlaps(b, world.player) {
                b.isDead = true
                world.player.takeDamage(1, ctx)
                return
            }
        }

        // player ↔ enemy → player dies (1-hit)
        for e in enemies where !e.isDead {
            if overlaps(world.player, e) {
                world.player.takeDamage(1, ctx)
                return
            }
        }
    }
}

// Narrow-phase test shared by the grid pairs.
func overlaps(_ a: Entity, _ b: Entity) -> Bool {
    let pa = a.position + a.hitbox.offset
    let pb = b.position + b.hitbox.offset
    switch (a.hitbox.shape, b.hitbox.shape) {
    case let (.circle(ra), .circle(rb)):
        let d = pa - pb
        return d.length <= (ra + rb)
    default:
        // TODO(S7): circle/AABB and AABB/AABB cases.
        return false
    }
}
