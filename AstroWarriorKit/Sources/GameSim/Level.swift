// Content is data; World is the running state (§5.8).
public enum ZoneID: Sendable { case galaxy, asteroid, nebula }

public enum Formation: Sendable { case line, vee, arc, stream }

public struct Wave {
    public let make: () -> Enemy                    // a Bestiary entry
    public let formation: Formation
    public let count: Int
    /// For a `.stream` wave this is the ROM per-member MOVEMENT-release step (record +0x15 =
    /// ordinal×interval): every member SPAWNS at once (stacked), and member i's motion is held
    /// `(i+1)·interval` frames before release. For non-stream waves it is the legacy emission
    /// stagger (0 = all at once). See WaveSpawner + docs/parity-findings.md §4b/§4c.
    public let interval: Double
    /// Scripted horizontal anchor (screen-x) for the formation. The real ROM places each
    /// wave at a fixed x (MEASURED), not randomly; nil falls back to RNG for placeholder content.
    public let baseX: Double?
    /// Decoded per-wave flight-script index (record +0x13) for Galaxy `sharlin` (type 0x18)
    /// stream waves — a STABLE per-wave identity from the variant-0 wave table (idx5→P0, idx7→P1,
    /// …). The spawner stamps it onto every member's `flightPathIndex`, so path selection no longer
    /// depends on enemy construction order. nil for every non-flight-script wave.
    public let pathIndex: Int?
    /// Per-member ENTRY stagger (frames), ROM record +0x14/+0x13: for a line/arc wave the members all
    /// spawn at once (counted immediately) but member i holds its MOTION for `i·entryStagger` frames
    /// before it starts descending — the ROM's staggered entry, which sustains the on-field count. 0 =
    /// no stagger (Galaxy, and every flight-script stream, are unchanged). Wave-3b (Asteroid/Nebula).
    public let entryStagger: Double
    /// Explicit per-member entry X columns (ROM record +0x14 / decoded member-X), overriding the
    /// formation layout. The ROM places each member at a scripted X — critical for edge/scattered waves
    /// (e.g. tricker at X=16/240): a member out of the player's straight-up fire path survives, which the
    /// coarse centred `.line` layout gets wrong. nil = use the formation layout. Wave-3b (Asteroid/Nebula).
    public let memberX: [Double]?
    public init(make: @escaping () -> Enemy, formation: Formation, count: Int,
                interval: Double, baseX: Double? = nil, pathIndex: Int? = nil,
                entryStagger: Double = 0, memberX: [Double]? = nil) {
        self.make = make; self.formation = formation; self.count = count
        self.interval = interval; self.baseX = baseX; self.pathIndex = pathIndex
        self.entryStagger = entryStagger; self.memberX = memberX
    }
}

public struct WaveCue {
    public let atScroll: Double
    public let wave: Wave
    public init(atScroll: Double, wave: Wave) { self.atScroll = atScroll; self.wave = wave }

    /// Return a copy with `entryStagger` set on its Wave (Wave-3b Asteroid/Nebula line/arc staggered entry).
    public func withEntryStagger(_ s: Double) -> WaveCue {
        WaveCue(atScroll: atScroll,
                wave: Wave(make: wave.make, formation: wave.formation, count: wave.count,
                           interval: wave.interval, baseX: wave.baseX, pathIndex: wave.pathIndex,
                           entryStagger: s, memberX: wave.memberX))
    }
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
