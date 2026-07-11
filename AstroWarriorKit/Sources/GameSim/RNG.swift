// Seeded, deterministic RNG threaded through SimContext (§5.11).
// No Date(), no .random(). SplitMix64 — small, fast, good distribution.
public struct RNG: Sendable {
    private var state: UInt64
    public init(seed: UInt64) { self.state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform Double in [0, 1).
    public mutating func unit() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    /// Uniform Int in 0..<n.
    public mutating func int(_ n: Int) -> Int {
        precondition(n > 0)
        return Int(next() % UInt64(n))
    }
}
