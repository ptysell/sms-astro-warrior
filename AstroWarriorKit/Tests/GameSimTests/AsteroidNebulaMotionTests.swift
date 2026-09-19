import Testing
@testable import GameSim

// Wave-3b — regression coverage for the 12 Asteroid/Nebula enemies ported to the ROM
// magnitude+direction model (docs/rom-decode-systems.md §velocity, cross-checked by the Sweep-1
// astneb-decode-spec decode/verify workflow). These lock the DETERMINISTIC, ROM-exact motion of the
// new movers — the un-confounded correctness signal (independent of the fire-always ParityScore tape).
struct AsteroidNebulaMotionTests {

    private func ctx(_ w: World) -> SimContext { SimContext(world: w, intent: Intent()) }

    // ── caborn (0x1F): pure straight-down integrator drift 1.0 px/f, no X, indestructible ────
    @Test func cabornStraightDescends() {
        let w = World()
        let e = Bestiary.caborn()
        e.position = Vec2(128, 190)
        e.update(ctx(w))                        // init sets dirMask=down, stepY=1.0, then integrate
        #expect(e.dirMask == MoveDir.down)
        #expect(abs(e.stepY - 1.0) < 1e-9)
        #expect(e.stepX == 0)
        #expect(e.position == Vec2(128, 189))   // −1.0 in y, x fixed
        for _ in 0..<5 { e.update(ctx(w)) }
        #expect(e.position.x == 128)            // never moves horizontally
        #expect(e.position.y == 184)            // 6 frames × 1.0
    }

    @Test func cabornIsIndestructible() {
        let w = World()
        let e = Bestiary.caborn()
        e.position = Vec2(128, 100)
        e.takeDamage(1, ctx(w))
        #expect(!e.isDead)                       // no death path in the ROM (+0x01=0xA0)
    }

    // ── aster (0x1B): centre-launch (X=128) diagonal fan, per-member decel to a straight fall ─
    @Test func asterFansFromCentreThenFalls() {
        let w = World()
        let e = Bestiary.aster()
        e.memberIndex = 0                        // member 0 = down-LEFT, decel 0.125 px/f²
        e.position = Vec2(60, 192)               // spawned off-centre; the ROM forces X=128
        e.update(ctx(w))
        #expect(e.dirMask == (MoveDir.down | MoveDir.left))
        #expect(abs(e.stepY - Tuning.asterVY) < 1e-9)   // 2.0
        // init forced X=128 then integrated left by |vx|=4.0 → 124; y 192→190.
        #expect(e.position == Vec2(124, 190))
        // |vx| decelerates by 0.125/frame; after 32 more frames it reaches 0 → straight down.
        for _ in 0..<40 { e.update(ctx(w)) }
        #expect(e.stepX == 0)
        #expect(e.dirMask == MoveDir.down)
    }

    // ── shamir (0x17): descend 1.0 until below the player, then homing ram at 0.9375 px/f ─────
    @Test func shamirDescendsThenRamsAtHalfAimSpeed() {
        let w = World()
        w.player.position = Vec2(128, 180)       // just below the spawn so it crosses quickly
        let e = Bestiary.shamir()
        e.position = Vec2(128, 192)
        e.update(ctx(w))
        #expect(e.dirMask == MoveDir.down)
        #expect(abs(e.stepY - Tuning.shamirDescend) < 1e-9)   // 1.0 descent
        // Descend until it drops below the player row, then it locks a homing ram.
        var frames = 0
        while e.motionPhase == 1 && frames < 60 { e.update(ctx(w)); frames += 1 }
        #expect(e.motionPhase == 2)              // reached the ram phase
        let total = (e.stepX * e.stepX + e.stepY * e.stepY).squareRoot()
        #expect(abs(total - Tuning.shamirRamSpeed) < 1e-6)    // 0.9375 = aim/2
    }

    // ── tinker (0x21): aim (1.875) × a random scale from the ROM table, then coast ────────────
    @Test func tinkerAimScaleDiveUsesROMScales() {
        let w = World()
        w.player.position = Vec2(200, 40)
        let e = Bestiary.tinker()
        e.position = Vec2(128, 192)
        e.update(ctx(w))                         // aims once and applies a random scale
        let total = (e.stepX * e.stepX + e.stepY * e.stepY).squareRoot()
        let scale = total / Tuning.aimUnitSpeed
        // scale must be exactly one of the loop-0 ROM table values {3.0,1.5,2.0,2.5}.
        #expect(Tuning.tinkerScalesLoop0.contains { abs($0 - scale) < 1e-6 })
        // Coasts: after aiming, the velocity is held (straight-line dive).
        let vx = e.stepX, vy = e.stepY
        e.update(ctx(w))
        #expect(e.stepX == vx && e.stepY == vy)
    }

    // ── ufolick (0x24): edge entry opposite the player, dive 2.0, reverse to up 4.0 + 6-shot fan ─
    @Test func ufolickEntersEdgeThenReversesAndBursts() {
        let w = World()
        w.step(Intent(fire: true))               // playing
        w.player.position = Vec2(200, 170)       // right half + high, so it reverses quickly
        let e = Bestiary.ufolick()
        e.position = Vec2(0, 192)
        e.update(ctx(w))
        #expect(e.position.x == Tuning.ufolickEntryLeftX)  // player right ⇒ enters LEFT edge (32)
        #expect(e.dirMask == MoveDir.down)
        #expect(abs(e.stepY - Tuning.ufolickDescend) < 1e-9)   // 2.0 dive
        // Descend to below the player row → reverse: dirMask up, 4.0, fire a one-shot 6-shot fan.
        var frames = 0
        while e.motionPhase == 0 && frames < 40 { e.update(ctx(w)); frames += 1 }
        #expect(e.dirMask == MoveDir.up)
        #expect(abs(e.stepY - Tuning.ufolickClimb) < 1e-9)     // 4.0 climb
        let ebullets = w.entities.compactMap { $0 as? Bullet }.filter { $0.side == .enemy }
        #expect(ebullets.count == 6)             // the burst fired exactly once
    }

    // ── triat (0x25): armored 8-HP straight descender + fixed 2-shot spread ───────────────────
    @Test func triatIsArmoredAndFiresSpread() {
        let w = World()
        let e = Bestiary.triat()
        #expect(e.hp == 8)                       // ROM +0x28 = 8
        e.position = Vec2(128, 190)
        e.update(ctx(w))                         // cooldown starts at 0 → fires on the first on-screen frame
        #expect(abs(e.stepY - Tuning.triatDescend) < 1e-9)     // 1.0 down
        #expect(e.stepX == 0)
        let ebullets = w.entities.compactMap { $0 as? Bullet }.filter { $0.side == .enemy }
        #expect(ebullets.count == 2)             // a symmetric 2-shot down-V (not aimed)
    }

    // ── dririt (0x20): self-split births a mirrored child via the pooled enemy-spawn primitive ─
    @Test func driritSplitsIntoAMirroredChild() {
        let w = World()
        let e = Bestiary.dririt()
        e.position = Vec2(128, 180)
        // descendFrames (16) then a split spawns a child of type dririt into the world.
        for _ in 0..<20 { e.update(ctx(w)) }
        let children = w.entities.compactMap { $0 as? Enemy }
        #expect(children.count >= 1)             // at least one mirror child spawned
        // A child inherits the mirrored horizontal direction (down+left/right, opposite the parent).
        #expect(children.allSatisfy { $0.dirMask & MoveDir.down != 0 })
    }

    // ── dilon (0x23): carrier launches a type-0x18 sharlin diver on flight-path P8/P9 ─────────
    @Test func dilonLaunchesFlightPathDivers() {
        let w = World()
        let e = Bestiary.dilon()
        e.position = Vec2(128, 180)
        for _ in 0..<24 { e.update(ctx(w)) }     // first diver launches at diverTimer==10 (~frame 23)
        let divers = w.entities.compactMap { $0 as? Enemy }
        #expect(divers.count >= 1)
        #expect(divers.allSatisfy { $0.flightPathIndex == 8 || $0.flightPathIndex == 9 })
    }

    // ── enemy-birth pool cap: children are hard-capped at the ROM 12-slot pool ─────────────────
    @Test func spawnPoolEnemyRespectsThePoolCap() {
        let w = World()
        for _ in 0..<Tuning.enemyPoolSlots { w.add(Bestiary.caborn()) }   // fill the pool
        let before = w.entities.count
        let ok = w.spawnPoolEnemy(Bestiary.dririt, at: Vec2(128, 100)) { _ in }
        #expect(!ok)                             // refused at the cap
        #expect(w.entities.count == before)      // nothing added
    }

    // ── content: pre-death waves carry the ROM per-member X + entry stagger ────────────────────
    @Test func nebulaTrickersUseEdgeColumnsAndStagger() {
        let neb = DefaultContent.nebula()
        // idx5 is the first cue: 2 trickers at the screen edges.
        let idx5 = neb.waves.first!
        #expect(idx5.wave.memberX == [16, 240])  // ROM edge columns, not centred
        // line/arc Ast/Neb waves get the per-member entry stagger; Galaxy does not.
        #expect(idx5.wave.entryStagger == Tuning.astNebEntryStagger)
        #expect(DefaultContent.galaxy().waves.allSatisfy { $0.wave.entryStagger == 0 })
    }
}
