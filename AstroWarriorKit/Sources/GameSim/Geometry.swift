import simd

// Logical-unit 2D vector used throughout the sim (§5.1).
public typealias Vec2 = SIMD2<Double>

public extension Vec2 {
    static let zero = Vec2(0, 0)
    var length: Double { (x * x + y * y).squareRoot() }
}

// Which art to draw: a stable id + an animation frame index (§5.3).
public struct SpriteRef: Hashable, Sendable {
    public var id: String
    public var frame: Int
    public init(_ id: String, frame: Int = 0) { self.id = id; self.frame = frame }
}

// Collision shape in logical units (§5.3).
public struct Hitbox: Sendable {
    public enum Shape: Sendable {
        case circle(r: Double)
        case aabb(half: Vec2)
    }
    public var shape: Shape
    public var offset: Vec2
    public init(shape: Shape, offset: Vec2 = .zero) { self.shape = shape; self.offset = offset }

    public static func circle(r: Double) -> Hitbox { Hitbox(shape: .circle(r: r)) }
    public static func aabb(half: Vec2) -> Hitbox { Hitbox(shape: .aabb(half: half)) }

    /// Logical width×height of the collision shape — the renderer draws at exactly this
    /// so what you see is what collides.
    public var boundingSize: Vec2 {
        switch shape {
        case let .circle(r):    return Vec2(2 * r, 2 * r)
        case let .aabb(half):   return Vec2(2 * half.x, 2 * half.y)
        }
    }
}
