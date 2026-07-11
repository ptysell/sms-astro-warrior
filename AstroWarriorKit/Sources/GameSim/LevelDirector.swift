// Subsystem of World.step: scroll, spawn waves, trigger boss, transition (§5.8).
public final class LevelDirector {
    private var level: Level
    private var scroll = 0.0
    private var next = 0
    private enum Phase { case scrolling, boss, cleared }
    private var phase = Phase.scrolling

    public init(level: Level) { self.level = level }

    public var currentScroll: Double { scroll }

    public func update(_ world: World, _ ctx: SimContext) {
        switch phase {
        case .scrolling:
            scroll += level.scrollSpeed
            while next < level.waves.count, level.waves[next].atScroll <= scroll {
                world.spawn(level.waves[next].wave)
                next += 1
            }
            if scroll >= level.scrollLength {
                world.spawnBoss(level.boss)
                phase = .boss
            }
        case .boss:
            if world.bossDefeated { phase = .cleared }
        case .cleared:
            world.campaign.advance(self)            // next zone or loop + difficulty
        }
    }

    /// Re-arm the director for a new level (called by Campaign.advance).
    public func load(_ level: Level) {
        self.level = level; scroll = 0; next = 0; phase = .scrolling
    }
}
