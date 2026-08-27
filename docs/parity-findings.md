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

Score stored as BCD at `0xC031` (the hundreds-place byte; `0xC030` appears unused or at
a different address). `0xC233` mirrors the same value (display shadow).

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

## 4b. Galaxy stage layout — full wave schedule (MEASURED)

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

> **hex vs decimal caution:** the probe logs the `+0x00` type in **decimal**. Galaxy's chevron is
> decimal `24` = **`0x18`**; the *hex* `0x24` (= decimal 36) is a different, variant-1 enemy (Curos).

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
