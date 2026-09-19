// Ordered zones + infinite loop with difficulty scaling (§5.8).
public final class Campaign {
    public let levels: [Level]                      // [galaxy, asteroid, nebula]  [extract content]
    public private(set) var index = 0
    public private(set) var loop = 0

    public init(levels: [Level]) { self.levels = levels }

    public var current: Level { levels[index] }

    public func advance(_ director: LevelDirector) {
        index += 1
        if index >= levels.count {                  // wrap → next loop, harder
            index = 0
            loop += 1
        }
        director.load(levels[index])
        // TODO(S9): scale spawn rate / velocity by `loop`. [extract]
    }

    /// Return to the first zone / loop 0 for a fresh game (called by World.restart on game-over).
    public func reset(_ director: LevelDirector) {
        index = 0
        loop = 0
        director.load(levels[0])
    }

    /// ADDITIVE parity/test hook (Wave 3a stage-warp): jump straight to `zone` (loop 0) and re-arm
    /// the director there, so the sim can be measured in Asteroid/Nebula against the warped ROM.
    /// Purely additive — the default game path never calls this, so zone 0 (Galaxy) is unchanged.
    /// `zone` is clamped to the valid range; loop scaling is left at 0 (mirrors a fresh first-loop run).
    public func setZone(_ zone: Int, _ director: LevelDirector) {
        index = min(max(zone, 0), levels.count - 1)
        loop = 0
        director.load(levels[index])
    }
}
