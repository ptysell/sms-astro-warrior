# Astro Warrior — Worksweep Plan (Maximum Sessions / Agents)

**Purpose.** Decompose the build in [`astro-warrior-build-and-reference.md`](astro-warrior-build-and-reference.md)
into the largest set of **independent work packages** that can run as concurrent
sessions/agents, while respecting the one hard dependency the architecture imposes.
This is the orchestration plan; the blueprint is the spec.

---

## 1. The one fact that governs all parallelism

The blueprint's architecture (§4, §12) has a single dependency direction:

```
GameSim  ──(depends on nothing)
   ▲
   └── GameRenderSpriteKit / GameAudio / GameInput / GameUI / App  (all depend ONLY on GameSim)
```

Everything keys off a small set of **shared contracts**: `Entity`, `Hitbox`,
`SpriteRef`, `SimContext`, `Snapshot`, `Intent`, `Tuning`, `RNG`, `SIM_DT`.
Once those types exist and their signatures are **frozen**, every other module can
be built blind to the others — they only see the contract, never each other.

So the worksweep is: **one short serial bottleneck to freeze the contracts, then a
very wide fan-out, then integration.** Plus two tracks (ROM data-extraction and art)
that are pure research/asset work and run **fully parallel from minute zero** because
they produce *data*, not code that links against anything.

There are effectively **four independent rivers** of work:

| River | Depends on | Can start |
|---|---|---|
| **Code** (Swift modules) | frozen contracts | after Wave 0 |
| **Data extraction** (the `[extract]` values, §16) | the ROM + emulator only | immediately |
| **Art** (recreated sprite atlas, App. B) | reference rips only | immediately |
| **Test harness** (Swift Testing, replay, parity) | contracts + a runnable `World` | trickles in, peaks late |

Data, Art, and Test-harness scaffolding need **zero** code to start, so they should
be launched on day one regardless of where the code track is.

---

## 2. Critical path (the irreducible serial spine)

Maximum agents ≠ everything parallel. This chain must be serial; everything else
hangs off it:

```
Wave 0 contracts  →  World.step integration  →  M1 feel-tune (sim vs emulator)  →  parity gate
```

- **Wave 0** is the bottleneck — keep it to **one agent, small, fast**. Every hour it
  runs, the fan-out waits.
- **Feel-tuning (M1)** can't be parallelized away: it's a human/measurement loop
  (§11) that needs the *real* extracted numbers and side-by-side play. Front-load the
  data-extraction river so the numbers are waiting when the sim is runnable.

Everything below maximizes width *around* this spine.

---

## 3. Wave 0 — Freeze the contracts (1 agent, blocking)

**Goal:** the smallest compilable `GameSim` target that defines every shared type as
a stub/signature, so 20+ agents can import it without colliding.

**Single agent, single session.** Deliverables (all in `Sources/GameSim/`):

- `Package.swift` + full module skeleton from §12 (empty targets that compile).
- `Geometry.swift` — `SIMD2<Double>` helpers, units.
- `Entity.swift` — `Entity`, `Damageable`, `Faction`, `Side`, `Hitbox` (§5.3).
- `SimContext` + `World` *facade* (method signatures only: `spawn`, `addScore`,
  `spawnBoss`, `bossDefeated`, `campaign`, `rng`) — no bodies yet.
- `Snapshot.swift` (§5.13), `Intent` (§7), `RNG.swift` (§5.11), `SIM_HZ`/`SIM_DT`.
- `Tuning.swift` — every constant declared with placeholder values + `// [extract]`.
- `SpriteRef` enum stub (one case per roster entry, §2).

**Exit criterion:** `swift build` green; the signatures of `Snapshot`, `Intent`,
`Entity`, `SimContext`, and `World`'s spawn/score API are **declared frozen** (changes
after this require a coordinated re-sync, see §8).

---

## 4. Wave 1 — Maximum fan-out (the wide part)

All of the following run **concurrently** the moment Wave 0 is frozen. Each owns a
disjoint set of files (no two agents write the same file), so there are no merge
collisions by construction. Target: **~16–22 concurrent agents.**

### 4A. GameSim internals (own `Sources/GameSim/...`)

| # | Agent | Files owned | Notes |
|---|---|---|---|
| S1 | Movement behaviors | `Behaviors/Movement.swift` | `Descend`, `Weave`, `Dive`, `FormationHold` (§5.4) |
| S2 | Attack behaviors | `Behaviors/Attack.swift` | `NoAttack`, `AimedShot`, `RingFire` (§5.4) |
| S3 | Weapons | `Weapons/*.swift` | `SingleShot`, `TripleShot`, `LaserBeam` (§5.7) |
| S4 | Bullet + PowerUp + Drone | `Bullet.swift` `PowerUp.swift` `Drone.swift` | leaf entities (§5.3, §5.7) |
| S5 | Player + power-up ladder | `Player.swift` `PowerUpLadder` | ladder 12/36/60/84/108/120 (§5.7) |
| S6 | Enemy + Bestiary | `Enemy.swift` `Bestiary.swift` | 18-entry factory (§5.5); values stubbed → filled by data river |
| S7 | Collision system | `Collision.swift` | grid broad-phase + circle/AABB (§5.6) |
| S8 | Level/Wave data model | `Level.swift` `Wave.swift` | `Level`, `WaveCue`, `Wave`, `Formation` (§5.8) |
| S9 | LevelDirector + Campaign | `LevelDirector.swift` `Campaign.swift` | phase machine + loop (§5.8) |
| S10 | Bosses framework | `Bosses/Boss.swift` `Bosses/BossPhase.swift` | phase state-machine scaffold (§5.9) |

### 4B. Presentation & shell (own `Sources/GameRender*/`, `GameAudio/`, etc.)

| # | Agent | Files owned | Notes |
|---|---|---|---|
| P1 | SpriteKit host + Camera | `GameRenderSpriteKit/` | `GameScene`, fixed-step `update`, `Camera` width-lock (§6.1–6.3) |
| P2 | Audio engine | `GameAudio/` | `AVAudioEngine`, SN76489 synth or samples (§8) |
| P3 | Input | `GameInput/` | touch drag-to-move + `GameController` → `Intent` (§7) |
| P4 | SwiftUI shell + HUD | `GameUI/` | `@Observable AppModel`, HUD, menus, settings (§10) |
| P5 | App target | `App/` | `@main App`, entitlements, Game Center, haptics wiring (§10) |

### 4C. Data-extraction river (NO code dep — start at minute zero)

Each is a research/measurement session producing a data file the code river consumes.
Maps directly to the §16 table.

| # | Agent | Produces | Source |
|---|---|---|---|
| D1 | Ship kinematics | speed/accel/bounds/fire cadence → `Tuning` | emulator measure |
| D2 | Bullet & weapon forms | bullet speeds, triple spread, laser → `Tuning`/`Weapons` | measure + disasm |
| D3 | Bestiary stats | per-enemy hp/points/hitbox/movement/fire (18 enemies) | measure + disasm (`0x0518`) |
| D4 | Scroll & spawn | scroll speed, spawn distance → `Tuning`/`Camera` | measure |
| D5 | Wave layout | wave composition + positions per zone | disasm name-table layer (App. C, `sub_2534`) |
| D6 | Power-up ladder | 12…120 → effect mapping | game-design + measure |
| D7 | Boss scripts | hp + attack phases ×3 (Zanoni/Nebiros/Belzebul) | measure + disasm |
| D8 | Scoring | point values, 50k extra-life | game-design |

### 4D. Art river (NO code dep — start at minute zero)

| # | Agent | Produces |
|---|---|---|
| A1 | Allied sprites | 3 ship forms + drones + pickups (App. B allied table) |
| A2 | Galaxy enemies | Mother Boon, Cult, Sharlin, Sacle, Curos, Spindow |
| A3 | Asteroid enemies | Aster, Shamir, Ufolick, Burdle, Ashion, Tinker |
| A4 | Nebula enemies | Caborn, Dilon, Triat, Dririt, Arbleby, Tricker |
| A5 | Bosses + backgrounds + atlas pack | 3 bosses, 3 zone backgrounds, `SKTextureAtlas` assembly (§6.4) |

> **Granularity knob:** to push agent count higher, split D3/A2–A4 to **one agent per
> enemy** (18 enemies). That alone takes the roster from 3 art + 1 data agent to ~18
> data + 18 art agents — the cheapest way to "maximize sessions" if that's the goal.

**Wave 1 peak concurrency: ~16–22 agents** (10 sim + 5 presentation + ~8 data + ~5
art ≈ 28 if data/art aren't collapsed; throttle to your runner's concurrency cap).

---

## 5. Wave 2 — Integration (3–4 agents, partial barrier)

Needs Wave-1 modules to exist. Not fully parallel — these touch shared seams.

| # | Agent | Work | Waits on |
|---|---|---|---|
| I1 | `World.step` wiring | the ordered tick (§5.10): player→director→entities→collision→reap→extra-life | S1–S10 |
| I2 | Host integration | wire sim↔SpriteKit↔audio↔input fixed-step loop (§6.1–6.2) | P1–P3, I1 |
| I3 | App assembly | `AppModel`, scene mount, HUD↔Snapshot, menu→mode transitions | P4, P5, I2 |
| I4 | Test scaffold | Swift Testing target, golden-replay harness, tuning-regression asserts (§13) | I1 |

I1 is itself a mild bottleneck (it owns `World.step` order, which is faithfulness-
critical). Run it first; I2/I3 follow; I4 parallel to all once `World` runs headless.

---

## 6. Wave 3 — Content & feel (wide again, data-gated)

Now the data river's output gets poured in. Re-fans out.

| # | Agent | Work |
|---|---|---|
| C1 | Tuning fill + M1 feel-tune | apply D1/D2/D4/D8 numbers; side-by-side vs emulator until it *moves* right (§11, §14-M1) |
| C2 | Bestiary fill | apply D3 stats to all 18 `Bestiary` entries |
| C3–C5 | Zone content ×3 | Galaxy / Asteroid / Nebula wave data from D5 (one agent per zone) |
| C6–C8 | Boss phase machines ×3 | Zanoni / Nebiros / Belzebul from D7 (one agent per boss) |
| C9 | Power-up ladder fill | apply D6 mapping; verify reset-on-death |
| C10 | Audio tracks | music + SFX from PSG patterns (App. D audio) |
| C11 | Parity harness | optional emulator-vs-sim input-diff gate (§11.3, §13) |

**Concurrency: ~10 agents**, gated only by the matching data agent having finished.

---

## 7. Wave 4 — Modern polish (wide, independent)

All behind flags, all leaf changes (the seam guarantees the sim is untouched, §6.5).

| # | Agent | Work |
|---|---|---|
| M1 | Metal renderer | `GameRenderMetal/` instanced batch + tilemap, integer-scale (§6.5) |
| M2 | CRT/particles | scanline/bloom shaders, `SKEmitterNode` effects |
| M3 | Widescreen/enhanced | camera policies as settings, iPad pillarbox (§6.3) |
| M4 | 120 Hz + controller | ProMotion render-interp, MFi/DualSense/Xbox (§7) |
| M5 | Accessibility + Game Center polish | leaderboards, haptics tuning |
| M6 | Ship prep | settings, balancing pass, App Store packaging (§14-M5) |

**Concurrency: ~6 agents**, mutually independent.

---

## 8. Coordination protocol (how N agents don't trip over each other)

1. **Disjoint file ownership.** The tables above assign every file to exactly one
   agent. No file has two writers in a wave. This is what makes the fan-out safe.
2. **The contract is frozen after Wave 0.** Signatures of `Snapshot`, `Intent`,
   `Entity`, `SimContext`, `World` spawn/score API, `Tuning` *names* (not values).
   A change to any of these is a **stop-the-world re-sync**: it ripples to every
   agent. Treat Wave 0 as the most careful work in the project.
3. **Stubs over blocking.** S6 (Bestiary) needs S1–S3's behavior types — it imports
   their *protocols* (defined in Wave 0/early S1–S3), not their tuned values, so it
   never waits. Same pattern everywhere: depend on the interface, stub the value.
4. **Data/Art write data files, not Swift.** D* and A* drop into `Tuning` data files
   and `Art/` — the code river reads them in Wave 3. They never link, so they never
   collide with the code agents.
5. **Worktree isolation per agent.** If orchestrated via the `Workflow` tool, give
   file-mutating agents `isolation: "worktree"` so parallel writes can't conflict;
   merge at each wave barrier. (Note: this dir is **not currently a git repo** —
   `git init` first if you want worktree isolation.)
6. **Wave barriers.** Wave N+1 starts only when Wave N's exit criterion is met. The
   only true barriers are Wave 0→1 and (partially) 1→2. Data/Art ignore barriers.

---

## 9. Concurrency summary

| Wave | What | Peak agents | Barrier? |
|---|---|---|---|
| 0 | Freeze contracts | **1** | hard (blocks all) |
| 1 | Sim + presentation + data + art | **~16–28** | none internally; data/art unbarriered |
| 2 | Integration | ~4 | partial (I1 first) |
| 3 | Content & feel (data-gated) | ~10 | per-item gate on data river |
| 4 | Polish | ~6 | none |

**To literally maximize session count:** collapse nothing and split the rosters to
one-agent-per-enemy (D3, A2–A4) and one-agent-per-boss (D7, C6–C8). That alone yields
**40+ distinct sessions** across the project, with a Wave-1 peak near 28 concurrent.

**To maximize *throughput* (recommended):** keep Wave 0 tiny and serial, launch the
**data + art rivers on day one** (they're the long-lead items and gate M1 feel-tuning),
and hold Wave-1 code concurrency to your runner's cap (the blueprint's `Workflow`
guidance caps at ~16 concurrent). The critical path is Wave 0 → World.step → feel-tune,
not the breadth — so spend care there and let everything else fan out around it.

---

## 10. Recommended kickoff order

1. **Now:** launch Wave 0 (1 agent) **and** the full data river (D1–D8) **and** art
   river (A1–A5) — these three start simultaneously; data/art don't wait for Wave 0.
2. **On Wave 0 freeze:** fan out all of 4A + 4B (~15 agents).
3. **As S1–S10 land:** run Wave 2 integration (I1 → I2/I3, I4 parallel).
4. **As data lands:** Wave 3 content fill + the M1 feel-tune loop (the real risk).
5. **After M3 parity:** Wave 4 polish fan-out.
