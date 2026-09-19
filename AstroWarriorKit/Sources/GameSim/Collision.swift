// Collision in the logical sim — never SpriteKit physics (§5.6).
// Broad phase: uniform grid; narrow phase: circle/AABB in logical units.
struct CollisionSystem {
    // Brute-force pairs at low entity counts (the roster is tiny). Narrow phase covers all
    // circle/AABB shape pairings. TODO(S7): uniform-grid broad phase; powerup/block pairs.
    func resolve(_ world: World, _ ctx: SimContext) {
        let enemies = world.entities.compactMap { $0 as? Enemy }
        let bosses  = world.entities.compactMap { $0 as? Boss }
        let bullets = world.entities.compactMap { $0 as? Bullet }

        // player-bullet ↔ enemy → enemy takes damage
        for b in bullets where b.side == .player && !b.isDead {
            var consumed = false
            for e in enemies where !e.isDead {
                if overlaps(b, e) {
                    e.takeDamage(b.damage, ctx)
                    b.isDead = true
                    consumed = true
                    break
                }
            }
            if consumed { continue }
            // player-bullet ↔ boss (AABB hitbox) → boss takes damage; at 0 hp Boss.takeDamage
            // flips world.bossDefeated via onBossDefeated(), which unblocks the LevelDirector.
            for boss in bosses where !boss.isDead {
                if overlaps(b, boss) {
                    boss.takeDamage(b.damage, ctx)
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

// Narrow-phase test shared by the grid pairs. All four shape pairings in logical units.
func overlaps(_ a: Entity, _ b: Entity) -> Bool {
    let pa = a.position + a.hitbox.offset
    let pb = b.position + b.hitbox.offset
    switch (a.hitbox.shape, b.hitbox.shape) {
    case let (.circle(ra), .circle(rb)):
        // Unchanged from M1 — kept byte-identical.
        let d = pa - pb
        return d.length <= (ra + rb)
    case let (.circle(r), .aabb(half)):
        return circleOverlapsAABB(center: pa, r: r, boxCenter: pb, half: half)
    case let (.aabb(half), .circle(r)):
        return circleOverlapsAABB(center: pb, r: r, boxCenter: pa, half: half)
    case let (.aabb(ha), .aabb(hb)):
        // Two AABBs overlap when they overlap on both axes (inclusive, matching circle/circle).
        let d = pa - pb
        return abs(d.x) <= (ha.x + hb.x) && abs(d.y) <= (ha.y + hb.y)
    }
}

// Circle ↔ AABB: nearest point on the box to the circle centre, then a radius test.
// Inclusive (<=) to match the circle/circle convention above.
private func circleOverlapsAABB(center: Vec2, r: Double, boxCenter: Vec2, half: Vec2) -> Bool {
    let minX = boxCenter.x - half.x, maxX = boxCenter.x + half.x
    let minY = boxCenter.y - half.y, maxY = boxCenter.y + half.y
    let nearestX = min(max(center.x, minX), maxX)
    let nearestY = min(max(center.y, minY), maxY)
    let dx = center.x - nearestX
    let dy = center.y - nearestY
    return (dx * dx + dy * dy) <= (r * r)
}
