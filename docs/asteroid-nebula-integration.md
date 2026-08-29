# Asteroid & Nebula — staged integration (paste-ready)

> **Status: NOT yet integrated into the sim.** This is the paste-ready output of the
> 2026-08-29 ROM-extraction pass, parked here so the next session can wire it in by
> copy-paste. The *findings* behind it are in [`parity-findings.md`](parity-findings.md) §4d.
> Source ROM `AstroWarrior.sms` md5 `e645faa5628caab5129383fdbf4df090`.
>
> **Confidence tags:** romType / count / per-member X and all HP/points/hitbox values are
> **ROM-EXACT** (disassembly + byte read). Formation choice, `baseX`, movement/attack numeric
> tuning, and every **species name** are **INFERRED** (best-fit onto the sim's coarser model;
> names by hitbox-size/role, only tinker=0x21 and arbleby=0x1A anchored). See the open
> questions at the bottom before treating names or tuning as settled.

## Integration checklist (the "later" task)

1. Paste the **Asteroid waves** block into `DefaultContent.asteroid()` and the **Nebula waves**
   block into `DefaultContent.nebula()` (replacing `waves: []`), following the existing
   `galaxy()` shape (a `let waves: [WaveCue] = [...]` then `Level(...)`).
2. Set `scrollLength: 7392` on **both** `asteroid()` and `nebula()` (was placeholder `2000`;
   boss fires at wave idx62 = `128*62 − 544`). Leave the boss `BossSpec` ids as-is for now.
3. Paste the **Bestiary** bodies over the Asteroid/Nebula `placeholder(...)` stubs.
4. `cd AstroWarriorKit && swift build` then `swift run ParityProbe` to confirm it still boots
   and the schedules stream. (Keep to `swift build`/`run` — do **not** trigger Xcode app builds;
   DerivedData is the disk-pressure culprit.)
5. Commit → PR → auto-merge.

Deferred to follow-up sessions (not this paste): the multi-part boss model (Nebiros/Belzebul),
the carrier-spawn (dilon) & self-split (dririt) behaviors, a per-member explicit-X formation for
edge/scattered waves, species-name confirmation, and movement/attack numeric calibration.

---

## Asteroid waves → `DefaultContent.asteroid()`

```swift
// Asteroid stage — ROM wave-spawn table variant1 (root 0x4029), extracted from
// AstroWarrior.sms (md5 e645faa5628caab5129383fdbf4df090).
//   ROM-EXACT: romType, count, per-member X (shown in each comment).
//   INFERRED : formation (sim's coarse .line/.stream/.vee/.arc model) + baseX; species
//              NAMES (behavior is ROM-exact; the name binding is provisional — see Bestiary).
//
// atScroll = 128*idx - 544  (frames; Level.scrollSpeed = 1 tick/frame).
//   • slope 128 frames/wave-index is ROM-EXACT (cycle-sim of scroll routine 0x0D44).
//   • -544 is the harness measurement-origin offset (matches the existing Galaxy cues).
//   • NOTE: Galaxy idx5 was empirically 181, not the formula's 96 — the first content
//     index may want a small warm-up nudge (unresolved). interval = 0: the ROM emits all
//     members of a wave in one spawner call; intra-wave stagger is handler-driven.
//   • .line reproduces ROM X EXACTLY where members are 32px-uniform (all 0x1D waves,
//     0x1E idx16/40); it is an APPROXIMATION for scattered/edge waves.
let waves: [WaveCue] = [
    // atScroll  species            formation count interval baseX     ── ROM idx / type / X row ──
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
    cue(2016, Bestiary.shamir,  .arc,    7, 0, 128),  // idx20 0x17 arc   X=32..224@32px, f14 Y-arch 1,32,48,56,48,32,1
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
    // idx61 = empty rest.
    // TODO idx62 @7392: NEBIROS boss = romType 0x29 x5 segments (f13=0..4) — spawned via
    //   BossSpec(id:"nebiros") at scrollLength, not as a WaveCue in this array.
]
```

## Nebula waves → `DefaultContent.nebula()`

```swift
// Nebula stage — ROM wave-spawn table variant2 (root 0x40A9), extracted from
// AstroWarrior.sms (md5 e645faa5628caab5129383fdbf4df090).
//   ROM-EXACT: romType, count, per-member X.  INFERRED: formation + baseX; species NAMES.
//
// atScroll = 128*idx - 544 frames (see Asteroid header for the full derivation & caveats).
// MIXED waves (idx29/40/42/48/50/52/54) carry two enemy types in one ROM record list; each
//   is emitted as TWO cues at the SAME atScroll (the director fires both). interval = 0.
// caborn (0x1F) is INDESTRUCTIBLE (Bestiary sets indestructible:true) — it is a moving
//   hazard, not a kill. 0x1F/0x1A/0x20/0x25/0x23 X-lists are scattered → .line is approximate.
let waves: [WaveCue] = [
    // atScroll  species             formation count interval baseX    ── ROM idx / type / X row ──
    cue(96,   Bestiary.tricker, .line,   2, 0, 128),  // idx5  0x26 ring-fire  X=16,240 (EDGES — approx)
    cue(224,  Bestiary.tricker, .line,   2, 0, 128),  // idx6  0x26 ring-fire  X=16,240 (idx7 empty rest)
    cue(480,  Bestiary.arbleby, .stream, 4, 0, 128),  // idx8  0x1A swoop-to-player; f13=1,16,32,48 stagger
    cue(608,  Bestiary.arbleby, .stream, 4, 0, 128),  // idx9  0x1A swoop
    cue(736,  Bestiary.arbleby, .stream, 4, 0, 128),  // idx10 0x1A swoop
    cue(864,  Bestiary.arbleby, .stream, 4, 0, 128),  // idx11 0x1A swoop
    cue(992,  Bestiary.caborn,  .line,   8, 0, 128),  // idx12 0x1F INDESTRUCTIBLE X=16,240,48,208,176,80,112,144; f15 stagger
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
    // idx30 = empty rest.
    cue(3424, Bestiary.triat,   .line,   3, 0, 128),  // idx31 0x25 ARMORED-8HP X=128,64,192
    cue(3552, Bestiary.triat,   .line,   5, 0, 128),  // idx32 0x25 ARMORED-8HP X=80,176,32,128,224
    cue(3680, Bestiary.triat,   .line,   5, 0, 128),  // idx33 0x25 ARMORED-8HP X=80,176,32,128,224
    cue(3808, Bestiary.triat,   .line,   5, 0, 128),  // idx34 0x25 ARMORED-8HP X=80,176,32,128,224
    // idx35 = empty rest.
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
    // idx60,61 = empty rest.
    // TODO idx62 @7392: BELZEBUL boss = 0x2D core + 0x2C x4 + 0x2B x4 (9 pieces) — spawned via
    //   BossSpec(id:"belzebul") at scrollLength, not as WaveCues in this array.
]
```

## Bestiary bodies → replace the Asteroid/Nebula `placeholder(...)` stubs

```swift
// hp / points / hitbox radius / indestructible are ROM-EXACT (handler disassembly +
// collision table @0x1B1C). movement/attack are best-fit onto the existing primitives —
// the BEHAVIOR is ROM-derived, but the numeric tuning (speeds, fire intervals, bullet
// speeds) is INFERRED pending velocity measurement. Species NAMES are provisional (LOW):
// only tinker=0x21 (smallest box) and arbleby=0x1A (largest box) have a real anchor.

    // —— Asteroid Zone ——  (romType handlers 0x17/0x1B/0x1D/0x1E/0x21/0x24, bank1)
    public static func aster() -> Enemy {          // romType 0x1B @0x4D66 — center sweeper, 1-HP, no fire
        Enemy(at: .zero, sprite: SpriteRef("aster"), hitbox: .circle(r: 8),
              hp: 1, points: 100,
              movement: Weave(speed: 1.4, amp: 40, freq: 0.05),
              attack: NoAttack())
    }
    public static func shamir() -> Enemy {         // romType 0x17 @0x49AC — aimed diver/rammer, 1-HP, no fire
        Enemy(at: .zero, sprite: SpriteRef("shamir"), hitbox: .circle(r: 8),
              hp: 1, points: 200,
              movement: Dive(speed: 2.0),
              attack: NoAttack())
    }
    public static func ufolick() -> Enemy {        // romType 0x24 @0x5302 — edge sweeper + 6-shot burst, 1-HP
        Enemy(at: .zero, sprite: SpriteRef("ufolick"), hitbox: .circle(r: 8),
              hp: 1, points: 200,
              movement: Weave(speed: 1.2, amp: 60, freq: 0.04),
              attack: RingFire(interval: 90, count: 6, bulletSpeed: 2.0))
    }
    public static func burdle() -> Enemy {         // romType 0x1E @0x4EA7 — descend, turn, aimed shot, 1-HP
        Enemy(at: .zero, sprite: SpriteRef("burdle"), hitbox: .circle(r: 7),
              hp: 1, points: 100,
              movement: Descend(speed: 1.3),
              attack: AimedShot(interval: 100, bulletSpeed: 2.2))
    }
    public static func ashion() -> Enemy {         // romType 0x1D @0x4DE5 — descend + shot, survives a hit (~2-HP)
        Enemy(at: .zero, sprite: SpriteRef("ashion"), hitbox: .circle(r: 7),
              hp: 2, points: 100,
              movement: Descend(speed: 1.2),
              attack: AimedShot(interval: 110, bulletSpeed: 2.2))
    }
    public static func tinker() -> Enemy {         // romType 0x21 @0x50C3 — smallest box, aimed random-accel diver, 1-HP
        Enemy(at: .zero, sprite: SpriteRef("tinker"), hitbox: .circle(r: 4),
              hp: 1, points: 100,
              movement: Dive(speed: 2.2),
              attack: NoAttack())
    }

    // —— Nebula Zone ——  (romType handlers 0x1A/0x1F/0x20/0x23/0x25/0x26, bank1)
    public static func caborn() -> Enemy {         // romType 0x1F @0x4F41 — INDESTRUCTIBLE drifting debris
        Enemy(at: .zero, sprite: SpriteRef("caborn"), hitbox: .circle(r: 2),
              hp: 1, points: 0,
              movement: Descend(speed: 1.0),
              attack: NoAttack(),
              indestructible: true)
    }
    public static func dilon() -> Enemy {          // romType 0x23 @0x51EB — carrier: hovers, launches type-0x18 divers
        // TODO: carrier-spawn (births type-0x18 divers) has no sim primitive yet — modeled inert.
        Enemy(at: .zero, sprite: SpriteRef("dilon"), hitbox: .circle(r: 6),
              hp: 1, points: 200,
              movement: FormationHold(speed: 0.6),
              attack: NoAttack())
    }
    public static func triat() -> Enemy {          // romType 0x25 @0x5428 — ARMORED 8-HP sweeper + 2-shot
        Enemy(at: .zero, sprite: SpriteRef("triat"), hitbox: .circle(r: 6),
              hp: 8, points: 200,
              movement: Weave(speed: 1.0, amp: 50, freq: 0.04),
              attack: AimedShot(interval: 120, bulletSpeed: 2.0))
    }
    public static func dririt() -> Enemy {         // romType 0x20 @0x4FB5 — self-splitter, 1-HP, no fire
        // TODO: on spawn it clones a mirrored sibling — no split primitive yet; modeled as plain descent.
        Enemy(at: .zero, sprite: SpriteRef("dririt"), hitbox: .circle(r: 8),
              hp: 1, points: 100,
              movement: Descend(speed: 1.4),
              attack: NoAttack())
    }
    public static func arbleby() -> Enemy {        // romType 0x1A @0x4C64 — largest box, swoop-to-player + fire, 1-HP
        Enemy(at: .zero, sprite: SpriteRef("arbleby"), hitbox: .circle(r: 10),
              hp: 1, points: 200,
              movement: Dive(speed: 1.8),
              attack: AimedShot(interval: 100, bulletSpeed: 2.2))
    }
    public static func tricker() -> Enemy {        // romType 0x26 @0x54B8 — edge ring-fire emplacement, 1-HP
        Enemy(at: .zero, sprite: SpriteRef("tricker"), hitbox: .circle(r: 8),
              hp: 1, points: 100,
              movement: Descend(speed: 0.8),
              attack: RingFire(interval: 80, count: 4, bulletSpeed: 1.8))
    }
```

## Open questions to resolve before this is "faithful"

1. **Species names are provisional** — behavior/stats are ROM-exact; the type→name binding is
   inferred by hitbox-size/role for 10 of 12. Confirm via bank-4 sprite-pixel decode + a
   screen-capture reference.
2. **`atScroll` −544 offset** is a harness artifact, not intrinsic; Galaxy idx5 was 181 vs the
   formula's 96, so the first content index of each stage may want a warm-up nudge. Confirm the
   true stage-start seed of `0xC211`.
3. **Formation model is too coarse** for scattered-X and edge waves (`.line` is exact only for
   32px-uniform rows). A formation variant taking an explicit per-member X list would make the
   0x21/0x1E/0x1F/0x20/0x26 waves exact (the X lists are in the cue comments).
4. **Movement/attack tuning is best-fit** — real velocities live in slot-2 vector tables; convert
   and calibrate.
5. **Carrier (dilon) and self-split (dririt)** need new `AttackBehavior`/on-spawn hooks.
6. **`ashion` effective HP** (~2) is spawn-geometry gated — confirm the real mechanic.
7. **Boss model** — Nebiros (0x29 ×5) and Belzebul (0x2D+0x2C×4+0x2B×4) are multi-part entity
   bosses at idx62, plus a separate scripted end-boss (core 0x27, real 8-hit counter, idx65).
   A single-`Int` `BossSpec` can't capture this; decode the phase scripts at `0xA858`/`0xD030`.

See [`parity-findings.md`](parity-findings.md) §4d for the full findings and evidence.
