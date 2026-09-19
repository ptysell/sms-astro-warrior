# Astro Warrior — Endgame Sprint Plan (max-agent convergence to 1:1)

**Purpose.** The from-scratch orchestration is in
[`astro-warrior-worksweep-plan.md`](astro-warrior-worksweep-plan.md); the spec is
[`astro-warrior-build-and-reference.md`](astro-warrior-build-and-reference.md); the measured
ground truth is [`parity-findings.md`](parity-findings.md). Those got us a ROM-exact **content**
layer and a playable slice. **This document is the sprint to the finish line: a full-coverage
plan that names every remaining aspect of the game — backgrounds, tiles, sprites, palettes,
enemies & groups, stage lengths, opening/attract/clear/game-over screens, music/SFX, bosses,
power-ups, the loop — and lays them out as the widest safe fan-out of agents to reach a
faithful 1:1 recreation.**

Written 2026-09-18 from two adversarial code+ROM sweeps. It supersedes the old plan's Wave-3/4
sections (we are past Wave 0–2).

> ### Progress log
> - **Wave 0 — DONE (PR #13).** Boss is killable → zones transition (`Collision` AABB, boss in the
>   collision set, game-over→restart). Reference-core taps added: `readVRAM/readCRAM/satBase/readSAT`,
>   `writeRAM` (stage-warp), `psgCaptureReset/psgDrain` — additive, determinism preserved, verified live.
> - **Wave 1a — DONE (research).** Static-disassembly decode of 7 subsystems, all adversarially
>   **CONFIRMED** → [`rom-decode-systems.md`](rom-decode-systems.md). Big movers on the §2 map:
>   enemy **velocities/motion** now ROM-EXACT (integrator `0x0416`, aim table `0x19C0`, flight LUT
>   `0xA000`/bank6); flight-path engine (`0x4B6A`, 10 scripts); **boss driver** `0x3B94` decoded and the
>   `0xA858/0xD030` "phase-script" premise **refuted** (they're 16-bit values at `0xC2E2`, not pointers);
>   **audio driver** fully mapped (`0x34CA`/`0x362B`/`0x395E`/`0x3556`); **power-up block counter FOUND**
>   (`0xC228`, wrap-12 → `0xC615`) + ladder index `0xC229`/tables `0x0C98`/`0x0CA8`; species renderer
>   traced (but **no name strings in ROM** → names stay community-sourced/low-confidence). Flow
>   corrections: **the game loops forever (no ending screen)**; `sub_2309` is a palette pulse, not
>   progression; per-loop difficulty is **fire-gating + roster only, no speed scaling**; and `0x22` is
>   **200 pts** (corrects `parity-findings.md §4a`).
> - **Next:** Wave 1b (visual VRAM/CRAM/tile/palette/sprite extraction on the new taps) → Wave 2
>   (pour the decode into `GameSim`, starting with the velocity model — the residual-parity lever).

---

## 0. What "1:1 faithful" means here — the acceptance definition

A faithful recreation must match the original on **four independent axes**. The whole plan is
organized so each axis has a *measurable* gate, not a vibe check.

| Axis | It must… | Ground-truth oracle | Gate (Definition of Done) |
|---|---|---|---|
| **PLAYS** | move, spawn, collide, score, die identically | `ParityScore` DIVERGENCE off a shared input tape | ≤ **2.0** for **all 3 zones + all 3 bosses**; cumulative-spawn exact; player-pos err ≤ 1 px |
| **LOOKS** | same pixels: sprites, tiles, backgrounds, palette, HUD | ROM framebuffer PNG + VRAM/CRAM dump | per-representative-frame pixel-diff within tolerance; **CRAM exact**; every tile/sprite matches its rip |
| **SOUNDS** | same music & SFX | captured SN76489 `OUT (0x7F)` register stream | per-track register/timing match (or spectrogram match) for every track + SFX |
| **FLOWS** | same screens & progression | ROM playthrough capture | every screen present & sequenced identically; loop difficulty ramp matches |

> **Provenance rule (default, flagged for confirmation in §9):** ROM rips are the *measurement
> reference*, never shipped bytes. Shipped art/audio are **recreations drawn/synthesized to match**
> the rip (the README's "recreated sprite atlas"). The GPL emulator core stays dev-only.

---

## 1. Honest baseline — where we are (one screen)

**Green:** the content data river is done and trustworthy. **Red:** the mechanics that consume
it, and the entire audiovisual + flow layer, are stubs.

- ✅ **ROM-EXACT & wired:** all 192 waves across 3 variants; per-species HP/points/hitbox/fire-gating;
  ship kinematics (±1 frame); scroll cadence; stage lengths (7390/7392, offset provisional); scoring;
  dispatch/handler map; banking.
- ◑ **Structure known, model insufficient:** bosses (single-`Int` `BossSpec` can't hold multi-segment
  fortress/core); formations (`.line/.vee/.arc/.stream` too coarse for scattered/edge X).
- ☐ **Stubbed mechanics:** `TripleShot`/`LaserBeam` empty; power-up ladder inert; drones never spawn;
  loop scaling + loop-gated fire unimplemented; enemy motion approximate (no convergence/curve/swoop/
  split/carrier).
- ☐ **Absent presentation/flow:** all art is tinted vector shapes; no background/starfield/tilemap;
  no audio; no title/attract/intro/zone-clear/game-over-restart/name-entry screens.

> ### 🔴 The one blocker that gates everything downstream
> **The boss cannot be damaged.** `CollisionSystem.resolve` iterates only `Enemy` (a `Boss` is an
> `Entity`, not an `Enemy`), and circle/AABB overlap is unimplemented (only circle/circle). So
> `bossDefeated` never flips → `LevelDirector` is stuck in `.boss` forever → **no zone ever
> transitions in real play.** Until this is fixed, Asteroid/Nebula can't even be *reached* by a
> player, and their parity can't be measured with a normal tape. **Fix first (B1+B2), in Wave 0.**

---

## 2. The complete coverage map — every aspect, nothing missed

This is the "make sure we understand all aspects" deliverable. Each row: current **RE** (decoded?),
**SIM** (modeled?), **RENDER/AUDIO** (shown/heard?), and the **lead** to close it. Addresses cite
`parity-findings.md` (PF) / `astro-warrior-build-and-reference.md` (BR).

### 2A. Boot & meta-flow (the screens a player sees before/after gameplay)
| Aspect | RE | SIM | Shown | Lead to close |
|---|---|---|---|---|
| SEGA logo / boot | ☐ | ☐ | ☐ | logo in **bank 5**; boot `Reset→JP 0x1D40` (BR App D) |
| Title screen | ☐ | `.title` mode exists, no content | static ship on black | trace title tilemap/name-table build after `0x1D40` |
| Attract / demo playback | ☐ | ☐ | ☐ | attract sets `0xC020` during boot (PF §1); find the demo input source |
| High-score table display | ◑ (hi buffer `0xC030`) | hi tracked | HUD only | draw routine unlocated |
| Name / initials entry | ☐ | ☐ | ☐ | untouched |
| Ending / credits (after 3rd Belzebul) | ☐ | ☐ | ☐ | `sub_2309` wraps `0xC238` at `CP 6` (BR App A) |

### 2B. Per-stage flow
| Aspect | RE | SIM | Shown | Lead |
|---|---|---|---|---|
| Stage-intro banner | ☐ | ☐ | ☐ | untouched |
| Zone-clear / intermission | ☐ | `.cleared` calls `advance` but unreachable | ☐ | untouched |
| Game-over → restart | ☐ | dead end (`updateMenus` only `title→playing`) | ☐ | wire restart + score screen |
| Stage length / boss trigger | ✅ `0xC020` init 1080; boss at `==0`; scrollLength ~7392 | ✅ wired | n/a | done (offset provisional, §2G) |
| Zone→boss→loop progression | ◑ `0xC238`/`0xC25B`; wrap at 6 | loop wraps, **no difficulty scale** | n/a | trace state machine `sub_2309` |
| Loop difficulty ramp | ◑ fire gated `0xC240≥3`; `0x19` ungated loop 1 | ☐ never armed | n/a | implement loop→fire-arm + velocity scale |

### 2C. Backgrounds & tiles
| Aspect | RE | SIM | Shown | Lead |
|---|---|---|---|---|
| Scrolling starfield | ☐ | `scrollY` in Snapshot, **ignored** | ☐ | decode starfield generator |
| Per-zone name-table layer (galaxy/asteroid/nebula) | ☐ | `background` cosmetic ref | ☐ | tile drawer `sub_2534` → name table VRAM `0x3800` |
| Parallax / multi-layer | ☐ | ☐ | ☐ | VDP reg 9 scroll + name-table split |
| Power-up "blocks" in field | ◑ are name-table tiles, counts known (Gx159/As131/Ne116) | ☐ not modeled | ☐ | dump `0x3800` layout across scroll |
| Per-zone VRAM tile sets | ☐ | n/a | ☐ | **needs VRAM tap (H1)** then per-zone rip |
| Fortress / boss tilemaps | ☐ | ☐ | ☐ | Zanoni teal fortress (PF §4b) |
| HUD font tiles | ☐ | SwiftUI text stand-in | ☐ | rip digit/label tiles |

### 2D. Palettes (CRAM)
| Aspect | RE | Lead |
|---|---|---|
| Gameplay **sprite** palette | ✅ `0x1131` (verified vs Curos rip) | done |
| Background palette (CRAM 0–15) | ☐ | **needs CRAM tap (H1)**; 32-entry table `0x1121` |
| Per-zone palette swaps | ☐ | capture CRAM at each zone via stage-warp (H2) |
| Flash/animation (hit, boss) | ☐ | log CRAM writes per frame |

### 2E. Sprites (pixel art) & animation
| Aspect | RE | Lead |
|---|---|---|
| Standard 16×16 enemy metasprites | ◑ some ripped (`assets/gfx/sprites/`) | full pass per species (BR App C) |
| Player ship + 3 forms | ☐ | tiles ~`0x12A00`, form flag `0xC264` pages `0xAA00`/`0xB100` |
| Drones / options / pickups / bullets / explosions | ☐ | per-type draw-path decode |
| Bosses (fortress + core + turrets, all segments) | ☐ | per-handler tile base + frame tables |
| Animation frames | ☐ | anim counter `0xC229` → frame tables `0x0C98`/`0x0CA8` |
| **Species-name confirmation** | ◑ only tinker (smallest r4) + arbleby (largest r10) anchored; 10/12 inferred | bank-4 decode + screen cross-ref (biggest labeled gap) |

### 2F. Enemies & enemy groups
| Aspect | RE | SIM | Lead |
|---|---|---|---|
| Per-species HP/points/hitbox | ✅ ROM-EXACT | ✅ wired | done |
| Movement handlers (per type) | ◑ handler addrs known (49AC…5AD5) | approx (4 primitives) | convert **slot-2 velocity vector tables** |
| Flight-path scripts (stream) | ◑ 8-entry table `0x4B6A` → scripts `0xA0A8…` | ☐ | decode path scripts |
| Motion refinements | ◑ documented | ☐ TODO | Cult convergence; Sharlin down-right curve; kyra 2-phase homing; arbleby swoop |
| New primitives | ◑ handlers known | ☐ inert | dilon **carrier** (`0x51EB` births 0x18 divers); dririt **self-split** (`0x4FB5`) |
| Enemy bullets | ◑ type `0x14` @`0x18EE`, aimed ~1.9 px/f, loop-gated | ☐ `NoAttack` stage 1 | wire loop-gated fire |
| Formation model | ◑ X-lists captured in cues | `.line` exact only for 32px rows | add **explicit per-member-X** formation |
| Wave schedules / groups | ✅ all 192 waves | ✅ wired | done |

### 2G. Player, weapons, power-ups
| Aspect | RE | SIM | Lead |
|---|---|---|---|
| Ship kinematics / bounds / fire cadence | ✅ MEASURED | ✅ | done |
| Weapon forms | ☐ effects unmeasured | Single ✅; **Triple/Laser empty stubs** | decode handler `0x0807`; measure spread/pierce |
| Power-up ladder (12/36/60/84/108/120) | ◑ thresholds from manual, **not in RAM** | **inert** (`apply` empty; counter never inc; pickup never spawned) | RAM scan for block counter; measure effect per rung |
| Drones / options | ◑ `0xC6C0` ×6 sub-pool | never created, `fire()` empty | decode offsets + fire-sync |
| Heavy-weapon one-shot flag | ◑ `0xC610` (one-shots triat) | ☐ | trace which weapon sets it |

### 2H. Bosses
| Aspect | RE | SIM | Lead |
|---|---|---|---|
| Segment finale @idx62 | ✅ Galaxy `0x28×5`; Nebiros `0x29×5`; Belzebul `0x2D`+`0x2C×4`+`0x2B×4` | placeholder `BossHover` | multi-part model |
| Scripted end-boss | ◑ driver `0x3B94`, anchor `0x2A`@`0xC9C0`, core `0x28`@`0x5624`, **real 8-hit** `+0x28`→`0x56E8`, flag `0xC2C1` | ☐ | implement core hit-counter |
| **Per-phase attack scripts** | ☐ behind `0xA858` (Ast) / `0xD030` (Neb); Zanoni's uncited | ☐ | **decode — key open item** |
| Fortress tilemap + turret script | ☐ | ☐ | tie to 2C/2E |
| Boss HP | placeholder 80/70/80 | placeholder | from segment/core counters |

### 2I. Audio
| Aspect | RE | Impl | Lead |
|---|---|---|---|
| PSG interface | ✅ SN76489, `OUT (0x7F)` ×11 sites | ☐ `AudioEngine` empty | **needs capture tap (H4)** |
| Music driver + pattern tables | ☐ | ☐ | locate driver; per-track tables in data banks |
| Per-track data (title/3 stages/boss/gameover/ending) | ☐ | ☐ | capture register stream per screen via stage-warp |
| SFX (fire/explosion/pickup/etc.) | ☐ | ☐ | isolate on event |

### 2J. Cross-cutting
| Aspect | RE | Note |
|---|---|---|
| Extra-life threshold (50k) | ◑ manual; logic wired | confirm in RAM |
| RNG / determinism | ☐ | tinker "random-accel dive" — is behavior RNG-driven? decides parity-metric tolerance |
| Region (NTSC/PAL, 60/50 Hz) | ☐ | confirm; affects music tempo & sim Hz |
| `atScroll` offset −544/−546 | ◑ harness artifact; per-stage warm-up | resolve true `0xC211` stage-start seed |

---

## 3. Tooling first — grow the measurement backbone (Wave 0, the gate)

Everything downstream is measured against the ROM; several rivers can't even *start* until these
taps exist. Keep Wave 0 small and fast — it blocks the fan-out.

| # | Harness item | Unlocks | Notes |
|---|---|---|---|
| **H1** | `sms_core_vram/cram/sat` shims → `ReferenceCore.readVRAM/CRAM/SAT` | all of River V (tiles, palettes, name-tables) | globals already exist in the core; ~30 lines |
| **H2** | **Stage-warp harness** — force `0xC240`/`0xC211`/`0xC25B` to boot into any zone/wave/boss | Asteroid/Nebula/boss **parity + audio + palette** measurement | today the dodge bot dies ~idx21 and never leaves Galaxy |
| **H3** | Pixel-diff + CRAM-exact metric in `ParityScore` | the LOOKS gate | framebuffer PNG already works; add per-frame SSIM/exact + CRAM compare |
| **H4** | PSG capture tap — log every `OUT (0x7F)` write with frame stamp | all of River A | ground-truth track/SFX stream + diff metric |
| **H5** | Better survival bot + per-zone scripted tapes | full-stage tapes for River Q | current bot dies early |
| **H6** | Vendor **z80dis** into `tools/` + `make dump` (RAM/VRAM/CRAM/SAT/frame at labeled checkpoints) | reproducibility | z80dis is the disassembler of record but isn't in the repo |
| **H7** | Golden-replay + tuning-regression test target | stops regressions during the fan-out | the long-owed `I4` |

---

## 4. The four rivers (+ the gate & the QA spine)

```
   ┌─ River B  BLOCKERS & mechanics closeout  (unblocks transitions + measurement)
   ├─ River G  Gameplay fidelity              (motion/weapon/boss calibration + new primitives)
Wave 0  ├─ River V  Visual extraction → render     (tiles/palettes/backgrounds/sprites/HUD)
(H1/H2/ ├─ River S  Screens & flow                 (title/attract/intro/clear/gameover/name/loop)
 H4 gate)├─ River A  Audio extraction → synthesis    (driver/tracks/SFX → PSG synth)
   └─ River Q  Parity/QA gates                 (extend ParityScore, golden replays, A/B)
```

Dependency reality: **B1/B2 (boss damage) + H2 (stage-warp)** gate measuring/rendering anything
past Galaxy stage 1. **H1** gates tile/palette extraction. Each extraction package gates its
implementation counterpart. Everything else is parallel.

---

## 5. Wave-by-wave agent orchestration (the max-agent roster)

Rules (unchanged from the worksweep plan, they held): **disjoint file/data ownership** (no two
agents write one file), **worktree isolation per agent**, **one PR per package, merged at the wave
barrier**. Peak concurrency throttled to ~16 (the runner cap); total distinct sessions 40–60.

### Wave 0 — gate (small, fast, mostly serial) — ~5 agents
`W0-H1` VRAM/CRAM/SAT taps · `W0-H2` stage-warp harness · `W0-B1` collision AABB/grid broad-phase
(`Collision.swift`) · `W0-B2` boss-damage wiring + `LevelDirector` transitions + game-over→restart
· `W0-H4` PSG capture tap. **Exit:** boss is killable, a zone transitions, Ast/Neb are warp-reachable,
VRAM/CRAM/PSG are dumpable. Then fan out.

### Wave 1 — maximum fan-out — ~16–22 concurrent
**Mechanics closeout (own `GameSim/…`):**
`S-pow` power-up ladder + block model + pickup spawn · `S-wpn` TripleShot/LaserBeam + drones ·
`S-loop` loop difficulty scale + loop-gated fire arming · `S-fmt` explicit-per-member-X formation.

**Extraction — pure research, ROM+z80dis (tile/palette need H1):**
`Vx-tiles×3` per-zone VRAM tile sets · `Vx-pal×3` per-zone CRAM palettes · `Vx-bg×3` name-table
layers + starfield · `Vx-spr` sprite decode (player+forms / each species / pickups+bullets+explosions
/ each boss — split per group to push count) · `Vx-hud` HUD font+layout ·
`Sx-title` title+SEGA logo · `Sx-attract` attract/demo · `Sx-screens` intro/clear/gameover/name/ending
· `Ax-driver` music driver + track tables · `Ax-sfx` SFX table ·
`Gx-vel` slot-2 velocity vector tables · `Gx-path` flight-path scripts `0x4B6A→0xA0A8` ·
`Gx-boss` boss phase scripts `0xA858`/`0xD030` + core counter · `Gx-name` species-name confirmation
· `Gx-pow` power-up counter RAM scan + effect measurement.

### Wave 2 — implementation fan-out (each gated on its extraction) — ~16
`V-atlas` `SKTextureAtlas` + recreated sprites · `V-pal` per-zone palette pipeline ·
`V-bg` scrolling background/starfield renderer (consume `scrollY`/`background`) · `V-hud` HUD art ·
`V-anim` sprite animation · `G-motion` motion primitives (convergence/curve/swoop/split/carrier) ·
`G-vel` apply measured velocities · `B-boss×3` Zanoni/Nebiros/Belzebul multi-part models + phase
machines · `S-flow` all screens wired into the mode machine · `A-synth` SN76489 synth in
`GameAudio` · `A-tracks` per-track playback + SFX events.

### Wave 3 — integration + the parity gate — ~6
`Q-score` extend `ParityScore`: all-3-zone + all-3-boss DIVERGENCE via stage-warp; pixel-diff;
audio-diff · `Q-golden` golden replays + regression asserts · `Q-ab` frame-perfect A/B capture per
screen/zone · `C-calib` the calibration loop (tighten motion/weapon/boss until DoD thresholds met)
· `C-region` NTSC/PAL + tempo reconciliation · `C-prov` swap rips→recreations, strip GPL core check.

**Exit = §0 Definition of Done on all four axes.**

---

## 6. Critical path & kickoff order

Irreducible spine (everything else hangs off it):

```
W0: H1 (VRAM/CRAM) + H2 (stage-warp) + H4 (PSG tap) + B1/B2 (boss killable → zones transition)
      ↓
Extraction rivers (V/S/A/G) run wide, pure-research, minute-zero
      ↓
Implementation rivers pour each extraction into Swift (per-item gated)
      ↓
Q parity gate: converge DIVERGENCE (all zones+bosses) + pixel-diff + audio-diff to DoD
```

**Launch now, simultaneously:** the 5 Wave-0 agents **and** the pure-research extraction that needs
only ROM+z80dis (`Sx-*`, `Ax-driver`, `Gx-vel/path/boss/name/pow`, `Vx-spr`). Tile/palette
extraction (`Vx-tiles/pal/bg`) waits on H1 (hours, not days). The riskiest work is the **calibration
loop** (C-calib) and the **boss phase-script decode** (`Gx-boss`) — front-load both.

---

## 7. Definition of Done — the finish line (repeat of §0, as a checklist)

- [ ] **PLAYS:** `ParityScore` DIVERGENCE ≤ 2.0 for Galaxy **and** Asteroid **and** Nebula, plus each
      boss fight, off shared tapes; cumulative-spawn exact; player-pos err ≤ 1 px.
- [ ] **LOOKS:** every zone background, all sprites/tiles, HUD, and each screen pixel-match the ROM
      within tolerance; **CRAM exact** per zone; power-up blocks placed correctly in the field.
- [ ] **SOUNDS:** every music track + SFX matches the captured PSG stream.
- [ ] **FLOWS:** SEGA logo → title → attract/demo → 3 stages (correct lengths) → 3 bosses →
      zone-clear/intermission → loop with correct difficulty ramp → game-over → name entry → ending.
- [ ] Ships without the GPL core; golden-replay regression suite green.

---

## 8. Risks, unknowns & decisions needed

- **⚠️ Asset provenance (needs a call):** ship pixel-identical **rips** vs **recreations drawn to
  match**? Default here = recreate-to-match (rips are reference only), matching the README. Rips are
  ©SEGA. Confirm before River V implementation ships anything.
- **RNG determinism:** if any enemy behavior (tinker random-accel dive) is RNG-driven, exact
  frame-parity may be impossible → the PLAYS gate needs either RNG seeding parity or a statistical
  tolerance band. Resolve early in `Gx-vel`.
- **Region:** confirm NTSC (60 Hz) vs PAL (50 Hz) — sim is 60 Hz; wrong region skews music tempo and
  scroll timing.
- **`atScroll` offset (−544/−546):** provisional harness origin; resolve the true `0xC211`
  stage-start seed so idx anchoring is intrinsic, not fitted.
- **Boss model:** `BossSpec` (single `Int`) must become a multi-segment/phased model — a small
  contract change (touch the frozen types), so do it deliberately, once, in `B-boss`.
- **z80dis not versioned** (H6) and the **GPL emulator can't ship** (Swift-native `ReferenceCore`
  eventually — not blocking 1:1).

---

## 9. How to run it (execution options)

- **Manual fan-out (recommended, matches current workflow):** spawn each package as an agent with
  `isolation: "worktree"`, one PR per package, merge at each wave barrier. This is exactly how #1–#11
  landed.
- **`Workflow` tool (automated orchestration):** opt-in + billed; the size guideline caps a single
  workflow at <10 agents, so batch by river (one workflow per wave/river) rather than one 40-agent
  run. Use for the mechanical fan-out (extraction, impl); keep the calibration loop human-in-the-loop.
- Either way the yardstick is `swift run ParityScore` (extended per H3/Q-score) — re-run after every
  package; nothing merges that regresses DIVERGENCE or a golden replay.
