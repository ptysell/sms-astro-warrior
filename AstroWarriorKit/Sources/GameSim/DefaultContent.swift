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
        // FULL idx5..60 schedule — decoded from the variant0 wave table (root 0x3FA9, records @0x4129)
        // and cross-checked against a live-emulator census (2026-08 pass, crosscheck PASSED). romType,
        // count, and member X are ROM-EXACT; formation/baseX are best-fit onto the sim's coarse model.
        //   atScroll = 128*idx − 546 (idx≥7; slope ROM-EXACT via scroll routine 0x0D44), idx5 = 179 warm-up.
        //   Species: 0x15 cult, 0x16 zanix, 0x18 sharlin (streams, centre X=128), 0x19 delta, 0x22 kyra,
        //   0x27 gyron. ALL 1-HP/100pts; latent fire is loop-gated (0xC240≥3) → silent on stage-1.
        //   Empty rests (idx6,15,33,35,61) omitted. .stream = staggered column; .line ≈ 32px row on baseX.
        let waves: [WaveCue] = [
            // atScroll  species        formation  count  interval  baseX   ── ROM idx / type ──
            cue( 179, Bestiary.sharlin,  .stream, 6, 8, 128),  // idx5 0x18 x6
            cue( 350, Bestiary.sharlin,  .stream, 6, 8, 128),  // idx7 0x18 x6
            cue( 478, Bestiary.cult,     .line,   4, 0,  64),  // idx8 0x15 x4
            cue( 606, Bestiary.cult,     .line,   4, 0, 192),  // idx9 0x15 x4
            cue( 734, Bestiary.cult,     .line,   4, 0, 128),  // idx10 0x15 x4
            cue( 862, Bestiary.cult,     .line,   4, 0, 128),  // idx11 0x15 x4
            cue( 990, Bestiary.zanix,    .line,   4, 0, 128),  // idx12 0x16 x4
            cue(1118, Bestiary.zanix,    .stream, 4, 8, 208),  // idx13 0x16 x4
            cue(1246, Bestiary.zanix,    .stream, 4, 8,  48),  // idx14 0x16 x4
            cue(1502, Bestiary.sharlin,  .stream, 6, 8, 128),  // idx16 0x18 x6
            cue(1630, Bestiary.cult,     .line,   4, 0, 128),  // idx17 0x15 x4
            cue(1758, Bestiary.cult,     .line,   4, 0, 128),  // idx18 0x15 x4
            cue(1886, Bestiary.sharlin,  .stream, 6, 8, 128),  // idx19 0x18 x6
            cue(2014, Bestiary.gyron,    .line,   4, 0, 128),  // idx20 0x27 x4
            cue(2142, Bestiary.gyron,    .line,   4, 0, 128),  // idx21 0x27 x4
            cue(2270, Bestiary.gyron,    .line,   4, 0, 128),  // idx22 0x27 x4
            cue(2398, Bestiary.gyron,    .line,   4, 0, 128),  // idx23 0x27 x4
            cue(2526, Bestiary.sharlin,  .stream, 6, 8, 128),  // idx24 0x18 x6
            cue(2654, Bestiary.cult,     .line,   4, 0, 128),  // idx25 0x15 x4
            cue(2782, Bestiary.cult,     .line,   4, 0, 128),  // idx26 0x15 x4
            cue(2910, Bestiary.sharlin,  .stream, 6, 8, 128),  // idx27 0x18 x6
            cue(3038, Bestiary.kyra,     .stream, 4, 8,  48),  // idx28 0x22 x4
            cue(3166, Bestiary.kyra,     .stream, 4, 8, 208),  // idx29 0x22 x4
            cue(3294, Bestiary.kyra,     .stream, 4, 8,  64),  // idx30 0x22 x4
            cue(3422, Bestiary.kyra,     .stream, 4, 8, 192),  // idx31 0x22 x4
            cue(3550, Bestiary.zanix,    .line,   8, 0,  80),  // idx32 0x16 x8
            cue(3806, Bestiary.zanix,    .line,   8, 0, 176),  // idx34 0x16 x8
            cue(4062, Bestiary.cult,     .arc,    7, 0, 128),  // idx36 0x15 x7
            cue(4190, Bestiary.cult,     .arc,    7, 0, 128),  // idx37 0x15 x7
            cue(4318, Bestiary.cult,     .line,   6, 0, 128),  // idx38 0x15 x6
            cue(4446, Bestiary.cult,     .line,   6, 0, 128),  // idx39 0x15 x6
            cue(4574, Bestiary.gyron,    .line,   4, 0, 128),  // idx40 0x27 x4
            cue(4702, Bestiary.gyron,    .line,   4, 0, 128),  // idx41 0x27 x4
            cue(4830, Bestiary.gyron,    .line,   4, 0, 128),  // idx42 0x27 x4
            cue(4958, Bestiary.gyron,    .line,   4, 0, 128),  // idx43 0x27 x4
            cue(5086, Bestiary.sharlin,  .stream, 6, 8, 128),  // idx44 0x18 x6
            cue(5214, Bestiary.cult,     .line,   8, 0, 128),  // idx45 0x15 x8
            cue(5342, Bestiary.cult,     .line,   8, 0, 128),  // idx46 0x15 x8
            cue(5470, Bestiary.sharlin,  .stream, 6, 8, 128),  // idx47 0x18 x6
            cue(5598, Bestiary.cult,     .line,   8, 0, 128),  // idx48 0x15 x8
            cue(5726, Bestiary.sharlin,  .stream, 6, 8, 128),  // idx49 0x18 x6
            cue(5854, Bestiary.cult,     .line,   8, 0, 128),  // idx50 0x15 x8
            cue(5982, Bestiary.sharlin,  .stream, 6, 8, 128),  // idx51 0x18 x6
            cue(6110, Bestiary.kyra,     .line,   4, 0,  80),  // idx52 0x22 x4
            cue(6238, Bestiary.kyra,     .line,   4, 0, 176),  // idx53 0x22 x4
            cue(6366, Bestiary.kyra,     .stream, 4, 8, 160),  // idx54 0x22 x4
            cue(6494, Bestiary.kyra,     .stream, 4, 8,  96),  // idx55 0x22 x4
            cue(6622, Bestiary.delta,    .line,   2, 0, 128),  // idx56 0x19 x2
            cue(6750, Bestiary.delta,    .line,   4, 0, 128),  // idx57 0x19 x4
            cue(6878, Bestiary.delta,    .line,   4, 0, 128),  // idx58 0x19 x4
            cue(7006, Bestiary.delta,    .line,   4, 0, 128),  // idx59 0x19 x4
            cue(7134, Bestiary.delta,    .line,   4, 0, 128),  // idx60 0x19 x4
        ]
        // Boss: Zanoni is a large scrolling teal-tiled FORTRESS with green "X" turret-defenders
        // (romType 0x16 zanix) and a central core (romType 0x28) — a multi-part entity wave, not one
        // sprite. Modelled as a single BossSpec for now (multi-part boss model TBD). Fires at idx62.
        return Level(id: .galaxy, scrollSpeed: Tuning.scrollSpeed, scrollLength: 7390,
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
        // Asteroid — variant1 wave table (root 0x4029), decoded 2026-08 and re-verified against the ROM
        // (zero discrepancies). romType/count/member-X ROM-EXACT; formation/baseX best-fit; names provisional.
        // atScroll = 128*idx − 544. Boss Nebiros (0x29 ×5) fires at scrollLength (idx62). NOT yet
        // parity-measured — reaching this stage in lockstep needs a warp harness (a follow-up).
        let waves: [WaveCue] = [
            cue(96,   Bestiary.tinker,  .line,   8, 0, 120),  // idx5  0x21 dive  X=48,64,80,96,128,144,192,208
            cue(224,  Bestiary.tinker,  .line,   8, 0, 120),  // idx6  0x21 dive  X=48..208
            cue(352,  Bestiary.tinker,  .line,   8, 0, 120),  // idx7  0x21 dive  X=48..208
            cue(480,  Bestiary.ashion,  .line,   7, 0, 128),  // idx8  0x1D line  X=32,64,96,128,160,192,224 (exact)
            cue(608,  Bestiary.ashion,  .line,   6, 0, 128),  // idx9  0x1D line  X=48,80,112,144,176,208 (exact)
            cue(736,  Bestiary.ashion,  .line,   7, 0, 128),  // idx10 0x1D line  X=32..224 (exact)
            cue(864,  Bestiary.ashion,  .line,   6, 0, 128),  // idx11 0x1D line  X=48..208 (exact)
            cue(992,  Bestiary.ufolick, .stream, 1, 0, 128),  // idx12 0x24 edge-sweep (enters side nearest player)
            cue(1120, Bestiary.ufolick, .stream, 1, 0, 128),  // idx13 0x24 edge-sweep
            cue(1248, Bestiary.ufolick, .stream, 1, 0, 128),  // idx14 0x24 edge-sweep
            cue(1376, Bestiary.ufolick, .stream, 1, 0, 128),  // idx15 0x24 edge-sweep
            cue(1504, Bestiary.burdle,  .line,   4, 0, 128),  // idx16 0x1E line  X=80,112,144,176 (exact)
            cue(1632, Bestiary.burdle,  .line,   6, 0, 128),  // idx17 0x1E line  X=112,144,32,64,192,224 (approx)
            cue(1760, Bestiary.burdle,  .line,   4, 0, 128),  // idx18 0x1E line  X=32,224,176,80 (approx)
            cue(1888, Bestiary.burdle,  .line,   4, 0, 128),  // idx19 0x1E line  X=64,192,64,192 (approx)
            cue(2016, Bestiary.shamir,  .arc,    7, 0, 128),  // idx20 0x17 arc   X=32..224@32px, f14 Y-arch
            cue(2272, Bestiary.shamir,  .arc,    7, 0, 128),  // idx22 0x17 arc   X=32..224 (idx21 empty rest)
            cue(2528, Bestiary.aster,   .stream, 6, 0, 128),  // idx24 0x1B sweep all spawn X=128, f14=dir 6/10
            cue(2656, Bestiary.aster,   .stream, 6, 0, 128),  // idx25 0x1B sweep (idx23 empty rest)
            cue(2784, Bestiary.aster,   .stream, 6, 0, 128),  // idx26 0x1B sweep
            cue(2912, Bestiary.aster,   .stream, 6, 0, 128),  // idx27 0x1B sweep
            cue(3040, Bestiary.tinker,  .line,   8, 0, 120),  // idx28 0x21 dive  X=48..208
            cue(3168, Bestiary.tinker,  .line,   8, 0, 120),  // idx29 0x21 dive  X=48..208
            cue(3296, Bestiary.tinker,  .line,   8, 0, 120),  // idx30 0x21 dive  X=48..208
            cue(3424, Bestiary.tinker,  .line,   8, 0, 120),  // idx31 0x21 dive  X=48..208
            cue(3552, Bestiary.shamir,  .arc,    7, 0, 128),  // idx32 0x17 arc   X=32..224
            cue(3808, Bestiary.shamir,  .arc,    7, 0, 128),  // idx34 0x17 arc   X=32..224 (idx33,35 empty rest)
            cue(4064, Bestiary.ashion,  .line,   7, 0, 128),  // idx36 0x1D line  X=32..224 (exact)
            cue(4192, Bestiary.ashion,  .line,   6, 0, 128),  // idx37 0x1D line  X=48..208 (exact)
            cue(4320, Bestiary.ashion,  .line,   7, 0, 128),  // idx38 0x1D line  X=32..224 (exact)
            cue(4448, Bestiary.ashion,  .line,   6, 0, 128),  // idx39 0x1D line  X=48..208 (exact)
            cue(4576, Bestiary.burdle,  .line,   4, 0, 128),  // idx40 0x1E line  X=80,112,144,176 (exact)
            cue(4704, Bestiary.burdle,  .line,   4, 0, 128),  // idx41 0x1E line  X=64,192,96,160 (approx)
            cue(4832, Bestiary.burdle,  .line,   4, 0, 128),  // idx42 0x1E line  X=80,112,144,176 (exact)
            cue(4960, Bestiary.burdle,  .line,   4, 0, 128),  // idx43 0x1E line  X=64,192,96,160 (approx)
            cue(5088, Bestiary.ufolick, .stream, 1, 0, 128),  // idx44 0x24 edge-sweep
            cue(5216, Bestiary.ufolick, .stream, 1, 0, 128),  // idx45 0x24 edge-sweep
            cue(5344, Bestiary.ufolick, .stream, 1, 0, 128),  // idx46 0x24 edge-sweep
            cue(5472, Bestiary.ufolick, .stream, 1, 0, 128),  // idx47 0x24 edge-sweep
            cue(5600, Bestiary.aster,   .stream, 6, 0, 128),  // idx48 0x1B sweep X=128
            cue(5728, Bestiary.aster,   .stream, 6, 0, 128),  // idx49 0x1B sweep
            cue(5856, Bestiary.aster,   .stream, 6, 0, 128),  // idx50 0x1B sweep
            cue(5984, Bestiary.aster,   .stream, 6, 0, 128),  // idx51 0x1B sweep
            cue(6112, Bestiary.tinker,  .line,   8, 0, 120),  // idx52 0x21 dive  X=48..208
            cue(6240, Bestiary.tinker,  .line,   8, 0, 120),  // idx53 0x21 dive  X=48..208
            cue(6368, Bestiary.tinker,  .line,   8, 0, 120),  // idx54 0x21 dive  X=48..208
            cue(6496, Bestiary.tinker,  .line,   8, 0, 120),  // idx55 0x21 dive  X=48..208
            cue(6624, Bestiary.ashion,  .line,   7, 0, 128),  // idx56 0x1D line  X=32..224 (exact)
            cue(6752, Bestiary.ashion,  .line,   6, 0, 128),  // idx57 0x1D line  X=48..208 (exact)
            cue(6880, Bestiary.ashion,  .line,   7, 0, 128),  // idx58 0x1D line  X=32..224 (exact)
            cue(7008, Bestiary.ashion,  .line,   6, 0, 128),  // idx59 0x1D line  X=48..208 (exact)
            cue(7136, Bestiary.ashion,  .line,   7, 0, 128),  // idx60 0x1D line  X=32..224 (exact)
        ]
        return Level(id: .asteroid, scrollSpeed: Tuning.scrollSpeed, scrollLength: 7392,
                     waves: waves, boss: BossSpec(id: "nebiros", hp: 70),
                     background: BackgroundRef("asteroid"), music: "asteroid")
    }

    static func nebula() -> Level {
        // Nebula — variant2 wave table (root 0x40A9), decoded 2026-08 and re-verified (zero discrepancies).
        // romType/count/member-X ROM-EXACT; formation/baseX best-fit; names provisional. caborn (0x1F) is
        // INDESTRUCTIBLE (a hazard, not a kill). MIXED indices carry two romTypes → two cues at one atScroll.
        // atScroll = 128*idx − 544. Boss Belzebul (0x2D + 0x2C ×4 + 0x2B ×4) at scrollLength. NOT yet measured.
        let waves: [WaveCue] = [
            cue(96,   Bestiary.tricker, .line,   2, 0, 128),  // idx5  0x26 ring-fire  X=16,240 (EDGES — approx)
            cue(224,  Bestiary.tricker, .line,   2, 0, 128),  // idx6  0x26 ring-fire  X=16,240 (idx7 empty rest)
            cue(480,  Bestiary.arbleby, .stream, 4, 0, 128),  // idx8  0x1A swoop-to-player; f13=1,16,32,48 stagger
            cue(608,  Bestiary.arbleby, .stream, 4, 0, 128),  // idx9  0x1A swoop
            cue(736,  Bestiary.arbleby, .stream, 4, 0, 128),  // idx10 0x1A swoop
            cue(864,  Bestiary.arbleby, .stream, 4, 0, 128),  // idx11 0x1A swoop
            cue(992,  Bestiary.caborn,  .line,   8, 0, 128),  // idx12 0x1F INDESTRUCTIBLE X=16,240,48,208,176,80,112,144
            cue(1120, Bestiary.caborn,  .line,   7, 0, 128),  // idx13 0x1F INDESTRUCTIBLE X=32,224,64,192,160,96,128
            cue(1248, Bestiary.caborn,  .line,   8, 0, 128),  // idx14 0x1F INDESTRUCTIBLE X=16,240,48,208,176,80,112,144
            cue(1376, Bestiary.caborn,  .line,   7, 0, 128),  // idx15 0x1F INDESTRUCTIBLE X=32,224,64,192,160,96,128
            cue(1504, Bestiary.dririt,  .line,   3, 0, 117),  // idx16 0x20 splitter X=176,112,64
            cue(1632, Bestiary.dririt,  .line,   3, 0, 128),  // idx17 0x20 splitter X=160,80,144
            cue(1760, Bestiary.dririt,  .line,   3, 0, 139),  // idx18 0x20 splitter X=192,128,96
            cue(1888, Bestiary.dririt,  .line,   3, 0, 128),  // idx19 0x20 splitter X=96,128,160
            cue(2016, Bestiary.triat,   .line,   3, 0, 128),  // idx20 0x25 ARMORED-8HP X=128,64,192
            cue(2144, Bestiary.triat,   .line,   5, 0, 128),  // idx21 0x25 ARMORED-8HP X=80,176,32,128,224
            cue(2272, Bestiary.triat,   .line,   5, 0, 128),  // idx22 0x25 ARMORED-8HP X=80,176,32,128,224
            cue(2400, Bestiary.triat,   .line,   5, 0, 128),  // idx23 0x25 ARMORED-8HP X=80,176,32,128,224
            cue(2528, Bestiary.dilon,   .line,   2, 0, 128),  // idx24 0x23 carrier X=64,192
            cue(2656, Bestiary.dilon,   .line,   2, 0, 128),  // idx25 0x23 carrier X=48,208
            cue(2784, Bestiary.dilon,   .line,   2, 0, 128),  // idx26 0x23 carrier X=64,192
            cue(2912, Bestiary.dilon,   .line,   2, 0, 128),  // idx27 0x23 carrier X=104,152
            cue(3040, Bestiary.caborn,  .line,   6, 0, 128),  // idx28 0x1F INDESTRUCTIBLE X=48,80,112,144,176,208
            cue(3168, Bestiary.tricker, .line,   2, 0, 128),  // idx29 MIXED 0x26 x2 X=16,240
            cue(3168, Bestiary.caborn,  .line,   5, 0, 128),  // idx29 MIXED 0x1F x5 X=64,96,128,160,192 (INDESTRUCTIBLE)
            cue(3424, Bestiary.triat,   .line,   3, 0, 128),  // idx31 0x25 ARMORED-8HP X=128,64,192
            cue(3552, Bestiary.triat,   .line,   5, 0, 128),  // idx32 0x25 ARMORED-8HP X=80,176,32,128,224
            cue(3680, Bestiary.triat,   .line,   5, 0, 128),  // idx33 0x25 ARMORED-8HP X=80,176,32,128,224
            cue(3808, Bestiary.triat,   .line,   5, 0, 128),  // idx34 0x25 ARMORED-8HP X=80,176,32,128,224
            cue(4064, Bestiary.dririt,  .line,   3, 0, 117),  // idx36 0x20 splitter X=176,112,64
            cue(4192, Bestiary.dririt,  .line,   3, 0, 128),  // idx37 0x20 splitter X=160,80,144
            cue(4320, Bestiary.dririt,  .line,   3, 0, 139),  // idx38 0x20 splitter X=192,128,96
            cue(4448, Bestiary.dririt,  .line,   3, 0, 128),  // idx39 0x20 splitter X=96,128,160
            cue(4576, Bestiary.tricker, .line,   2, 0, 128),  // idx40 MIXED 0x26 x2 X=16,240
            cue(4576, Bestiary.arbleby, .stream, 4, 0, 128),  // idx40 MIXED 0x1A x4 swoop
            cue(4704, Bestiary.arbleby, .stream, 4, 0, 128),  // idx41 0x1A swoop  f13=1,24,48,72
            cue(4832, Bestiary.tricker, .line,   2, 0, 128),  // idx42 MIXED 0x26 x2 X=16,240
            cue(4832, Bestiary.arbleby, .stream, 4, 0, 128),  // idx42 MIXED 0x1A x4 swoop
            cue(4960, Bestiary.arbleby, .stream, 4, 0, 128),  // idx43 0x1A swoop  f13=1,16,48,64
            cue(5088, Bestiary.dilon,   .line,   2, 0, 128),  // idx44 0x23 carrier X=64,192
            cue(5216, Bestiary.dilon,   .line,   2, 0, 128),  // idx45 0x23 carrier X=48,208
            cue(5344, Bestiary.dilon,   .line,   2, 0, 128),  // idx46 0x23 carrier X=64,192
            cue(5472, Bestiary.dilon,   .line,   2, 0, 128),  // idx47 0x23 carrier X=104,152
            cue(5600, Bestiary.tricker, .line,   2, 0, 128),  // idx48 MIXED 0x26 x2 X=16,240
            cue(5600, Bestiary.triat,   .line,   3, 0, 128),  // idx48 MIXED 0x25 x3 ARMORED-8HP X=128,64,192
            cue(5728, Bestiary.triat,   .line,   5, 0, 128),  // idx49 0x25 ARMORED-8HP X=80,176,32,128,224
            cue(5856, Bestiary.tricker, .line,   4, 0, 128),  // idx50 MIXED 0x26 x4 X=240,240,16,16 (EDGES — approx)
            cue(5856, Bestiary.triat,   .line,   5, 0, 128),  // idx50 MIXED 0x25 x5 ARMORED-8HP X=80,176,32,128,224
            cue(5984, Bestiary.triat,   .line,   5, 0, 128),  // idx51 0x25 ARMORED-8HP X=80,176,32,128,224
            cue(6112, Bestiary.tricker, .line,   2, 0, 128),  // idx52 MIXED 0x26 x2 X=16,240
            cue(6112, Bestiary.triat,   .line,   3, 0, 128),  // idx52 MIXED 0x25 x3 ARMORED-8HP X=128,64,192
            cue(6240, Bestiary.triat,   .line,   5, 0, 128),  // idx53 0x25 ARMORED-8HP X=80,176,32,128,224
            cue(6368, Bestiary.tricker, .line,   4, 0, 128),  // idx54 MIXED 0x26 x4 X=240,240,16,16
            cue(6368, Bestiary.triat,   .line,   5, 0, 128),  // idx54 MIXED 0x25 x5 ARMORED-8HP X=80,176,32,128,224
            cue(6496, Bestiary.triat,   .line,   5, 0, 128),  // idx55 0x25 ARMORED-8HP X=80,176,32,128,224
            cue(6624, Bestiary.arbleby, .stream, 4, 0, 128),  // idx56 0x1A swoop
            cue(6752, Bestiary.arbleby, .stream, 4, 0, 128),  // idx57 0x1A swoop
            cue(6880, Bestiary.arbleby, .stream, 4, 0, 128),  // idx58 0x1A swoop
            cue(7008, Bestiary.arbleby, .stream, 4, 0, 128),  // idx59 0x1A swoop
        ]
        return Level(id: .nebula, scrollSpeed: Tuning.scrollSpeed, scrollLength: 7392,
                     waves: waves, boss: BossSpec(id: "belzebul", hp: 80),
                     background: BackgroundRef("nebula"), music: "nebula")
    }
}
