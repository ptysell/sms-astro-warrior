// A minimal runnable campaign so the sim boots. Real wave/scroll/boss data is
// [extract] (D5/D7) and lands in Wave 3 content agents (§14-M2/M3).
public enum DefaultContent {
    public static func campaign() -> Campaign {
        Campaign(levels: [galaxy(), asteroid(), nebula()])
    }

    static func galaxy() -> Level {
        // Stage 1 — scrollLength MEASURED (907 ticks = ~15s). Wave cue positions are
        // placeholders scaled to fit; real atScroll values [extract] from ROM.
        let waves: [WaveCue] = [
            // — Opening: easy weavers —
            cue(38,   Bestiary.cult,       .line,   4, 0),
            cue(81,   Bestiary.cult,       .arc,    6, 8),
            // — Introduce shooters —
            cue(131,  Bestiary.curos,      .stream, 4, 40),
            cue(176,  Bestiary.cult,       .line,   6, 0),
            // — Introduce divers —
            cue(222,  Bestiary.sharlin,    .vee,    5, 12),
            cue(267,  Bestiary.sacle,      .line,   4, 0),
            cue(313,  Bestiary.curos,      .stream, 5, 36),
            cue(358,  Bestiary.sharlin,    .vee,    6, 10),
            // — First heavy —
            cue(403,  Bestiary.motherBoon, .stream, 1, 0),
            cue(418,  Bestiary.cult,       .arc,    6, 8),
            // — Mid-stage mix, denser —
            cue(479,  Bestiary.sacle,      .arc,    6, 10),
            cue(534,  Bestiary.curos,      .stream, 6, 34),
            cue(590,  Bestiary.sharlin,    .vee,    6, 10),
            cue(635,  Bestiary.cult,       .line,   6, 0),
            // — Pre-boss gauntlet —
            cue(686,  Bestiary.sacle,      .line,   5, 0),
            cue(731,  Bestiary.curos,      .stream, 6, 30),
            cue(781,  Bestiary.sharlin,    .vee,    7, 9),
            cue(832,  Bestiary.motherBoon, .stream, 2, 60),
            cue(847,  Bestiary.cult,       .arc,    7, 8),
        ]
        return Level(id: .galaxy, scrollSpeed: Tuning.scrollSpeed, scrollLength: 907,
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
