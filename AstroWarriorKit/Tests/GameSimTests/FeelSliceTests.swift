import Testing
@testable import GameSim

// M1 vertical-slice behavior: firing, spawning, and bullet→enemy→score (§14-M1).
struct FeelSliceTests {

    @Test func titleStartIsEdgeTriggered() {
        let w = World()
        w.primeTitleFire(true)               // fire already held (e.g. carried across a reset)
        w.step(Intent(fire: true))
        #expect(w.mode == .title)            // held fire does NOT start
        w.step(Intent(fire: false))          // release
        w.step(Intent(fire: true))           // fresh press
        #expect(w.mode == .playing)          // now it starts
    }

    @Test func firesWhenFireHeld() {
        let w = World()
        w.mode = .playing
        w.step(Intent(fire: true))                 // fire held → fires
        #expect(w.entities.contains { ($0 as? Bullet)?.side == .player })
    }

    @Test func holdsFireWhenInputOff() {
        let w = World()
        w.mode = .playing
        w.step(Intent(fire: false))                // fire released → no shot (debugger title screen)
        #expect(!w.entities.contains { ($0 as? Bullet)?.side == .player })
    }

    @Test func enemyShootsAtPlayer() {
        let w = World()
        w.mode = .playing
        // Off to the side so the player's own auto-fire can't reach it.
        let e = Enemy(at: Vec2(40, 100), sprite: SpriteRef("t"), hitbox: .circle(r: 7),
                      hp: 9, points: 0, movement: Descend(speed: 0),
                      attack: AimedShot(interval: 2, bulletSpeed: 2))
        w.add(e)
        var saw = false
        for _ in 0..<8 {
            w.step(Intent(fire: false))
            if w.entities.contains(where: { ($0 as? Bullet)?.side == .enemy }) { saw = true; break }
        }
        #expect(saw)
    }

    @Test func lineFormationSpreadsAcross() {
        let p0 = WaveSpawner.position(.line, i: 0, count: 5, baseX: 128)
        let p4 = WaveSpawner.position(.line, i: 4, count: 5, baseX: 128)
        #expect(p0.x < p4.x)                        // spread left → right
        #expect(p0.y > LOGICAL_HEIGHT)              // enters above the field
    }

    @Test func streamStaggersOverTime() {
        let world = World()
        let spawner = WaveSpawner()
        let ctx = SimContext(world: world, intent: Intent())
        spawner.enqueue(Wave(make: Bestiary.cult, formation: .stream, count: 3, interval: 30), baseX: 128)
        spawner.update(world, ctx)
        #expect(world.entities.count == 1)          // only the first member yet
        for _ in 0..<30 { spawner.update(world, ctx) }
        #expect(world.entities.count == 2)          // second member after the interval
    }

    @Test func diveCommitsHeading() {
        let w = World()
        w.mode = .playing
        let e = Enemy(at: Vec2(60, 200), sprite: SpriteRef("t"), hitbox: .circle(r: 7),
                      hp: 9, points: 0, movement: Dive(speed: 1.5), attack: NoAttack())
        w.add(e)
        for _ in 0..<50 { w.step(Intent(fire: false)) }
        #expect(e.headingLocked)                    // descended past the commit line, then locked
    }

    @Test func bulletDestroysEnemyAndScores() {
        let w = World()
        w.mode = .playing
        // A stationary enemy and an overlapping player bullet.
        let e = Enemy(at: Vec2(100, 100), sprite: SpriteRef("test"), hitbox: .circle(r: 7),
                      hp: 2, points: 100, movement: Descend(speed: 0), attack: NoAttack())
        w.add(e)
        w.add(Bullet(at: Vec2(100, 100), velocity: .zero, side: .player, damage: 2,
                     sprite: SpriteRef("bullet")))
        w.step(Intent(fire: false))                // no new bullets; resolve the hit
        #expect(w.score == 100)
        #expect(!w.entities.contains { ($0 as? Enemy) === e })   // reaped
    }

    @Test func directorSpawnsEnemies() {
        let w = World()
        w.mode = .playing
        var sawEnemy = false
        for _ in 0..<200 {
            w.step(Intent(fire: false))
            if w.entities.contains(where: { $0 is Enemy }) { sawEnemy = true; break }
        }
        #expect(sawEnemy)
    }

    @Test func axisMovesAndClampsToField() {
        let w = World()
        w.mode = .playing
        let x0 = w.player.position.x
        w.step(Intent(moveAxis: Vec2(1, 0), fire: false))
        #expect(w.player.position.x > x0)                       // moved right
        for _ in 0..<400 { w.step(Intent(moveAxis: Vec2(1, 0), fire: false)) }
        #expect(w.player.position.x <= LOGICAL_WIDTH - 6 + 0.001) // clamped inside field
    }

    @Test func playerDeathLosesLifeAndEmitsHit() {
        let w = World()
        w.mode = .playing
        let e = Enemy(at: w.player.position, sprite: SpriteRef("test"), hitbox: .circle(r: 7),
                      hp: 1, points: 0, movement: Descend(speed: 0), attack: NoAttack())
        w.add(e)
        let lives0 = w.lives
        w.step(Intent(fire: false))
        #expect(w.lives == lives0 - 1)
        if case .playerHit = w.snapshot().events.first { } else {
            Issue.record("expected a playerHit event")
        }
    }

    @Test func drawSizeEqualsHitbox() {
        let w = World()
        let e = Enemy(at: Vec2(60, 100), sprite: SpriteRef("sz"), hitbox: .circle(r: 9),
                      hp: 9, points: 0, movement: Descend(speed: 0), attack: NoAttack())
        w.add(e)
        let draw = w.snapshot().sprites.first { $0.sprite.id == "sz" }
        #expect(draw?.size == Vec2(18, 18))         // 2 × radius — what you see is what collides
    }

    @Test func bossSpawnsAtStageEnd() {
        let w = World()
        w.mode = .playing
        w.spawnBoss(BossSpec(id: "zanoni", hp: 80))
        #expect(w.mode == .boss)
        #expect(w.entities.contains { $0 is Boss })
    }

    @Test func bossRingFires() {
        let w = World()
        w.mode = .playing
        w.spawnBoss(BossSpec(id: "zanoni", hp: 999))   // high hp so auto-fire can't kill it first
        var saw = false
        for _ in 0..<85 {
            w.step(Intent(fire: false))
            if w.entities.contains(where: { ($0 as? Bullet)?.side == .enemy }) { saw = true; break }
        }
        #expect(saw)
    }

    @Test func enemiesDescend() {
        let w = World()
        w.mode = .playing
        let e = Bestiary.curos()                    // Descend movement
        e.position = Vec2(128, 150); e.anchorX = 128
        w.add(e)
        let y0 = e.position.y
        for _ in 0..<10 { w.step(Intent(fire: false)) }
        #expect(e.position.y < y0)                  // moved down the screen
    }
}
