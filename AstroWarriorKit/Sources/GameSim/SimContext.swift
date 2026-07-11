// Per-tick context handed to every update(). Carries the world, the frame's intent,
// the fixed dt, and the deterministic RNG (§5.10, §5.11).
public struct SimContext {
    public unowned let world: World
    public let intent: Intent
    public let dt: Double
    public init(world: World, intent: Intent, dt: Double = SIM_DT) {
        self.world = world; self.intent = intent; self.dt = dt
    }
}
