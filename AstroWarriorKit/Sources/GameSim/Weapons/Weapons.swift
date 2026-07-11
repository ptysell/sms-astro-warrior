// Weapon strategy objects + the power-up ladder (§5.7). Numeric fields [extract].
public protocol Weapon {
    func fire(from origin: Vec2, _ ctx: SimContext)
}

public struct SingleShot: Weapon {
    public let speed: Double
    public init(speed: Double) { self.speed = speed }
    public func fire(from origin: Vec2, _ ctx: SimContext) {
        let b = Bullet(at: origin + Vec2(0, 6),
                       velocity: Vec2(0, speed),       // +Y = up the field
                       side: .player, damage: 1,
                       sprite: SpriteRef("bullet"))
        ctx.world.add(b)
    }
}

public struct TripleShot: Weapon {
    public let speed: Double
    public let spreadDeg: Double
    public init(speed: Double, spreadDeg: Double) { self.speed = speed; self.spreadDeg = spreadDeg }
    public func fire(from origin: Vec2, _ ctx: SimContext) {
        // TODO(S3): 3-way spread. [extract]
    }
}

public struct LaserBeam: Weapon {                 // piercing, persistent
    public init() {}
    public func fire(from origin: Vec2, _ ctx: SimContext) {
        // TODO(S3): persistent piercing beam. [extract]
    }
}

public enum PowerUpKind: Sendable { case speedUp, triple, laser }

// The cumulative-block ladder from §2 / Appendix A.
public enum PowerUpLadder {
    public static let thresholds = [12, 36, 60, 84, 108, 120]

    /// Apply the upgrade(s) earned at the player's current block count.
    /// Exact threshold → effect sequence is [extract] (D6).
    public static func apply(to player: Player, blocks: Int) {
        // TODO(S5): map thresholds → speedUp / form upgrade. [extract]
    }
}
