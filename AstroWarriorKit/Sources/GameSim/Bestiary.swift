// Factory mapping each named enemy to a configured Enemy (§5.5).
// Values are [extract] — filled by the data river (D3). One method per roster entry (§2).
public enum Bestiary {
    // —— Galaxy Zone ——  romType→handler + HP/points/hitbox are ROM-EXACT (disassembly, 2026-08 pass);
    // movement/curves are best-fit. ALL Galaxy grunts are 1-HP, 100 pts, and their latent aimed fire is
    // LOOP-GATED behind 0xC240>=3 — SILENT on the first playthrough — so faithful stage-1 = NoAttack().
    public static func cult() -> Enemy {           // romType 0x15 (21) @0x4842 — ringed disc, 1-HP, 100pts (ROM-EXACT)
        // Flat row of 4 (~32 px apart), descends ~1.5 px/f converging toward centre (converge = TODO).
        // Single-hit death (0x5be3/0x5c1b); collision tbl @0x1C04 = 16×16 → r8.
        Enemy(at: .zero, sprite: SpriteRef("cult"), hitbox: .circle(r: 8),
              hp: 1, points: 100,
              movement: Descend(speed: 1.5),
              attack: NoAttack())
    }
    public static func curos() -> Enemy {          // "+/cross" sprite (bank-4 tile 40); [extract] D3
        // NOTE: Curos is the cross-shaped enemy — NOT the Galaxy chevron. It was not observed in
        // Galaxy stage 1; stats below remain placeholder until it is measured in a later wave/zone.
        Enemy(at: .zero, sprite: SpriteRef("curos"), hitbox: .circle(r: 7),
              hp: 1, points: 150,
              movement: Descend(speed: 0.9),
              attack: AimedShot(interval: 90, bulletSpeed: 2.4))
    }
    public static func sharlin() -> Enemy {        // romType 0x18 (24) @0x4A5F — chevron stream grunt, 1-HP, 100pts (ROM-EXACT)
        // Six spawn stacked at centre (X=128) and release per +0x15 stagger, each on a scripted flight
        // path (ptrs @0x4B6A → slot2 vel tbl @0xA000) curving down-right ~1.7 px/f (curve = TODO).
        // Leader-chain bonus (hit +0x14==1 of an intact 6-set → chain-kill, 1000 pts) not yet modelled.
        // Single-hit death; collision tbl @0x1BA8 = 8×8 → r4 (refined from r7).
        Enemy(at: .zero, sprite: SpriteRef("sharlin"), hitbox: .circle(r: 4),
              hp: 1, points: 100,
              movement: Descend(speed: 1.7), attack: NoAttack())
    }
    public static func zanix() -> Enemy {          // romType 0x16 (22) @0x48E4 — Zanoni "X" turret grunt, 1-HP, 100pts (ROM-EXACT)
        // Green-X defender; appears as waves of 4 (idx12-14) and on the fortress boss. Bobs vertically
        // while drifting slowly in X. Single-hit death; collision tbl @0x1C20 = 14×14 → r7.
        // Loop-gated aimed fire (≤2 bullets, 0xC240>=3) — silent on stage-1 loop, so NoAttack() here.
        Enemy(at: .zero, sprite: SpriteRef("zanix"), hitbox: .circle(r: 7),
              hp: 1, points: 100,
              movement: Weave(speed: 0.8, amp: 40, freq: 0.03),
              attack: NoAttack())
    }
    public static func gyron() -> Enemy {          // romType 0x27 (39) @0x5577 — accelerating aimed diver, 1-HP, 100pts (ROM-EXACT)
        // Galaxy waves idx20-23/40-43 (line of 4, X=80,112,144,176). Inits ±2 px/f both axes then state-2
        // accelerates Y — an accelerating dive. NOT the end-boss core (that 8-hit counter is romType 0x28
        // @0x5624). Single-hit death (0x5be3/0x5c1b); collision tbl @0x1CA0 = 12×12 → r6.
        // Loop-gated aimed shot (fires when player within 64px, 0xC240>=3) — silent on stage-1, NoAttack() here.
        Enemy(at: .zero, sprite: SpriteRef("gyron"), hitbox: .circle(r: 6),
              hp: 1, points: 100,
              movement: Dive(speed: 2.0),
              attack: NoAttack())
    }
    public static func kyra() -> Enemy {           // romType 0x22 (34) @0x5150 — dives to the player's row then homes, 1-HP, 200pts (ROM-EXACT)
        // Late-Galaxy grunt (idx28-31 columns, idx52-55 diagonals). state0 Y-speed 3 + down; descends until
        // past the player row (0xC609) then homes toward player X (0xC60B). Single-hit death; hitbox
        // tbl 0x1B1C+0x3E*4 = 16×16 → r8. Aimed shot is 0xC240-gated (silent on stage-1 loop) → NoAttack().
        Enemy(at: .zero, sprite: SpriteRef("kyra"), hitbox: .circle(r: 8),
              hp: 1, points: 200,
              movement: Dive(speed: 3, lockAt: LOGICAL_HEIGHT * 0.25),
              attack: NoAttack())
    }
    public static func delta() -> Enemy {          // romType 0x19 (25) @0x4B7E — swoop-in / halt-and-fire grunt, 1-HP, 200pts (ROM-EXACT)
        // Late-Galaxy grunt (idx56-60). Swoops in ~2 px/f with an accelerating horizontal sweep, halts to
        // fire, then retreats up. Single-hit death; hitbox tbl 0x1B1C+0x37*4 = 20×20 → r10. UNLIKE the other
        // Galaxy grunts its aimed shot (type 0x14, ~1.9 px/f) is NOT loop-gated — it FIRES on loop 1.
        Enemy(at: .zero, sprite: SpriteRef("delta"), hitbox: .circle(r: 10),
              hp: 1, points: 200,
              movement: Weave(speed: 2, amp: 32, freq: 0.05),
              attack: AimedShot(interval: 40, bulletSpeed: 2))
    }
    public static func sacle() -> Enemy {          // wide weaver that also shoots
        Enemy(at: .zero, sprite: SpriteRef("sacle"), hitbox: .circle(r: 7),
              hp: 2, points: 200,
              movement: Weave(speed: 0.8, amp: 34, freq: 0.05),
              attack: AimedShot(interval: 110, bulletSpeed: 2.2))
    }
    public static func motherBoon() -> Enemy {     // heavy, ring-fires
        Enemy(at: .zero, sprite: SpriteRef("mother_boon"), hitbox: .circle(r: 10),
              hp: 6, points: 500,
              movement: Descend(speed: 0.5),
              attack: RingFire(interval: 130, count: 8, bulletSpeed: 2.0))
    }
    public static func spindow() -> Enemy {        // 24×24, boss-class ring-firer
        Enemy(at: .zero, sprite: SpriteRef("spindow"), hitbox: .aabb(half: Vec2(12, 12)),
              hp: 8, points: 1000,
              movement: Descend(speed: 0.5),
              attack: RingFire(interval: 100, count: 10, bulletSpeed: 1.8))
    }

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
