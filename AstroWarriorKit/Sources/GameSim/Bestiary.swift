// Factory mapping each named enemy to a configured Enemy (§5.5).
// Values are [extract] — filled by the data river (D3). One method per roster entry (§2).
public enum Bestiary {
    // —— Galaxy Zone ——  romType→handler + HP/points/hitbox are ROM-EXACT (disassembly, 2026-08 pass);
    // movement/curves are best-fit. ALL Galaxy grunts are 1-HP, 100 pts, and their latent aimed fire is
    // LOOP-GATED behind 0xC240>=3 — SILENT on the first playthrough — so faithful stage-1 = NoAttack().
    public static func cult() -> Enemy {           // romType 0x15 (21) @0x4842 — ringed disc, 1-HP, 100pts (ROM-EXACT)
        // Wave-2a MOTION: AIMS at the player once (1.875 px/f split by angle, ROM 0x18fd) then holds
        // |vy| while |vx| drifts toward centre (−0.125 px/f per 16f, rebuild +0.03 px/f). AimConverge.
        // Single-hit death (0x5be3/0x5c1b); collision tbl @0x1C04 = 16×16 → r8.
        Enemy(at: .zero, sprite: SpriteRef("cult"), hitbox: .circle(r: 8),
              hp: 1, points: 100,
              movement: AimConverge(),
              attack: NoAttack())
    }
    public static func sharlin() -> Enemy {        // romType 0x18 (24) @0x4A5F — chevron stream grunt, 1-HP, 100pts (ROM-EXACT)
        // Wave-2a MOTION: real flight-script engine (bank6 scripts @0x4B6A → polar LUT @0xA000). Six
        // spawn STACKED at centre (X=128) and release ~interval frames apart (WaveSpawner), each
        // flying the wave's decoded path P0/P1/… — the path index (+0x13) is stamped per-wave onto
        // Enemy.flightPathIndex by the spawner (from Wave.pathIndex), so a bare sharlin defaults to
        // P0 with NO construction-order dependence. Quarter-arc / loop / serpentine curves at 2–3 px/f.
        // Single-hit death; collision tbl @0x1BA8 = 8×8 → r4 (refined from r7).
        Enemy(at: .zero, sprite: SpriteRef("sharlin"), hitbox: .circle(r: 4),
              hp: 1, points: 100,
              movement: FlightPathMove(),
              attack: NoAttack())
    }
    public static func zanix() -> Enemy {          // romType 0x16 (22) @0x48E4 — Zanoni "X" turret grunt, 1-HP, 100pts (ROM-EXACT)
        // Wave-2a MOTION: constant 0.5 px/f descent (down+right) with a horizontal sweep whose |vx|
        // oscillates 0..1.5 px/f at 0.25 px/f² (ZanixSweep) — a slow, long-lived drift.
        // Single-hit death; collision tbl @0x1C20 = 14×14 → r7.
        // Loop-gated aimed fire (≤2 bullets, 0xC240>=3) — silent on stage-1 loop, so NoAttack() here.
        Enemy(at: .zero, sprite: SpriteRef("zanix"), hitbox: .circle(r: 7),
              hp: 1, points: 100,
              movement: ZanixSweep(),
              attack: NoAttack())
    }
    public static func gyron() -> Enemy {          // romType 0x27 (39) @0x5577 — spiralling diver, 1-HP, 100pts (ROM-EXACT)
        // Wave-2a MOTION: enters at 2.0 px/f, walks an 8-direction CW rotation script (spiral), then
        // accelerates horizontally at 0.09375 px/f² (GyronSpiral). NOT the end-boss core (that 8-hit
        // counter is romType 0x28 @0x5624). Single-hit death; collision tbl @0x1CA0 = 12×12 → r6.
        // Loop-gated aimed shot (fires when player within 64px, 0xC240>=3) — silent on stage-1, NoAttack() here.
        Enemy(at: .zero, sprite: SpriteRef("gyron"), hitbox: .circle(r: 6),
              hp: 1, points: 100,
              movement: GyronSpiral(),
              attack: NoAttack())
    }
    public static func kyra() -> Enemy {           // romType 0x22 (34) @0x5150 — dives to the player's row then homes, 1-HP, 200pts (ROM-EXACT)
        // Wave-2a MOTION: dives 3.0 px/f; at the player's row turns up-and-toward the player column,
        // accelerates horizontally at 0.125 px/f² until aligned, then re-dives (KyraSwoop).
        // Single-hit death; hitbox tbl 0x1B1C+0x3E*4 = 16×16 → r8. Aimed shot is 0xC240-gated → NoAttack().
        Enemy(at: .zero, sprite: SpriteRef("kyra"), hitbox: .circle(r: 8),
              hp: 1, points: 200,
              movement: KyraSwoop(),
              attack: NoAttack())
    }
    public static func delta() -> Enemy {          // romType 0x19 (25) @0x4B7E — swoop-in / halt-and-fire grunt, 1-HP, 200pts (ROM-EXACT)
        // Wave-2a MOTION: 2.0 px/f descent with a triangular horizontal sweep at 0.125 px/f² (DeltaSweep).
        // Single-hit death; hitbox tbl 0x1B1C+0x37*4 = 20×20 → r10. UNLIKE the other Galaxy grunts its
        // aimed shot (type 0x14, ~1.9 px/f) is NOT loop-gated — it FIRES on loop 1 (kept below).
        Enemy(at: .zero, sprite: SpriteRef("delta"), hitbox: .circle(r: 10),
              hp: 1, points: 200,
              movement: DeltaSweep(),
              attack: AimedShot(interval: 40, bulletSpeed: 2))
    }
    // (Removed the pre-decode speculative Galaxy guesses curos/sacle/motherBoon/spindow — unreferenced
    //  and superseded by the ROM-decoded roster above. The real Galaxy roster is cult/zanix/sharlin/
    //  gyron/kyra/delta; see docs/parity-findings.md §4b. Curos = the "+/cross" sprite (bank-4 tile 40),
    //  not observed in Galaxy stage-1 — re-add from the decode if a later stage/loop needs it.)

    // —— Asteroid Zone ——  (romType handlers 0x17/0x1B/0x1D/0x1E/0x21/0x24, bank1; 2026-08 decode,
    // re-verified against the ROM tables. hp/points/hitbox/indestructible ROM-EXACT; movement/attack best-fit;
    // NAMES provisional — only tinker=0x21 & arbleby=0x1A anchored.)
    public static func aster() -> Enemy {          // romType 0x1B @0x4D66 — center sweeper, 1-HP, no fire
        Enemy(at: .zero, sprite: SpriteRef("aster"), hitbox: .circle(r: 8),
              hp: 1, points: 100,
              movement: Weave(speed: 1.4, amp: 40, freq: 0.05),
              attack: NoAttack())
    }
    public static func shamir() -> Enemy {         // romType 0x17 @0x49AC — aimed diver/rammer, 1-HP, no fire
        Enemy(at: .zero, sprite: SpriteRef("shamir"), hitbox: .circle(r: 8),
              hp: 1, points: 200,
              movement: Dive(speed: 2.0),
              attack: NoAttack())
    }
    public static func ufolick() -> Enemy {        // romType 0x24 @0x5302 — edge sweeper + 6-shot burst, 1-HP
        Enemy(at: .zero, sprite: SpriteRef("ufolick"), hitbox: .circle(r: 8),
              hp: 1, points: 200,
              movement: Weave(speed: 1.2, amp: 60, freq: 0.04),
              attack: RingFire(interval: 90, count: 6, bulletSpeed: 2.0))
    }
    public static func burdle() -> Enemy {         // romType 0x1E @0x4EA7 — descend, turn, aimed shot, 1-HP
        Enemy(at: .zero, sprite: SpriteRef("burdle"), hitbox: .circle(r: 7),
              hp: 1, points: 100,
              movement: Descend(speed: 1.3),
              attack: AimedShot(interval: 100, bulletSpeed: 2.2))
    }
    public static func ashion() -> Enemy {         // romType 0x1D @0x4DE5 — descend + shot, survives a hit (~2-HP)
        Enemy(at: .zero, sprite: SpriteRef("ashion"), hitbox: .circle(r: 7),
              hp: 2, points: 100,
              movement: Descend(speed: 1.2),
              attack: AimedShot(interval: 110, bulletSpeed: 2.2))
    }
    public static func tinker() -> Enemy {         // romType 0x21 @0x50C3 — smallest box, aimed random-accel diver, 1-HP
        Enemy(at: .zero, sprite: SpriteRef("tinker"), hitbox: .circle(r: 4),
              hp: 1, points: 100,
              movement: Dive(speed: 2.2),
              attack: NoAttack())
    }

    // —— Nebula Zone ——  (romType handlers 0x1A/0x1F/0x20/0x23/0x25/0x26, bank1)
    public static func caborn() -> Enemy {         // romType 0x1F @0x4F41 — INDESTRUCTIBLE drifting debris
        Enemy(at: .zero, sprite: SpriteRef("caborn"), hitbox: .circle(r: 2),
              hp: 1, points: 0,
              movement: Descend(speed: 1.0),
              attack: NoAttack(),
              indestructible: true)
    }
    public static func dilon() -> Enemy {          // romType 0x23 @0x51EB — carrier: hovers, launches type-0x18 divers
        // TODO: carrier-spawn (births type-0x18 divers) has no sim primitive yet — modeled inert.
        Enemy(at: .zero, sprite: SpriteRef("dilon"), hitbox: .circle(r: 6),
              hp: 1, points: 200,
              movement: FormationHold(speed: 0.6),
              attack: NoAttack())
    }
    public static func triat() -> Enemy {          // romType 0x25 @0x5428 — ARMORED 8-HP sweeper + 2-shot
        Enemy(at: .zero, sprite: SpriteRef("triat"), hitbox: .circle(r: 6),
              hp: 8, points: 200,
              movement: Weave(speed: 1.0, amp: 50, freq: 0.04),
              attack: AimedShot(interval: 120, bulletSpeed: 2.0))
    }
    public static func dririt() -> Enemy {         // romType 0x20 @0x4FB5 — self-splitter, 1-HP, no fire
        // TODO: on spawn it clones a mirrored sibling — no split primitive yet; modeled as plain descent.
        Enemy(at: .zero, sprite: SpriteRef("dririt"), hitbox: .circle(r: 8),
              hp: 1, points: 100,
              movement: Descend(speed: 1.4),
              attack: NoAttack())
    }
    public static func arbleby() -> Enemy {        // romType 0x1A @0x4C64 — largest box, swoop-to-player + fire, 1-HP
        Enemy(at: .zero, sprite: SpriteRef("arbleby"), hitbox: .circle(r: 10),
              hp: 1, points: 200,
              movement: Dive(speed: 1.8),
              attack: AimedShot(interval: 100, bulletSpeed: 2.2))
    }
    public static func tricker() -> Enemy {        // romType 0x26 @0x54B8 — edge ring-fire emplacement, 1-HP
        Enemy(at: .zero, sprite: SpriteRef("tricker"), hitbox: .circle(r: 8),
              hp: 1, points: 100,
              movement: Descend(speed: 0.8),
              attack: RingFire(interval: 80, count: 4, bulletSpeed: 1.8))
    }
}
