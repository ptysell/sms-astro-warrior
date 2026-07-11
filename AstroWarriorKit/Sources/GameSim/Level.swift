// Content is data; World is the running state (§5.8).
public enum ZoneID: Sendable { case galaxy, asteroid, nebula }

public enum Formation: Sendable { case line, vee, arc, stream }

public struct Wave {
    public let make: () -> Enemy                    // a Bestiary entry
    public let formation: Formation
    public let count: Int
    public let interval: Double                     // stagger between members (ticks)
    public init(make: @escaping () -> Enemy, formation: Formation, count: Int, interval: Double) {
        self.make = make; self.formation = formation; self.count = count; self.interval = interval
    }
}

public struct WaveCue {
    public let atScroll: Double
    public let wave: Wave
    public init(atScroll: Double, wave: Wave) { self.atScroll = atScroll; self.wave = wave }
}

public struct BossSpec {
    public let id: String
    public let hp: Int                              // [extract]
    public init(id: String, hp: Int) { self.id = id; self.hp = hp }
}

public struct Level {                              // a Zone — pure data
    public let id: ZoneID
    public let scrollSpeed: Double                  // [extract] logical units / tick
    public let scrollLength: Double                 // [extract] field length before boss
    public let waves: [WaveCue]                     // sorted by atScroll
    public let boss: BossSpec
    public let background: BackgroundRef            // cosmetic
    public let music: String
    public init(id: ZoneID, scrollSpeed: Double, scrollLength: Double,
                waves: [WaveCue], boss: BossSpec, background: BackgroundRef, music: String) {
        self.id = id; self.scrollSpeed = scrollSpeed; self.scrollLength = scrollLength
        self.waves = waves; self.boss = boss; self.background = background; self.music = music
    }
}
