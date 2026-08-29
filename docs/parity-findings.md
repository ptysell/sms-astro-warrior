# Astro Warrior — Parity Findings & Reverse-Engineering Reference

Values measured from the **original ROM** (`Astro Warrior.sms`, © SEGA 1986, TMR SEGA,
checksum `0x7511`) by driving it headlessly through a vendored SMS emulator core and
reading its work RAM. This is the authoritative record of what has been extracted and
verified so far — the "data bridge" the build blueprint (§16) calls for.

> **How these were found:** the parity debugger (`ParityDebug`) runs the ROM beside our
> Swift sim in deterministic lockstep; `ParityProbe` drives the ROM headlessly and reads
> RAM / dumps frames. Every value below was confirmed either by a side-by-side parity bot
> (ship tracks the ROM to ±1 frame) or by motion analysis, then **independently
> re-verified by an adversarial multi-agent audit**.

---

## 1. Work-RAM map

### Player ship (entity slot 0 @ `0xC600`)
| Field | Address | Format | Notes |
|---|---|---|---|
| type | `0xC600` | u8 | `1` = player |
| **Y** | `0xC608`/`0xC609` | 8.8 fixed, LE | screen coords (0 = top) |
| **X** | `0xC60A`/`0xC60B` | 8.8 fixed, LE | screen coords |

Read a 16-bit value as `lo | (hi << 8)` — **cast to `Int` before the shift** (a `UInt8 << 8`
silently yields 0).

### Boss timer (`0xC020:0xC021`) — NOT the scroll length
| Address | Format | Meaning |
|---|---|---|
| `0xC020` | u16 LE | stage countdown timer; decrements 1/frame; **boss spawns when it hits 0** |

**Correction (the "907" was wrong):** this counter is **initialised to 1080** (`0x0438`), by the
literal `LD HL,0x0438` at ROM `0x1DE1` → `LD (0xC020),HL` (a second phase inits `1800`/`0x0708`
at `0x1E20`). The value **907 appears nowhere in the ROM** — it was a *boot-timing sampling
artifact*: the counter is set during the attract sequence and is already ~907 by the time the
probe pressed start. So `0xC020` is a **timer** that ends the stage; it is **only ever tested
`== 0`** and does **not gate waves**. **Waves are gated by scroll-row position** (see §4c). The
VDP vertical scroll register (reg 9) still advances **0.5 px/frame** (scroll accumulator `0xC214`
`+= 0x80`/frame). Scrolling begins ~15 frames after the player entity appears.

### Other useful addresses
| Address | Meaning |
|---|---|
| `0xC6C0` | first player-bullet slot (type `2`) |
| `0xC211` | **wave-index** — increments with scroll rows; drives the wave-spawn table (§4c) |
| `0xC280` | last-spawned wave-index (spawn fires when `0xC211` ≠ `0xC280`) |
| `0xC240` | stage/variant selector — `mod 3` picks Galaxy(0)/v1/v2 in the wave table |
| `0xC214`/`0xC223` | 16-bit scroll accumulator / per-frame scroll speed (`0x80`) |
| `0xC286` | a per-frame countdown timer (NOT a frame counter — the RE doc's `0xC01C` is wrong) |

### Entity pool
40 slots (`0x28`), base `0xC600`, stride `0x40`. Struct: `+0x00` type (0 = inactive),
`+0x08` Y (8.8), `+0x0A` X (8.8), `+0x13` **subtype/direction flag** (from the wave record — NOT
packed HP, correcting an earlier note), `+0x14` spawn-X seed / pattern byte. Active wave members
occupy the `0xCA00`-region slots. The updater alternates forward (`IX=0xC600`) / backward
(`IX=0xCFC0`) sweeps by frame, gated by `BIT 0,(0xC200)`.

---

## 2. Entity type catalog

Classified by **motion signature** (unambiguous and wave-proof — type *values* differ per
wave, so a fixed enemy list won't do):

| Type(s) | Category | Signature |
|---|---|---|
| `1` | **player** | input-driven |
| `2` | **player bullet** | moves up ~12 px/f |
| `18` | **power-up pickup** | drops straight down the **centre** (avgX ≈ 128) |
| `11`, `12`, `19` | **fx / HUD** | static / fixed-position; `19` = the death/explosion FX |
| `21` | **Cult** (Galaxy) | ringed magenta/green disc; row-of-4, converging descent |
| `24` | Galaxy grunt (chevron) | small yellow chevron; centre-column stream, curves down-right |
| `22` | **Zanoni boss turret** | green "X" defenders on the fortress |
| `20`, `25`, `39`, … | **enemy species** | later zones / variants |

### Type-dispatch mechanism (disassembled, bank-0)
The per-entity update dispatcher lives at file offset **`0x03FE`**. It reads the entity's
type byte (`LD A,(IX+0)`), and — **with no mask, subtract, or shift** — uses `type × 2` as a
word index into a jump table at **`0x0518`** (`LD HL,0x0518; ADD HL,DE; JP (HL)`). So the RAM
type byte *is* the dispatch index. Consequences:
- The reference doc's "16-entry table (types 1–15)" is an **undercount** — the table is
  ~47 entries; low types are bank-0 handlers, higher types dispatch into **paged-bank**
  handlers. The three measured Galaxy types resolve cleanly: `21→0x4842`, `22→0x48E4`,
  `24→0x4A5F` (all begin with the same `BIT 7,(IX+1)` handler guard).
- The pool is re-confirmed as **40 slots (`0x28`) at `0xC600`, stride `0x40`, type at `+0x00`**.
  The updater alternates forward (`IX=0xC600,+0x40`) / backward (`IX=0xCFC0,−0x40`) sweeps by
  frame, gated by `BIT 0,(0xC200)`.

Notes:
- **Enemy bullets are rare** in early Galaxy — most on-screen "red dots" are the dense
  starfield, not projectiles. No enemy-bullet entity type was seen during the Galaxy grunt
  waves (Cult/chevron do **not** fire; ring-fire belongs to the heavies).
- **Power-up blocks** are *background name-table tiles* (VRAM `0x3800`), **not** pool
  entities — they don't appear in the entity table. Galaxy holds **159** blocks.
- Type→official-name, cross-checked against a **bank-4 (file `0x10000`) sprite decode** (SMS
  4bpp planar, 2×2 sprites stored **column-major**):
  - **`21 = Cult`** — concentric ringed discs at tiles 16–31 (`0x10200–0x103FF`). Confirmed.
  - **`22` = the "X" fortress turret** — clean X at tiles 36–39 (`0x10480`). Confirmed.
  - **`24` = chevron** at tiles 0–15 (`0x10000`) — a small Y/V shape; official name **Sharlin
    (likely; vs Sacle)**. It is **not** Curos.
  - **Curos** is the separate **"+/cross"** sprite at tile 40 (`0x10500`) — the reference doc's
    "bank 4 tile 40 (100% match)" — and was **not** seen in Galaxy stage 1.

---

## 3. Measured tuning values (in `GameSim/Tuning.swift`)

| Constant | Value | How measured |
|---|---|---|
| `shipSpeed` | **1.5 px/frame, total (normalized)** — diagonal ≈ 1.06/axis (1.5/√2) | parity bot; tracks ROM to ±1 frame |
| `shipStartScreenY` | **144** (→ start Y = 48 in our +Y-up space) | RAM read at stage start |
| `shipBulletSpeed` | **12 px/frame** (upward) | tracked the bullet entity's Y |
| `shipFireInterval` | **~8 frames** between shots | counted bullet spawns |
| movement bounds | **X ∈ [18, 242]**, screen-Y ∈ **[0, 182]** (our y ∈ [10, 192]) | pushed the ship into each wall |
| `scrollSpeed` | **0.5 px/frame** (accum `0xC214 += 0x80`/frame) | scroll engine at `0x0D44` |
| `visualScrollPxPerTick` | **0.5 px/frame** (VDP reg 9 changes every 2 frames) | sampled VDP reg 9 |
| Galaxy stage length | boss on the **1080-init `0xC020` timer** hitting 0 (~880 scroll-frames as observed; "907 ticks" was a boot-sampling artifact — see the boss-timer note) | drove to boss |

---

## 4a. Score system

Score is BCD. **CORRECTION (session 4):** `0xC030–0xC032` is the **HIGH-SCORE** buffer; the **live
in-play score** is `0xC232–0xC234` (`0xC234` = fixed `00` low byte). During a first playthrough the
two track together (score ≥ hi-score), which is why hundreds-place deltas read cleanly at `0xC031`
below. The scoring routine `0x5C52` reads the reward index `(IX+0x1B)` → `[0x5C60 + idx*2]` (BCD):
idx1=100, idx2=200, idx3=1000, idx4=5000.

### Points per enemy type (from isolated single-kill frame deltas)
| ROM type | BCD delta (in C031) | Points | Confidence |
|---|---|---|---|
| 34 | +2 | **200** | high (7/7 consistent) |
| 21 | +1 | **100** | high (3/4 isolated; 1 multi-kill frame) |
| 22 | +1 | **100** | medium (1 confirmed kill) |
| 39 | +1 | **100** | medium (2 confirmed kills) |
| 24 | +1 or +10 | **100–1000** | low (multi-kill frame contamination) |

### Entity struct +0x13 — subtype/direction flag (NOT packed HP)
Correcting an earlier guess: `+0x13` is loaded straight from the wave record's `b1` byte
(§4c) and is a **subtype / direction flag** (`0x00` or `0x01` for the Galaxy grunts), not
packed HP. Per-enemy HP for the heavies/boss-core is still `[extract]` (grunts are 1-HP).

---

## 4b. Galaxy stage layout — initial wave schedule (MEASURED)

> **Superseded by §4e for the current state.** This section records the initial idx5..11 measurement.
> The **full idx5..60** schedule was later decoded, census-crosschecked, and integrated into
> `DefaultContent.galaxy()` — see §4e.

Driven headlessly (`ParityProbe` `census()`), then **verified deterministic**: two different
bots (an active dodger and a passive centre-holder) produced an **identical** spawn schedule.
Spawning is **scroll-scripted** — waves fire whether or not you clear the previous one — and is
**independently confirmed by the ROM wave-spawn table** (§4c) which decodes to this exact schedule.
`atScroll` below is the measured scroll position of each wave (the "countdown" column is the raw
`0xC020` value in one boot — see the boss-timer note on why it isn't the scroll length).

The entire Galaxy stage is **six waves of two grunt species, then the fortress boss** — far
sparser than the 19-wave placeholder that preceded this measurement.

| # | countdown | atScroll | romType | species | count | formation | baseX (screen-x) |
|---|---|---|---|---|---|---|---|
| 1 | 726 | 181 | 24 | chevron | 6 | centre column, released ~9 f apart | 128 |
| 2 | 555 | 352 | 24 | chevron | 6 | centre column | 128 |
| 3 | 427 | 480 | 21 | **Cult** | 4 | flat row, ~32 px apart | ~64 (left, x 16–112) |
| 4 | 299 | 608 | 21 | **Cult** | 4 | flat row | ~188 (right, x 140–236) |
| 5 | 171 | 736 | 21 | **Cult** | 4 | flat row | ~126 (centre) |
| 6 | 43 | 864 | 21 | **Cult** | 4 | flat row | ~126 (centre) |
| — | 0 | 907 | 22 | Zanoni fortress | — | boss | — |

Note the cadence: waves 2–6 are spaced **exactly 128 countdown-ticks** apart (555, 427, 299,
171, 43). **Wave X anchors are scripted, not random** — this corrected a real sim bug where
`World.spawn` chose `baseX` via RNG; the model now carries a scripted `Wave.baseX`.

### Grunt motion (traced per-frame)
- **Cult (type 21):** enters as a flat row of 4, ~32 px apart, at screen-y ≈ 0; descends
  ~**1.5 px/f** while **converging toward centre** (leftmost drifts right, rightmost drifts
  left). 1-HP, **100 pts**, no fire.
- **Chevron (type 24):** six spawn stacked at `(128, 0)` and **release ~9 frames apart**, each
  tracing an identical **down-right curve** (~**1.7 px/f** down, accelerating rightward). 1-HP,
  **100 pts**, no fire.
- Convergence (Cult) and right-curve (chevron) are per-enemy motion refinements not yet in the
  sim's movement primitives — noted as TODOs in `Bestiary`.

### Boss — Zanoni is a *fortress*, not a single sprite
At countdown 0 a large scrolling **teal-tiled fortress** fills the screen: green "X"
turret-defenders (romType 22) fly across it in groups, cannon ports are embedded in the tiles,
and a dark circular **core** sits at the bottom. This is the classic Astro-Warrior end-of-zone
base. A faithful boss model (fortress tilemap + core HP + turret script) is still `[extract]`.

Still `[extract]`: per-enemy HP for the heavies + boss core, hitboxes, boss scripts,
power-up ladder effects, per-zone stage lengths, and official names for most non-Galaxy types.
**Galaxy grunts (Cult/chevron) are confirmed 1-HP.**

---

## 4c. Wave-spawn table (ROM `0x3FA3`) — the whole game's schedule, decoded

The spawner routine at ROM **`0x3F2B`** runs each frame and emits a wave whenever the scroll-row
wave-index `0xC211` differs from the last-spawned `0xC280`. It reads a **3-level table**:

1. **Root `0x3FA3`** — three variant pointers `→0x3FA9, →0x4029, →0x40A9`, selected by
   `0xC240 mod 3`. **Variant 0 = Galaxy** (decodes to the measured schedule, 1:1); variants 1 & 2
   are the other two stages (Asteroid / Nebula — different rosters).
2. **Level-2 list** (per variant) — one word per wave-index; empty indices share a terminator
   pointer (e.g. Galaxy `0x4129`).
3. **Level-3 records** — 4 bytes each `[type, b1, b2, b3]` → entity `+0x00/+0x13/+0x14/+0x15`;
   a `type == 0` byte terminates the wave. For **line** enemies `b2 = spawn X` (spacing `0x20` =
   32 px); for the **stream** enemy `b3 = member×8` release stagger.

**Variant 0 (Galaxy) — decoded, matches the empirical run exactly:**

| waveIdx | count×type | member X (`b2`) / stagger (`b3`) |
|---|---|---|
| 5, 7 | 6× `0x18` (chevron) | X ordinal 1‥6, stagger `8,16,24,32,40,48` |
| 8 | 4× `0x15` (Cult) | X = `10 30 50 70` (16,48,80,112) |
| 9 | 4× `0x15` | X = `90 B0 D0 F0` (144,176,208,240) |
| 10, 11 | 4× `0x15` | X = `50 70 90 B0` (80,112,144,176) |
| 12–14 | 4× `0x16` (turret) | fortress-defender phase |
| 16–23 | more `0x18`/`0x15`/`0x27` | extended / later-loop indices |

**Variants 1 & 2 decode cleanly too** (types are byte values; not yet name-mapped): variant 1 uses
`0x21` (×8), `0x1D` (×6–7), `0x24` (the "+/cross" = **Curos**, so Curos is a variant-1 enemy, not
Galaxy), `0x1E`, `0x17`; variant 2 uses `0x26`, `0x1A`, `0x1F` (×7–8, staggered), `0x20`, `0x25`.
Full per-index dumps are reproducible from `0x3FA3` with the record format above. This means the
**entire game's wave content is statically extractable** — the remaining gap for Asteroid/Nebula
is anchoring each wave-index to a scroll position and mapping the type bytes to species.

> **Done (2026-08-29) — see §4d.** Both remaining gaps are now closed: all 192 waves decoded and
> independently verified, scroll-anchor derived (128 frames/idx), and every type byte mapped to a
> behavior. §4d's distinct-type lists (v1: 0x17/0x1B/0x1D/0x1E/0x21/0x24/0x29; v2:
> 0x1A/0x1F/0x20/0x23/0x25/0x26/0x2B-2D) **supersede** the partial byte list in this paragraph.

> **hex vs decimal caution:** the probe logs the `+0x00` type in **decimal**. Galaxy's chevron is
> decimal `24` = **`0x18`**; the *hex* `0x24` (= decimal 36) is a different, variant-1 enemy (Curos).

---

## 4d. Asteroid & Nebula schedules + HP/boss (ROM extraction)

Extracted 2026-08-29 by an 8-agent disassembly+decode pass (z80dis) and independently
re-verified (192 waves diffed byte-for-byte across all three variants → **0 discrepancies**;
Galaxy re-matches the §4b oracle exactly). Tags: **ROM-EXACT** (bytes/opcodes read directly),
**MEASURED** (cycle-sim of ROM routines), **INFERRED** (best-fit onto the sim's coarser model or
unproven naming). Paste-ready Swift for this is in
[`asteroid-nebula-integration.md`](asteroid-nebula-integration.md). This section **supersedes**
the partial variant-1/variant-2 byte list at the end of §4c.

### Table geometry (ROM-EXACT)
- Root @ `0x3FA3` → three level-2 pointers: variant0 `0x3FA9` = **Galaxy**, variant1 `0x4029` =
  **Asteroid**, variant2 `0x40A9` = **Nebula**; chosen by `0xC240 mod 3`. Area labels align with
  boss-system stage counter `0xC25B` (0/1/2) — INFERRED (no ROM name strings; Nebiros/Belzebul
  are StrategyWiki names).
- Each variant = **exactly 64** level-2 word-pointers (idx 0..63): v0 `0x3FA9–0x4028`, v1
  `0x4029–0x40A8`, v2 `0x40A9–0x4128`; level-3 records begin `0x4129`. idx0-4 + idx63 point at the
  shared empty terminator `0x4129`; content runs idx5..62; idx62 = boss/finale; idx63 = boss-gate.
- **Banking correction:** the type handlers run in **bank 1 fixed in slot1** — `0xFFFF` is the
  *slot-2* register (standard Sega mapper), and there are **zero** `0xFFFE` writes ROM-wide, so
  slot1 is never switched and handler file-offset == CPU address. Dispatch (type→handler, all
  bank1): 15→4842, 16→48E4, 17→49AC, 18→4A5F, 19→4B7E, 1A→4C64, 1B→4D66, 1D→4DE5, 1E→4EA7,
  1F→4F41, 20→4FB5, 21→50C3, 23→51EB, 24→5302, 25→5428, 26→54B8, 29→574C, 2B/2C/2D→58B7/59AE/5AD5.

### Record fields (ROM-EXACT, reader @0x3F71–0x3F92)
The TYPE byte (+0x00) *is* the formation selector (jump table @0x0518). Then:
- **+0x13** = flight-path-script index for STREAM types (8-entry table @`0x4B6A` → path scripts
  `0xA0A8`…) / an on-entity countdown for LINE types.
- **+0x14** = absolute spawn-X (line) / member ordinal 1..N (stream).
- **+0x15** = per-member time stagger (stream; 8-frame steps) / unused (line).

### Scroll-anchor / timing (MEASURED slope, INFERRED offset)
`atScroll(idx) = 128*idx - 544` frames (sim `scrollSpeed = 1 tick/frame`).
- **MEASURED**: slope = **128 frames per wave-index**, exact, from cycle-sim of scroll routine
  `0x0D44` (accum `0xC214 += 0xFF80`/frame; `0xC211` bumps every 4 column-events = 128 frames =
  64 visual px/idx).
- **INFERRED**: the `-544` is a harness measurement-origin offset (matches the existing Galaxy
  cues); intrinsic is `128*idx` (0xC211 seeds to a checkpoint, not 0). Galaxy idx5 was empirically
  181 vs the formula's 96 → the FIRST content index may want a per-stage warm-up nudge (open Q).

### Asteroid (variant1) — ROM-EXACT type/count/X, INFERRED formation/name
| idx | romType | species | count | member X (record) | formation |
|----|---------|---------|-------|-------------------|-----------|
| 5-7 | 0x21 | tinker | 8 | 48,64,80,96,128,144,192,208 | dive spread |
| 8,10 | 0x1D | ashion | 7 | 32..224 @32px | line (exact) |
| 9,11 | 0x1D | ashion | 6 | 48..208 @32px | line (exact) |
| 12-15 | 0x24 | ufolick | 1 | edge nearest player | edge sweep |
| 16-19 | 0x1E | burdle | 4-6 | 80,112,144,176 (16) / scattered (17-19) | line (16 exact) |
| 20,22,32,34 | 0x17 | shamir | 7 | X=32..224; f14=Y-arch 1,32,48,56,48,32,1 | arc |
| 24-27,48-51 | 0x1B | aster | 6 | all X=128; f14=sweep dir 6/10 | center sweep |
| 28-31,52-55 | 0x21 | tinker | 8 | 48..208 | dive spread |
| 36,38,56,58,60 | 0x1D | ashion | 7 | 32..224 | line |
| 37,39,57,59 | 0x1D | ashion | 6 | 48..208 | line |
| 40,42 | 0x1E | burdle | 4 | 80,112,144,176 | line (exact) |
| 41,43 | 0x1E | burdle | 4 | 64,192,96,160 | line |
| 44-47 | 0x24 | ufolick | 1 | edge | edge sweep |
| 62 | 0x29 | **Nebiros boss** | 5 segments (f13=0..4) | — | BossSpec |

Distinct grunts: 0x17, 0x1B, 0x1D, 0x1E, 0x21, 0x24. (0x1C exists in the dispatch table @`0x4DD9`
but never appears in variant1 content.)

### Nebula (variant2) — ROM-EXACT type/count/X, INFERRED formation/name
| idx | romType | species | count | member X (record) | formation |
|----|---------|---------|-------|-------------------|-----------|
| 5,6 | 0x26 | tricker | 2 | 16,240 — screen EDGES | edge emplacements |
| 8-11,41,43,56-59 | 0x1A | arbleby | 4 | ~player (homing swoop) | swoop |
| 12,14 | 0x1F | **caborn (INDESTRUCTIBLE)** | 8 | 16,240,48,208,176,80,112,144 | scattered drift |
| 13,15 | 0x1F | caborn | 7 | 32,224,64,192,160,96,128 | scattered drift |
| 16-19,36-39 | 0x20 | dririt (splitter) | 3 | scattered | line (approx) |
| 20,31 | 0x25 | **triat (8-HP)** | 3 | 128,64,192 | line |
| 21-23,32-34,49,51,53,55 | 0x25 | triat | 5 | 80,176,32,128,224 | line |
| 24-27,44-47 | 0x23 | dilon (carrier) | 2 | symmetric pairs | symmetric |
| 28 | 0x1F | caborn | 6 | 48..208 | drift |
| 29,40,42,48,50,52,54 | mixed | tricker+caborn/arbleby/triat | — | split into 2 cues each |
| 62 | 0x2D + 0x2C×4 + 0x2B×4 | **Belzebul boss** | 9 pieces | — | BossSpec |

Distinct grunts: 0x1A, 0x1F, 0x20, 0x23, 0x25, 0x26.

### Species behavior (stats/hitbox ROM-EXACT, NAMES low confidence)
Reward index (+0x1B) → BCD score table @`0x5C60`: idx1=100, idx2=200, idx3=1000, idx4=5000.

| type | species | zone | HP | pts | fires | movement (handler) | r | name conf |
|------|---------|------|----|----|-------|--------------------|---|-----------|
| 0x17 | shamir | Ast | 1 | 200 | no | aimed dive/ram (`0x49AC`) | 8 | LOW |
| 0x1B | aster | Ast | 1 | 100 | no | center sweep (`0x4D66`) | 8 | LOW |
| 0x1D | ashion | Ast | ~2 | 100 | yes | descend + shot; survives ≥1 hit (`0x4DE5`) | 7 | LOW |
| 0x1E | burdle | Ast | 1 | 100 | yes | descend, turn, aimed shot (`0x4EA7`) | 7 | LOW |
| 0x21 | tinker | Ast | 1 | 100 | no | aimed random-accel dive (`0x50C3`) | 4 | LOW (anchor: smallest) |
| 0x24 | ufolick | Ast | 1 | 200 | yes | edge sweep + 6-shot burst (`0x5302`) | 8 | LOW |
| 0x1A | arbleby | Neb | 1 | 200 | yes | swoop-to-player + fire (`0x4C64`) | 10 | LOW (anchor: largest) |
| 0x1F | caborn | Neb | ∞ | 0 | no | INDESTRUCTIBLE drift (`0x4F41`) | 2 | LOW |
| 0x20 | dririt | Neb | 1 | 100 | no | self-splits into mirrored pair (`0x4FB5`) | 8 | LOW |
| 0x23 | dilon | Neb | 1 | 200 | no | carrier: births type-0x18 divers (`0x51EB`) | 6 | LOW |
| 0x25 | triat | Neb | **8** | 200 | yes | armored sweep + shot; `0xC610` one-shots (`0x5428`) | 6 | LOW |
| 0x26 | tricker | Neb | 1 | 100 | yes | edge rotating ring-fire (`0x54B8`) | 8 | LOW |

### HP verdicts (ROM-EXACT — closes the "heavy/boss-core HP" gap)
- **All grunts 1-HP** except `0x1D`/ashion (effective ~2, sprite-morph survive-a-hit, spawn-geometry
  gated) and `0x25`/triat (genuine **8-HP**: `LD (IX+0x28),8`, `JP z,0x5C1B` at 0; `0xC610`≠0
  heavy-weapon one-shots it). `0x1F`/caborn is **INDESTRUCTIBLE** (no hit-test/death path → model
  `indestructible: true`, 0 pts). The +0x1B "hp-looking" field is the reward index, not a hit
  counter (only one hit-set opcode ROM-wide: `SET 6,(IX+1) @0x1AD5`).

### Boss findings (ROM-EXACT structure, single-Int BossSpec insufficient)
Two boss systems: (1) **entity-segment finale @ idx62** into the shared `0xCA00` array — Nebiros =
`0x29 ×5` (`0x574C`), Belzebul = `0x2D` core + `0x2C ×4` + `0x2B ×4` (`0x5AD5`/`59AE`/`58B7`); each
segment is boss-scripted, not a 1-hit grunt. (2) **Scripted end-boss** — driver @`0x3B94`, anchor
type `0x2A` @slot `0xC9C0`, gated by `0xC24E` when `0xC211` reaches `0x41` (idx 65); its core (type
`0x27 @0x5577`) has a real 8-hit counter (`INC (IX+0x28)` → death @8, `0x56E8`), defeat flag
`0xC2C1`, reward idx4 (5000). Per-phase attack scripts behind `0xA858` (Ast) / `0xD030` (Neb) —
**not yet decoded**. `BossSpec.hp` (single Int) can't model this → boss-model TODO.

### scrollLength (derived) — replace the placeholder `2000`
Boss-spawn frame = `atScroll(idx62) = 128*62 - 544 = 7392` for both stages (last grunt idx60 @7136
Ast / idx59 @7008 Neb, so the boss fires after all grunts). Alternatives: intrinsic-from-zero
`7936`; idx63 gate `7520`; scripted-boss idx65 `7776`. Galaxy's own `907` should likewise extend to
its full idx5..62 schedule (~7392) for consistency (out of scope for the Asteroid/Nebula pass).

---

## 4e. Session 4 — parity yardstick, integration, and corrections

**The measurement backbone.** `swift run ParityScore` (in `AstroWarriorKit`) drives the real ROM and
the headless `GameSim.World` off **one shared open-loop tape** (captured from the ROM's `dodge` bot)
and scores them frame-for-frame: player-position error, live enemy population, spawn timeline, an
input-independent **cumulative-spawn** count (pure schedule fidelity), and a headline **DIVERGENCE**
composite (`meanPlayerErr + 6·mean|Δpop|`). `swift run ParityScore census [frames]` dumps the ROM's
real schedule keyed by wave-index (`0xC211`). Deterministic; re-run after any sim change.

**Result (Galaxy, 1500-frame tape): DIVERGENCE 30.5 → 9.2.** player error 13.5 → **0.8 px**;
sim-empty-while-ROM-populated 493 → **90** frames; cumulative spawns **ROM 36 / SIM 40** (the sim
emits the full idx5..14 schedule). The residual is now **combat / enemy-lifetime fidelity** (inferred
movement speeds + player-weapon effectiveness), **not** the schedule.

**Corrections & new facts (verified via z80dis + live census, adversarial workflow):**

- **Player entity XY IS the 16×16 sprite CENTRE** — VDP draw @`0x0416`, 2-piece frame list @`0x129A`,
  reg1=`0xA2` (8×16 sprites), SAT copied to VRAM with no bias. So ROM XY already matches the sim's
  centre convention: **there is NO coordinate/sprite-origin offset.** (This killed a "sprite-corner"
  hypothesis.) §5's "sprite centre" note is confirmed.
- **Harness artifact (the real cause of the old ~13.5 px offset):** for ~9 frames after the 300/5/8
  boot, the player position words @`0xC608/0xC60A` read `(0,0)` (type byte is already 1, XY not yet
  populated). A dodge bot reading `(0,0)` presses phantom down+right → poisons a recorded tape; the
  sim (live from frame 0) obeys it → a constant offset. **Fix:** spin until `word(0xC60A) ≥ 1` before
  recording/censusing. Drops player error to ~0.8 px.
- **Handlers located:** `0x22` → **`0x5150`** (dives to the player row `0xC609` then homes on `0xC60B`);
  `0x27` → **`0x5577`** (accelerating aimed diver; NOT the end-boss core — that is `0x28` @`0x5624`
  with the real 8-hit `+0x28` counter). Both single-hit death (`CALL 0x5be3` / `JP nz,0x5c1b`).
- **Loop-gated fire:** every Galaxy grunt's aimed shot (bullet type `0x14` @`0x18EE`, aimed, ~1.9 px/f)
  is gated behind `0xC240 ≥ 3` (via `0x5bf2`/`0x5c06`) → **silent on the first (stage-1) loop**, so
  faithful stage-1 = `NoAttack`. **EXCEPTION: `0x19` fires UNGATED on loop 1** (the `0xC240` check only
  tightens its cadence on loops ≥ 3).
- **Hitboxes** from table `0x1B1C + (IX+3)*4` = `[Yoff,H,Xoff,W]`: `0x15`=16×16(r8), `0x16`=14×14(r7),
  `0x18`=8×8(r4), `0x19`=20×20(r10), `0x22`=16×16(r8), `0x27`=12×12(r6).
- **Galaxy full idx5..60 schedule** decoded (variant0) and census-crosschecked (PASSED). Clean
  `atScroll = 128*idx − 546` (idx ≥ 7), idx5 = 179 (+85 warm-up). Now wired into
  `DefaultContent.galaxy()` (scrollLength 7390). Species: `0x15` cult, `0x16` zanix (the "X" turret),
  `0x18` sharlin (centre streams), `0x19` delta, `0x22` kyra, `0x27` gyron; boss `0x28` ×5 @ idx62.
  Empty rests: idx6,15,33,35,61.

---

## 5. Coordinate systems

- **ROM:** origin top-left, **+Y down**, 256×192.
- **Our sim (`GameSim`):** origin bottom, **+Y up**, logical 256×192.
- Convert: `screen_y = LOGICAL_HEIGHT − sim_y`. X is identical. The ship position in RAM
  is the sprite **centre** (128 = screen centre).

---

## 6. Emulator gotchas (vendored SMS Plus core)

- **Input requires `sms.device[0]/[1] = DEVICE_PAD2B`** (set in `CSMSCore/shim.c`). Without
  it the core ignores `input.pad` entirely — port `0xDC` reads `0xFF` and the game never
  starts. This had silently broken the debugger's ROM input.
- The core is a **singleton** (global `sms`/`cart`/`bitmap`) — `system_init` once per
  process, power-on per load, never tear down. Its tests run `@Suite(.serialized)`.
- Framebuffer is RGB 5:6:5 → converted to RGBA8888 for display.
- **The core is GPL-2 and DEV-ONLY** — it must never ship in the app; a Swift-native
  emulator is planned to replace it behind the `ReferenceCore` protocol.

---

## 7. To reproduce

```
cd AstroWarriorKit
swift run ParityProbe          # headless measurement harness (edit main.swift per experiment)
swift test                     # includes the emulator boot + determinism tests
```
Or run the app (macOS scheme) → **Parity Debugger** tab → the System Monitor shows the ROM
and sim state side by side, live.
