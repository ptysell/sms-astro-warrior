// A minimal runnable campaign so the sim boots. Real wave/scroll/boss data is
// [extract] (D5/D7) and lands in Wave 3 content agents (§14-M2/M3).
public enum DefaultContent {
    public static func campaign() -> Campaign {
        Campaign(levels: [galaxy(), asteroid(), nebula()])
    }

    static func galaxy() -> Level {
        // Full Stage 1 — escalates through all six Galaxy types, then the Zanoni boss.
        // atScroll, maker, formation, count, interval(ticks between members; 0 = together)
        let waves: [WaveCue] = [
            // — Opening: easy weavers, learn the movement —
            cue(150,  Bestiary.cult,       .line,   4, 0),
            cue(320,  Bestiary.cult,       .arc,    6, 8),
            // — Introduce shooters —
            cue(520,  Bestiary.curos,      .stream, 4, 40),
            cue(700,  Bestiary.cult,       .line,   6, 0),
            // — Introduce divers —
            cue(880,  Bestiary.sharlin,    .vee,    5, 12),
            cue(1060, Bestiary.sacle,      .line,   4, 0),
            cue(1240, Bestiary.curos,      .stream, 5, 36),
            cue(1420, Bestiary.sharlin,    .vee,    6, 10),
            // — First heavy —
            cue(1600, Bestiary.motherBoon, .stream, 1, 0),
            cue(1660, Bestiary.cult,       .arc,    6, 8),
            // — Mid-stage mix, denser —
            cue(1900, Bestiary.sacle,      .arc,    6, 10),
            cue(2120, Bestiary.curos,      .stream, 6, 34),
            cue(2340, Bestiary.sharlin,    .vee,    6, 10),
            cue(2520, Bestiary.cult,       .line,   6, 0),
            // — Pre-boss gauntlet —
            cue(2720, Bestiary.sacle,      .line,   5, 0),
            cue(2900, Bestiary.curos,      .stream, 6, 30),
            cue(3100, Bestiary.sharlin,    .vee,    7, 9),
            cue(3300, Bestiary.motherBoon, .stream, 2, 60),
            cue(3360, Bestiary.cult,       .arc,    7, 8),
        ]
        return Level(id: .galaxy, scrollSpeed: Tuning.scrollSpeed, scrollLength: 3600,
                     waves: waves, boss: BossSpec(id: "zanoni", hp: 80),
                     background: BackgroundRef("galaxy"), music: "galaxy")
    }

    private static func cue(_ at: Double, _ make: @escaping () -> Enemy,
                            _ formation: Formation, _ count: Int, _ interval: Double) -> WaveCue {
        WaveCue(atScroll: at, wave: Wave(make: make, formation: formation, count: count, interval: interval))
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
