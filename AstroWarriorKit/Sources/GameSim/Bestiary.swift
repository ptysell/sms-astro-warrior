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
    public static func aster() -> Enemy {          // romType 0x1B @0x4D66 — centre-launch decelerating fan, 1-HP, no fire
        // Wave-3b MOTION: 6 members burst from screen-centre (X=128) diagonally (vx=4.0,vy=2.0), each
        // decelerating |vx| per-member (dir/decel from the ROM record via memberIndex) to a straight fall.
        Enemy(at: .zero, sprite: SpriteRef("aster"), hitbox: .circle(r: 8),
              hp: 1, points: 100,
              movement: AsterFan(),
              attack: NoAttack())
    }
    public static func shamir() -> Enemy {         // romType 0x17 @0x49AC — descend then homing ram, 1-HP, no fire
        // Wave-3b MOTION: descend 1.0 until below the player, then homing ram at 0.9375 (aim/2), re-aimed
        // every 8f. Never fires (no 0x18a6 in handler).
        Enemy(at: .zero, sprite: SpriteRef("shamir"), hitbox: .circle(r: 8),
              hp: 1, points: 200,
              movement: ShamirRam(),
              attack: NoAttack())
    }
    public static func ufolick() -> Enemy {        // romType 0x24 @0x5302 — edge-entry dive/reverse + 6-shot burst, 1-HP
        // Wave-3b MOTION: enter the edge OPPOSITE the player, descend 2.0, reverse to UP 4.0 at the player
        // row and fire a one-shot 6-shot fan (UfolickBurst). Not loop-gated (fires on loop 0).
        Enemy(at: .zero, sprite: SpriteRef("ufolick"), hitbox: .circle(r: 8),
              hp: 1, points: 200,
              movement: EdgeEntryReverse(),
              attack: UfolickBurst())
    }
    public static func burdle() -> Enemy {         // romType 0x1E @0x4EA7 — descend then 16f diagonal veer, 1-HP
        // Wave-3b MOTION: descend 2.0; at 32px above the player, a 16-frame veer (2.0,2.0) toward the
        // player's side, then straight down. Fire is LOOP-GATED (0xC240>=3) → SILENT on loop 0 → NoAttack.
        Enemy(at: .zero, sprite: SpriteRef("burdle"), hitbox: .circle(r: 7),
              hp: 1, points: 100,
              movement: BurdleVeer(),
              attack: NoAttack())
    }
    public static func ashion() -> Enemy {         // romType 0x1D @0x4DE5 — straight descender, survives a glancing hit (~2-HP)
        // Wave-3b MOTION: straight down 2.0 (ROM speeds up to 4.0 after a glancing hit — a collision
        // response the sim can't express per-hit yet; modeled as hp:2). Fire LOOP-GATED → NoAttack loop 0.
        Enemy(at: .zero, sprite: SpriteRef("ashion"), hitbox: .circle(r: 7),
              hp: 2, points: 100,
              movement: AshionDrop(),
              attack: NoAttack())
    }
    public static func tinker() -> Enemy {         // romType 0x21 @0x50C3 — delayed aim × random-scale dive, 1-HP
        // Wave-3b MOTION: after a spawn delay, aim (1.875) × random scale {3.0,1.5,2.0,2.5} then coast.
        // RNG scale is hardware-random in the ROM → sim draws from the seeded RNG (distribution parity).
        Enemy(at: .zero, sprite: SpriteRef("tinker"), hitbox: .circle(r: 4),
              hp: 1, points: 100,
              movement: AimScaleDive(),
              attack: NoAttack())
    }

    // —— Nebula Zone ——  (romType handlers 0x1A/0x1F/0x20/0x23/0x25/0x26, bank1)
    public static func caborn() -> Enemy {         // romType 0x1F @0x4F41 — INDESTRUCTIBLE drifting debris, 0 pts
        // Wave-3b MOTION: pure straight-down integrator drift 1.0 px/f (1.5 on loop>=3). No fire.
        Enemy(at: .zero, sprite: SpriteRef("caborn"), hitbox: .circle(r: 2),
              hp: 1, points: 0,
              movement: StraightDescend(lo: Tuning.cabornDescend, hi: Tuning.cabornDescendHi),
              attack: NoAttack(),
              indestructible: true)
    }
    public static func dilon() -> Enemy {          // romType 0x23 @0x51EB — carrier: descends, orbits, launches type-0x18 divers
        // Wave-3b MOTION: descend 2.0, then 8-dir orbit (reuse gyron's rotation LUT), launching a
        // type-0x18 sharlin diver (flight-path P8/P9) every ~32f via World.spawnPoolEnemy.
        Enemy(at: .zero, sprite: SpriteRef("dilon"), hitbox: .circle(r: 6),
              hp: 1, points: 200,
              movement: DilonCarrier(),
              attack: NoAttack())
    }
    public static func triat() -> Enemy {          // romType 0x25 @0x5428 — ARMORED 8-HP straight descender + 2-shot spread
        // Wave-3b MOTION: pure straight-down 1.0 (1.5 loop>=3), armored 8-HP; every 64f a fixed 2-shot
        // down-V spread (SpreadFire, NOT aimed). Laser one-shot (0xC610) deferred (needs a weapon flag).
        Enemy(at: .zero, sprite: SpriteRef("triat"), hitbox: .circle(r: 6),
              hp: 8, points: 200,
              movement: StraightDescend(lo: Tuning.triatDescend, hi: Tuning.triatDescendHi),
              attack: SpreadFire(interval: Tuning.triatSpreadInterval))
    }
    public static func dririt() -> Enemy {         // romType 0x20 @0x4FB5 — self-splitter, 1-HP, no fire
        // Wave-3b MOTION: random speed S on both axes; descend 16f then split into a mirrored diagonal
        // pair (child dir = parent XOR left/right) repeatedly until past screenY 128. Cascade pool-capped.
        Enemy(at: .zero, sprite: SpriteRef("dririt"), hitbox: .circle(r: 8),
              hp: 1, points: 100,
              movement: DriritSplit(),
              attack: NoAttack())
    }
    public static func arbleby() -> Enemy {        // romType 0x1A @0x4C64 — multi-pass swoop-to-player + aimed fire, 1-HP
        // Wave-3b MOTION: diagonal swoop onto the player column, overshoot, hover, mirror-sweep (multi-pass).
        // Aimed fire is UNGATED (fires on loop 0) — via AimedShot at the shared 1.875 px/f.
        Enemy(at: .zero, sprite: SpriteRef("arbleby"), hitbox: .circle(r: 10),
              hp: 1, points: 200,
              movement: ArblebySwoop(),
              attack: AimedShot(interval: 60, bulletSpeed: Tuning.aimUnitSpeed))
    }
    public static func tricker() -> Enemy {        // romType 0x26 @0x54B8 — edge-column dropper, aimed + jitter, 1-HP
        // Wave-3b MOTION: edge column, descend 2.0, then a random vertical jitter at the player's row.
        // Aimed single shot (1.875 px/f) — NOT a ring (corrects the old RingFire).
        Enemy(at: .zero, sprite: SpriteRef("tricker"), hitbox: .circle(r: 8),
              hp: 1, points: 100,
              movement: TrickerDrop(),
              attack: AimedShot(interval: 48, bulletSpeed: Tuning.aimUnitSpeed))
    }
}
