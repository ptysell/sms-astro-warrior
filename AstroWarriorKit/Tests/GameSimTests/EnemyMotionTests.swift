import Testing
@testable import GameSim

// Wave-2a — regression coverage for the ROM magnitude+direction enemy-motion model
// (docs/rom-decode-systems.md §"Enemy movement model" and §"Stream flight-path script engine").
// These lock the decoded behaviour of the shared integrator, the aim primitive, the flight-path
// script engine, and the rewired Galaxy grunts (cult / zanix / sharlin).
struct EnemyMotionTests {

    private func ctx(_ w: World) -> SimContext { SimContext(world: w, intent: Intent()) }

    // ── Shared integrator (ROM 0x0416): magnitude × direction, ROM despawn bounds ──────────
    @Test func integratorAppliesDirectionAndMagnitude() {
        let e = Bestiary.cult()
        e.dirMask = MoveDir.down; e.stepY = 2; e.stepX = 0
        e.position = Vec2(128, 100)
        Integrator.apply(to: e)
        #expect(e.position.y == 98)            // ROM Y+ (screen-down) = sim −y
        #expect(!e.isDead)

        let r = Bestiary.cult()
        r.dirMask = MoveDir.right; r.stepX = 3
        r.position = Vec2(120, 100)
        Integrator.apply(to: r)
        #expect(r.position.x == 123)           // ROM X+ = sim +x
    }

    @Test func integratorDespawnsOnROMBounds() {
        // Bottom: screen-Y ≥ 200  ⇒  sim y ≤ LOGICAL_HEIGHT − 200 = −8.
        let bottom = Bestiary.cult()
        bottom.dirMask = MoveDir.down; bottom.stepY = 2
        bottom.position = Vec2(128, -7)        // screen-Y 199
        Integrator.apply(to: bottom)
        #expect(bottom.isDead)

        // Right edge: X ≥ 248.
        let right = Bestiary.cult()
        right.dirMask = MoveDir.right; right.stepX = 3
        right.position = Vec2(246, 100)
        Integrator.apply(to: right)
        #expect(right.isDead)

        // Left edge: X < 16.
        let left = Bestiary.cult()
        left.dirMask = MoveDir.left; left.stepX = 3
        left.position = Vec2(17, 100)
        Integrator.apply(to: left)
        #expect(left.isDead)
    }

    @Test func integratorNoOpForLegacyBehaviors() {
        let e = Bestiary.aster()               // legacy Weave mover → dirMask stays 0
        e.position = Vec2(100, 100)
        Integrator.apply(to: e)                // must not move or despawn
        #expect(e.position == Vec2(100, 100))
        #expect(!e.isDead)
    }

    // ── Aim primitive (ROM 0x18fd, constant 1.875 px/f toward the player) ───────────────────
    @Test func aimIsConstantSpeedTowardPlayer() {
        let w = World()
        w.player.position = Vec2(200, 48)      // player below-right of the enemy
        let e = Bestiary.cult()
        e.position = Vec2(128, 200)
        Aim.lock(e, toward: w.player.position)
        // Total speed is the ROM unit 1.875, regardless of angle.
        let total = (e.stepX * e.stepX + e.stepY * e.stepY).squareRoot()
        #expect(abs(total - Tuning.aimUnitSpeed) < 1e-9)
        // Player is below and to the right ⇒ move down + right.
        #expect(e.dirMask & MoveDir.down != 0)
        #expect(e.dirMask & MoveDir.right != 0)
        #expect(e.stepY > e.stepX)             // player is farther in Y than X ⇒ Y dominates
    }

    // ── cult (0x15): aims once, holds |vy|, drifts |vx| toward centre ───────────────────────
    @Test func cultAimsThenConverges() {
        let w = World()
        w.player.position = Vec2(128, 48)
        let e = Bestiary.cult()
        e.position = Vec2(210, 200)            // off to the right → initial |vx| > 0
        e.update(ctx(w))                       // frame 1: locks the aim
        let vy0 = e.stepY, vx0 = e.stepX
        #expect(e.dirMask & MoveDir.down != 0)
        #expect(vx0 > 0)                       // aimed toward centre → some horizontal speed
        // Over the next 16 frames |vx| must decay by one 0.125 step while |vy| is unchanged.
        let yStart = e.position.y
        for _ in 0..<16 { e.update(ctx(w)) }
        #expect(e.stepY == vy0)                // vertical speed locked
        #expect(e.stepX < vx0)                 // horizontal drifts toward centre
        #expect(e.position.y < yStart)         // still descending
    }

    // ── zanix (0x16): slow 0.5 px/f descent, pendulum X-sweep, long-lived ───────────────────
    @Test func zanixDescendsSlowlyAndSweeps() {
        let w = World()
        let e = Bestiary.zanix()
        e.position = Vec2(128, 200)
        e.update(ctx(w))
        #expect(abs(e.stepY - Tuning.zanixDescend) < 1e-9)   // 0.5 px/f
        var sawLeft = false, sawRight = false
        for _ in 0..<120 {
            e.update(ctx(w))
            if e.dirMask & MoveDir.left  != 0 { sawLeft = true }
            if e.dirMask & MoveDir.right != 0 { sawRight = true }
        }
        #expect(sawLeft && sawRight)           // the sweep flips horizontal direction
        #expect(!e.isDead)                     // 0.5 px/f ⇒ still on-field after ~120 frames
        // Descent rate ≈ 0.5 px/f (allowing for the one aim/​init frame).
        let screenY = LOGICAL_HEIGHT - e.position.y
        #expect(screenY > 50 && screenY < 75)
    }

    // ── sharlin (0x18): flight-script engine follows the ROM P0 step velocities ─────────────
    @Test func sharlinFollowsFlightScriptP0() {
        let w = World()
        let s = Bestiary.sharlin()             // flightPathIndex defaults to 0 ⇒ P0
        s.position = Vec2(128, 200)

        s.update(ctx(w))                       // step 0: velLUT[26], mask down+right (0x0A)
        #expect(s.dirMask == 0x0A)
        #expect(abs(s.stepX - FlightData.velLUT[26].dx) < 1e-9)
        #expect(abs(s.stepY - FlightData.velLUT[26].dy) < 1e-9)

        // Step 0 holds for 24 frames; the 25th update advances to step 1 (velLUT[25]).
        for _ in 0..<24 { s.update(ctx(w)) }
        #expect(abs(s.stepX - FlightData.velLUT[25].dx) < 1e-9)
        #expect(abs(s.stepY - FlightData.velLUT[25].dy) < 1e-9)

        // The down-right quarter-arc must eventually exit the RIGHT edge (X ≥ 248).
        let s2 = Bestiary.sharlin()            // fresh P0
        s2.position = Vec2(128, 200)
        var frames = 0
        while !s2.isDead && frames < 300 { s2.update(ctx(w)); frames += 1 }
        #expect(s2.isDead)
        #expect(s2.position.x >= Tuning.despawnXHigh)   // exited via the right edge, not the bottom
    }

    // ── sharlin flight-path index reads the per-enemy field (no construction-order global) ──
    @Test func sharlinFlightPathIsPerEnemy() {
        let w = World()
        let a = Bestiary.sharlin(); a.flightPathIndex = 1; a.position = Vec2(128, 200)
        let b = Bestiary.sharlin(); b.flightPathIndex = 6; b.position = Vec2(128, 200)
        a.update(ctx(w)); b.update(ctx(w))
        // P1 step0 = mask 0x06 (down+left) vel26; P6 step0 = mask 0x0A (down+right) vel26.
        #expect(a.dirMask == FlightData.scripts[1][0].mask)
        #expect(b.dirMask == FlightData.scripts[6][0].mask)
        #expect(a.dirMask != b.dirMask)        // the two members fly different scripts, deterministically
    }

    // ── velocity LUT integrity (ROM bank6 @0xA000) ──────────────────────────────────────────
    @Test func velLUTMatchesROM() {
        #expect(FlightData.velLUT.count == 42)
        #expect(abs(FlightData.velLUT[0].dx - 0.5) < 1e-9 && FlightData.velLUT[0].dy == 0)   // 0.5px @0°
        #expect(FlightData.velLUT[6].dx == 0 && abs(FlightData.velLUT[6].dy - 0.5) < 1e-9)   // 0.5px @90°
        #expect(FlightData.velLUT[41].dx == 0 && abs(FlightData.velLUT[41].dy - 4.0) < 1e-9) // 4px @90°
        // idx24 = 2.0px @45° ≈ (1.414, 1.414).
        #expect(abs(FlightData.velLUT[24].dx - FlightData.velLUT[24].dy) < 1e-9)
        #expect(abs(FlightData.velLUT[24].dx - 1.4141) < 0.001)
    }

    // ── Flight-path identity is STABLE per-wave, not construction-order-dependent ────────────
    // Regression for the old process-global counter in GalaxyStreamPaths (removed): building the
    // Galaxy level and, separately, constructing loose sharlins must NOT perturb the assignment.
    @Test func galaxyStreamPathsArePerWaveDeterministic() {
        // Pollute any hypothetical global by constructing sharlins first and out of order.
        for _ in 0..<5 { _ = Bestiary.sharlin() }
        // Every sharlin (flight-script) stream wave carries the ROM idx→path map on Wave.pathIndex,
        // in schedule order: idx5→P0, idx7→P1, 16→P6, 19→P3, 24→P7, 27→P2, 44→P4, 47→P2, 49→P3, 51→P3.
        let streamPaths = DefaultContent.galaxy().waves.compactMap { $0.wave.pathIndex }
        #expect(streamPaths == GalaxyStreamPaths.sequence)
        #expect(streamPaths == [0, 1, 6, 3, 7, 2, 4, 2, 3, 3])
    }

    // ── Stacked spawn + staggered movement release for a flight-script stream wave ───────────
    @Test func streamWaveSpawnsStackedWithStaggeredRelease() {
        let w = World()
        w.step(Intent(fire: true))             // title → playing so the spawner runs
        // A 6-member sharlin stream (P3), interval 8 — the ROM idx19 shape.
        let wave = Wave(make: Bestiary.sharlin, formation: .stream, count: 6,
                        interval: 8, baseX: 128, pathIndex: 3)
        w.spawn(wave)
        w.step(Intent())                       // spawner tick emits the members (all at once)
        let members = w.entities.compactMap { $0 as? Enemy }
        // All 6 exist AT ONCE (stacked), not staggered in emission.
        #expect(members.count == 6)
        // Each got the wave's path (P3), regardless of construction order.
        #expect(members.allSatisfy { $0.flightPathIndex == 3 })
        // Movement release is staggered by ROM +0x15 = ordinal×interval → 8,16,24,32,40,48.
        #expect(Set(members.map { $0.releaseDelay }) == Set([8, 16, 24, 32, 40, 48]))
    }
}
