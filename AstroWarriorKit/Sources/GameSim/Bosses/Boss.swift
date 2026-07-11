import Foundation

// Each boss: its own object with a phase state machine (§5.9). HP + scripts [extract].
public protocol BossPhase {
    func step(_ b: Boss, _ ctx: SimContext)
}

public final class Boss: Entity, Damageable {
    public var hp: Int                              // [extract]
    public let id: String
    public var age = 0
    public var anchorX: Double = 0
    private var phase: BossPhase

    public init(spec: BossSpec, at p: Vec2, phase: BossPhase) {
        self.hp = spec.hp; self.id = spec.id; self.phase = phase
        super.init(at: p, sprite: SpriteRef(spec.id), hitbox: .aabb(half: Vec2(16, 16)))
        self.anchorX = p.x
    }

    public func setPhase(_ p: BossPhase) { phase = p }

    public override func update(_ ctx: SimContext) { age += 1; phase.step(self, ctx) }

    public func takeDamage(_ amount: Int, _ ctx: SimContext) {
        hp -= amount
        if hp <= 0 { isDead = true; ctx.world.onBossDefeated() }
    }
}

// Placeholder intro phase so the type graph compiles (§14-M3 fills the real scripts).
public struct BossIntro: BossPhase {
    public init() {}
    public func step(_ b: Boss, _ ctx: SimContext) {}
}

// M-level stage-1 boss: hovers side to side and periodically ring-fires.
// TODO(C6): real Zanoni multi-phase script (§5.9). Values [extract] D7.
public struct BossHover: BossPhase {
    public init() {}
    public func step(_ b: Boss, _ ctx: SimContext) {
        b.position.x = b.anchorX + 46 * _bsin(Double(b.age) * 0.028)
        if b.age % 80 == 0 {
            let count = 12
            for k in 0..<count {
                let a = (Double(k) / Double(count)) * 2 * .pi
                ctx.world.add(Bullet(at: b.position,
                                     velocity: Vec2(_bcos(a), _bsin(a)) * 1.9,
                                     side: .enemy, damage: 1, sprite: SpriteRef("ebullet")))
            }
        }
    }
}

@inline(__always) private func _bsin(_ x: Double) -> Double { Foundation.sin(x) }
@inline(__always) private func _bcos(_ x: Double) -> Double { Foundation.cos(x) }
