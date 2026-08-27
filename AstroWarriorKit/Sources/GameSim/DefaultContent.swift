// A minimal runnable campaign so the sim boots. Real wave/scroll/boss data is
// [extract] (D5/D7) and lands in Wave 3 content agents (§14-M2/M3).
public enum DefaultContent {
    public static func campaign() -> Campaign {
        Campaign(levels: [galaxy(), asteroid(), nebula()])
    }

    static func galaxy() -> Level {
        // Galaxy stage — MEASURED from the ROM (ParityProbe) AND cross-checked against the ROM
        // wave-spawn table at 0x3FA3. The spawn schedule is scroll-SCRIPTED and DETERMINISTIC
        // (two different bots produced an identical schedule). Waves are gated by scroll-row
        // position (RAM 0xC211), NOT by the 0xC020 countdown — that counter inits to 1080 and is
        // the separate boss timer (fires the boss at 0). "907" was a boot-timing sampling artifact.
        // scrollLength 907 below is a stand-in that reproduces the observed stage length.
        //
        // The whole stage is just SIX waves + the fortress boss (Zanoni). Only two grunt species
        // (both confirmed by bank-4 sprite decode):
        //   • romType 21 = Cult  — ringed magenta/green disc; enters as a flat row of 4 (~32 px apart),
        //                          descends and converges toward centre. 1-HP, 100 pts. No fire.
        //   • romType 24 = chevron (Sharlin) — small yellow chevron; six enter stacked at centre-top
        //                          and release ~9 frames apart, each tracing a down-right curve.
        //                          1-HP, 100 pts. No fire. (Curos is a separate cross-shaped enemy.)
        // Counts, types, member X and stagger are ROM-EXACT — decoded from the wave-spawn table
        // at ROM 0x3FA3 (variant 0 = Galaxy), which matches the empirical run 1:1. atScroll = the
        // empirically-measured scroll position of each wave-index. baseX = centre of the ROM X row;
        // interval 8 = the ROM's `member×8` release stagger for the 0x18 stream.
        let waves: [WaveCue] = [
            // atScroll  species          formation  count  interval  baseX   ── ROM idx / X row ──
            cue(181,  Bestiary.sharlin, .stream, 6,  8, 128),  // idx5   0x18 ×6 centre column
            cue(352,  Bestiary.sharlin, .stream, 6,  8, 128),  // idx7   0x18 ×6 centre column
            cue(480,  Bestiary.cult,    .line,   4,  0,  64),  // idx8   0x15 ×4  x=16,48,80,112
            cue(608,  Bestiary.cult,    .line,   4,  0, 192),  // idx9   0x15 ×4  x=144,176,208,240
            cue(736,  Bestiary.cult,    .line,   4,  0, 128),  // idx10  0x15 ×4  x=80,112,144,176
            cue(864,  Bestiary.cult,    .line,   4,  0, 128),  // idx11  0x15 ×4  x=80,112,144,176
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
