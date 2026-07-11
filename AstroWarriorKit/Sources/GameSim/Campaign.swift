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
}
