// Factory mapping each named enemy to a configured Enemy (§5.5).
// Values are [extract] — filled by the data river (D3). One method per roster entry (§2).
public enum Bestiary {
    // —— Galaxy Zone ——  (cult/curos = MEASURED from ROM; others [extract] D3)
    public static func cult() -> Enemy {           // romType 21 — ringed disc, 1-HP, no fire (MEASURED)
        // Enters as a flat row of 4 (~32 px apart) and descends ~1.5 px/f, converging toward centre.
        // Convergence during descent is a movement refinement TODO (no converge primitive yet).
        Enemy(at: .zero, sprite: SpriteRef("cult"), hitbox: .circle(r: 7),
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
    public static func sharlin() -> Enemy {        // romType 24 — chevron, 1-HP, no fire (MEASURED)
        // Galaxy chevron grunt (official name Sharlin likely; vs Sacle — Sacle is the shooter and
        // this one never fires). Six enter stacked at centre-top and release ~9 frames apart (.stream),
        // each curving down-right at ~1.7 px/f. The right-curve is a movement refinement TODO.
        Enemy(at: .zero, sprite: SpriteRef("sharlin"), hitbox: .circle(r: 7),
              hp: 1, points: 100,
              movement: Descend(speed: 1.7), attack: NoAttack())
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

    // —— Asteroid Zone ——
    public static func aster() -> Enemy { placeholder("aster") }
    public static func shamir() -> Enemy { placeholder("shamir") }
    public static func ufolick() -> Enemy { placeholder("ufolick") }
    public static func burdle() -> Enemy { placeholder("burdle") }
    public static func ashion() -> Enemy { placeholder("ashion") }
    public static func tinker() -> Enemy { placeholder("tinker") }

    // —— Nebula Zone ——
    public static func caborn() -> Enemy { placeholder("caborn") }
    public static func dilon() -> Enemy { placeholder("dilon") }
    public static func triat() -> Enemy { placeholder("triat") }
    public static func dririt() -> Enemy { placeholder("dririt") }
    public static func arbleby() -> Enemy { placeholder("arbleby") }
    public static func tricker() -> Enemy { placeholder("tricker") }

    // Stub used until D3 supplies real stats. [extract]
    private static func placeholder(_ id: String) -> Enemy {
        Enemy(at: .zero, sprite: SpriteRef(id), hitbox: .circle(r: 7),
              hp: 1, points: 100, movement: Descend(speed: 1.0), attack: NoAttack())
    }
}
