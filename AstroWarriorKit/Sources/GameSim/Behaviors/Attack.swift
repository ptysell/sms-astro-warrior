import Foundation

// Attack strategy objects (§5.4). Numeric fields are [extract] — §16.
public protocol AttackBehavior {
    func step(_ e: Enemy, _ ctx: SimContext)
}

public struct NoAttack: AttackBehavior {
    public init() {}
    public func step(_ e: Enemy, _ ctx: SimContext) {}
}

// Fires a single bullet aimed at the player on a fixed cadence.
public struct AimedShot: AttackBehavior {
    public let interval: Double        // ticks between shots
    public let bulletSpeed: Double
    public init(interval: Double, bulletSpeed: Double) {
        self.interval = interval; self.bulletSpeed = bulletSpeed
    }
    public func step(_ e: Enemy, _ ctx: SimContext) {
        guard e.position.y < LOGICAL_HEIGHT else { return }   // only once on-screen
        if e.attackCooldown > 0 { e.attackCooldown -= 1; return }
        e.attackCooldown = interval
        let d = ctx.world.player.position - e.position
        let len = d.length
        guard len > 0.0001 else { return }
        ctx.world.add(Bullet(at: e.position, velocity: (d / len) * bulletSpeed,
                             side: .enemy, damage: 1, sprite: SpriteRef("ebullet")))
    }
}

// Fires `count` bullets in an evenly-spaced ring on a fixed cadence.
public struct RingFire: AttackBehavior {
    public let interval: Double
    public let count: Int
    public let bulletSpeed: Double
    public init(interval: Double, count: Int, bulletSpeed: Double) {
        self.interval = interval; self.count = count; self.bulletSpeed = bulletSpeed
    }
    public func step(_ e: Enemy, _ ctx: SimContext) {
        guard e.position.y < LOGICAL_HEIGHT else { return }
        if e.attackCooldown > 0 { e.attackCooldown -= 1; return }
        e.attackCooldown = interval
        for k in 0..<max(1, count) {
            let a = (Double(k) / Double(count)) * 2 * .pi
            let v = Vec2(cos(a), sin(a)) * bulletSpeed
            ctx.world.add(Bullet(at: e.position, velocity: v,
                                 side: .enemy, damage: 1, sprite: SpriteRef("ebullet")))
        }
    }
}
