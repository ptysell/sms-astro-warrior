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

### Other useful addresses
| Address | Meaning |
|---|---|
| `0xC6C0` | first player-bullet slot (type `2`) |
| `0xC286` | a per-frame countdown timer (NOT a frame counter — the RE doc's `0xC01C` is wrong) |

### Entity pool
40 slots, base `0xC600`, stride `0x40`. Struct: `+0x00` type (0 = inactive),
`+0x08` Y (8.8), `+0x0A` X (8.8). Same layout for every entity.

---

## 2. Entity type catalog

Classified by **motion signature** (unambiguous and wave-proof — type *values* differ per
wave, so a fixed enemy list won't do):

| Type(s) | Category | Signature |
|---|---|---|
| `1` | **player** | input-driven |
| `2` | **player bullet** | moves up ~12 px/f |
| `18` | **power-up pickup** | drops straight down the **centre** (avgX ≈ 128) |
| `11`, `12`, `19` | **fx / HUD** | static / fixed-position |
| `20`, `21`, `22`, `24`, `25`, `39`, … | **enemy species** | descend ~1–1.7 px/f, weave (one type value per species) |

Notes:
- **Enemy bullets are rare** in early Galaxy — most on-screen "red dots" are the dense
  starfield, not projectiles. They currently fold into the enemy count.
- **Power-up blocks** are *background name-table tiles* (VRAM `0x3800`), **not** pool
  entities — they don't appear in the entity table.
- Enemy **species names** (Cult, Curos, Sharlin, …) and per-type **HP / points** are not
  yet mapped.

---

## 3. Measured tuning values (in `GameSim/Tuning.swift`)

| Constant | Value | How measured |
|---|---|---|
| `shipSpeed` | **1.5 px/frame, total (normalized)** — diagonal ≈ 1.06/axis (1.5/√2) | parity bot; tracks ROM to ±1 frame |
| `shipStartScreenY` | **144** (→ start Y = 48 in our +Y-up space) | RAM read at stage start |
| `shipBulletSpeed` | **12 px/frame** (upward) | tracked the bullet entity's Y |
| `shipFireInterval` | **~8 frames** between shots | counted bullet spawns |
| movement bounds | **X ∈ [18, 242]**, screen-Y ∈ **[0, 182]** (our y ∈ [10, 192]) | pushed the ship into each wall |

Still `[extract]`: scroll rate, per-enemy hp/points/hitboxes, boss scripts, power-up ladder.

---

## 4. Coordinate systems

- **ROM:** origin top-left, **+Y down**, 256×192.
- **Our sim (`GameSim`):** origin bottom, **+Y up**, logical 256×192.
- Convert: `screen_y = LOGICAL_HEIGHT − sim_y`. X is identical. The ship position in RAM
  is the sprite **centre** (128 = screen centre).

---

## 5. Emulator gotchas (vendored SMS Plus core)

- **Input requires `sms.device[0]/[1] = DEVICE_PAD2B`** (set in `CSMSCore/shim.c`). Without
  it the core ignores `input.pad` entirely — port `0xDC` reads `0xFF` and the game never
  starts. This had silently broken the debugger's ROM input.
- The core is a **singleton** (global `sms`/`cart`/`bitmap`) — `system_init` once per
  process, power-on per load, never tear down. Its tests run `@Suite(.serialized)`.
- Framebuffer is RGB 5:6:5 → converted to RGBA8888 for display.
- **The core is GPL-2 and DEV-ONLY** — it must never ship in the app; a Swift-native
  emulator is planned to replace it behind the `ReferenceCore` protocol.

---

## 6. To reproduce

```
cd AstroWarriorKit
swift run ParityProbe          # headless measurement harness (edit main.swift per experiment)
swift test                     # includes the emulator boot + determinism tests
```
Or run the app (macOS scheme) → **Parity Debugger** tab → the System Monitor shows the ROM
and sim state side by side, live.
