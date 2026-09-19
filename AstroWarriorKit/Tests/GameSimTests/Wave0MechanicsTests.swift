import Testing
@testable import GameSim

// Wave-0 unblock: AABB collision, a KILLABLE boss that drives the LevelDirector past the
// first boss, and a game-over that restarts instead of dead-ending (§5.6 / §5.8 / §5.10).
struct Wave0MechanicsTests {

    // —— narrow-phase geometry ——————————————————————————————————————————————

    private func ent(_ p: Vec2, _ shape: Hitbox.Shape) -> Entity {
        Entity(at: p, sprite: SpriteRef("x"), hitbox: Hitbox(shape: shape))
    }

    @Test func circleCircleUnchanged() {
        // The M1 case must stay byte-identical: touching at exactly r1+r2 counts (inclusive).
        #expect(overlaps(ent(Vec2(0, 0), .circle(r: 5)), ent(Vec2(9, 0),  .circle(r: 5))))
        #expect(overlaps(ent(Vec2(0, 0), .circle(r: 5)), ent(Vec2(10, 0), .circle(r: 5))))  // == boundary
        #expect(!overlaps(ent(Vec2(0, 0), .circle(r: 5)), ent(Vec2(11, 0), .circle(r: 5))))
    }

    @Test func circleVsAABB() {
        let box = ent(Vec2(0, 0), .aabb(half: Vec2(16, 16)))
        #expect(overlaps(ent(Vec2(17, 0), .circle(r: 2)), box))     // 1px outside face, r=2 → touches
        #expect(!overlaps(ent(Vec2(20, 0), .circle(r: 2)), box))    // 4px outside face, r=2 → clear
        #expect(overlaps(ent(Vec2(17, 17), .circle(r: 2)), box))    // near a corner → touches
        #expect(overlaps(ent(Vec2(0, 0), .circle(r: 2)), box))      // centre inside → overlaps
    }

    @Test func aabbVsAABB() {
        let a = ent(Vec2(0, 0), .aabb(half: Vec2(10, 10)))
        #expect(overlaps(a, ent(Vec2(14, 0), .aabb(half: Vec2(5, 5)))))    // gap 14 <= 15
        #expect(overlaps(a, ent(Vec2(15, 0), .aabb(half: Vec2(5, 5)))))    // == boundary (inclusive)
        #expect(!overlaps(a, ent(Vec2(16, 0), .aabb(half: Vec2(5, 5)))))   // 16 > 15 → clear
        #expect(!overlaps(a, ent(Vec2(0, 21), .aabb(half: Vec2(5, 5)))))   // clear on the y axis
    }

    @Test func overlapIsSymmetric() {
        let c = ent(Vec2(17, 0), .circle(r: 2))
        let b = ent(Vec2(0, 0), .aabb(half: Vec2(16, 16)))
        #expect(overlaps(c, b) == overlaps(b, c))   // order must not matter
    }

    // —— the boss is now damageable to death ————————————————————————————————

    @Test func playerBulletsDamageBossToDeath() {
        let w = World()
        w.mode = .playing
        w.spawnBoss(BossSpec(id: "zanoni", hp: 3))          // AABB hitbox boss
        let boss = w.entities.compactMap { $0 as? Boss }.first
        #expect(boss != nil)
        #expect(!w.bossDefeated)

        // Three damage-1 player bullets sitting on the boss — one collision pass must kill it.
        for _ in 0..<3 {
            w.add(Bullet(at: boss!.position, velocity: .zero, side: .player,
                         damage: 1, sprite: SpriteRef("bullet")))
        }
        CollisionSystem().resolve(w, SimContext(world: w, intent: Intent(fire: false)))

        #expect(boss!.hp <= 0)
        #expect(boss!.isDead)                               // boss killed by player bullets
        #expect(w.bossDefeated)                             // Boss.takeDamage drove onBossDefeated()
    }

    // —— the director advances the zone once the boss dies —————————————————————

    private func tinyLevel(_ id: ZoneID, bossHP: Int) -> Level {
        // Long stride + tiny field so the director spawns the boss on the first playing tick.
        Level(id: id, scrollSpeed: 10, scrollLength: 5, waves: [],
              boss: BossSpec(id: "boss-\(id)", hp: bossHP),
              background: BackgroundRef("x"), music: "x")
    }

    @Test func directorAdvancesPastFirstBoss() {
        let campaign = Campaign(levels: [tinyLevel(.galaxy, bossHP: 2),
                                         tinyLevel(.asteroid, bossHP: 2)])
        let w = World(campaign: campaign)
        #expect(w.campaign.index == 0)

        w.step(Intent(fire: true))          // title → playing (edge)
        w.step(Intent(fire: false))         // first playing tick → director spawns the boss
        #expect(w.mode == .boss)
        let boss = w.entities.compactMap { $0 as? Boss }.first
        #expect(boss != nil)

        // Kill it with two damage-1 bullets, resolved on the next tick.
        w.add(Bullet(at: boss!.position, velocity: .zero, side: .player,
                     damage: 1, sprite: SpriteRef("bullet")))
        w.add(Bullet(at: boss!.position, velocity: .zero, side: .player,
                     damage: 1, sprite: SpriteRef("bullet")))
        w.step(Intent(fire: false))         // collision kills boss → onBossDefeated()
        #expect(w.bossDefeated)
        #expect(w.mode != .gameOver)

        // The director must observe bossDefeated, clear the stage, and advance the campaign.
        var advanced = false
        for _ in 0..<6 {
            w.step(Intent(fire: false))
            if w.campaign.index == 1 { advanced = true; break }
        }
        #expect(advanced)                   // .boss → .cleared → campaign.advance ran (zone 2)
    }

    // —— game-over is no longer a dead end ————————————————————————————————————

    @Test func gameOverRestartsOnFireEdge() {
        let w = World()
        w.mode = .gameOver
        w.lives = -1
        w.score = 12_345
        w.hiScore = 99_999
        w.add(Enemy(at: Vec2(50, 50), sprite: SpriteRef("t"), hitbox: .circle(r: 4),
                    hp: 1, points: 0, movement: Descend(speed: 0), attack: NoAttack()))
        w.primeTitleFire(false)             // no fire currently held

        w.step(Intent(fire: true))          // rising edge on game-over → restart
        #expect(w.mode == .title)           // back to the title, not stuck
        #expect(w.lives == Tuning.startingLives)   // lives reset
        #expect(w.score == 0)               // score reset
        #expect(w.hiScore == 99_999)        // hi-score persists across games
        #expect(w.campaign.index == 0)      // campaign back to zone 1
        #expect(!w.entities.contains { $0 is Enemy })   // field cleared

        // And a fresh game can actually start again.
        w.step(Intent(fire: false))         // release
        w.step(Intent(fire: true))          // fresh press
        #expect(w.mode == .playing)
    }

    @Test func gameOverRestartIsEdgeTriggered() {
        let w = World()
        w.mode = .gameOver
        w.lives = -1
        w.primeTitleFire(true)              // fire already held from the run that just ended

        w.step(Intent(fire: true))
        #expect(w.mode == .gameOver)        // held fire does NOT auto-restart
        w.step(Intent(fire: false))         // release
        w.step(Intent(fire: true))          // fresh press
        #expect(w.mode == .title)           // now it restarts
    }
}
