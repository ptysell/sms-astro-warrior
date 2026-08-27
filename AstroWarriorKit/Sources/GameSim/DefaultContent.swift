// A minimal runnable campaign so the sim boots. Real wave/scroll/boss data is
// [extract] (D5/D7) and lands in Wave 3 content agents (§14-M2/M3).
public enum DefaultContent {
    public static func campaign() -> Campaign {
        Campaign(levels: [galaxy(), asteroid(), nebula()])
    }

    static func galaxy() -> Level {
        // Galaxy stage — MEASURED from the ROM (ParityProbe, driven headlessly to countdown 0).
        // scrollLength = 907 ticks (0xC020:0xC021 starts at 907, −1/frame). The spawn schedule is
        // fully SCROLL-SCRIPTED and DETERMINISTIC: two different bots produced an identical schedule.
        // atScroll = 907 − (countdown at spawn). baseX = the scripted screen-x anchor (also MEASURED).
        //
        // The whole stage is just SIX waves + the fortress boss (Zanoni). Only two grunt species
        // (both confirmed by bank-4 sprite decode):
        //   • romType 21 = Cult  — ringed magenta/green disc; enters as a flat row of 4 (~32 px apart),
        //                          descends and converges toward centre. 1-HP, 100 pts. No fire.
        //   • romType 24 = chevron (Sharlin) — small yellow chevron; six enter stacked at centre-top
        //                          and release ~9 frames apart, each tracing a down-right curve.
        //                          1-HP, 100 pts. No fire. (Curos is a separate cross-shaped enemy.)
        let waves: [WaveCue] = [
            // atScroll  cd   species          formation  count  interval  baseX     ── MEASURED ──
            cue(181,  Bestiary.sharlin, .stream, 6,  9, 128),  // cd 726  type24 centre column
            cue(352,  Bestiary.sharlin, .stream, 6,  9, 128),  // cd 555  type24 centre column
            cue(480,  Bestiary.cult,    .line,   4,  0,  64),  // cd 427  type21 row, left  (x 16‥112)
            cue(608,  Bestiary.cult,    .line,   4,  0, 188),  // cd 299  type21 row, right (x 140‥236)
            cue(736,  Bestiary.cult,    .line,   4,  0, 126),  // cd 171  type21 row, centre
            cue(864,  Bestiary.cult,    .line,   4,  0, 126),  // cd  43  type21 row, centre
        ]
        // Boss: Zanoni is a large scrolling teal-tiled FORTRESS with green "X" turret-defenders
        // (romType 22) and a central core — not a single sprite. hp is [extract] (fortress model TBD).
        return Level(id: .galaxy, scrollSpeed: Tuning.scrollSpeed, scrollLength: 907,
                     waves: waves, boss: BossSpec(id: "zanoni", hp: 80),
                     background: BackgroundRef("galaxy"), music: "galaxy")
    }

    private static func cue(_ at: Double, _ make: @escaping () -> Enemy,
                            _ formation: Formation, _ count: Int, _ interval: Double,
                            _ baseX: Double? = nil) -> WaveCue {
        WaveCue(atScroll: at,
                wave: Wave(make: make, formation: formation, count: count,
                           interval: interval, baseX: baseX))
    }

    static func asteroid() -> Level {
        Level(id: .asteroid, scrollSpeed: Tuning.scrollSpeed, scrollLength: 2000,
              waves: [], boss: BossSpec(id: "nebiros", hp: 70),
              background: BackgroundRef("asteroid"), music: "asteroid")
    }

    static func nebula() -> Level {
        Level(id: .nebula, scrollSpeed: Tuning.scrollSpeed, scrollLength: 2000,
              waves: [], boss: BossSpec(id: "belzebul", hp: 80),
              background: BackgroundRef("nebula"), music: "nebula")
    }
}
