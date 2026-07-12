# Astro Warrior (SMS) — modern Swift rebuild

A ground-up rebuild of the 1986 Sega Master System shooter *Astro Warrior* for Apple
platforms (Mac-first dev), whose **gameplay simulation is ported from the original so it
plays identically**, while presentation is rebuilt with SpriteKit / SwiftUI. See
[`docs/`](docs/) for the full build blueprint and the worksweep plan, and
[`docs/roadmap-two-tracks.md`](docs/roadmap-two-tracks.md) for the game-vs-framework
(SegaKit) parallel-track plan.

## Status

The pure `GameSim` skeleton runs (ship, firing, waves, Stage-1 content into a boss). A
**parity debugger** runs the original ROM beside our sim in deterministic lockstep, and
we've begun extracting faithful values from the ROM and pouring them into `Tuning.swift`.

**Player ship is now 1:1 with the ROM** — speed (1.5 px/f, normalized), start position,
bullet speed (12 px/f), fire cadence, and movement bounds are all measured and verified
(tracks the ROM to ±1 frame). The entity pool is classified (player / bullet / power-up /
fx / enemy species). Full measured record: [`docs/parity-findings.md`](docs/parity-findings.md).

Next: enemy species names + per-type hp/points, scroll rate, and the spawn/block tables.

## Layout

- **`AstroWarriorKit/`** — Swift package (the engine). `GameSim` is pure, deterministic,
  60 Hz, depends on nothing; `GameRenderSpriteKit` / `GameAudio` / `GameInput` / `GameUI`
  are presentation skins over it.
- **`AstroWarrior/`** — the Xcode app shell that hosts the engine.
- **Parity debugger** (`ParityDebug`, `ReferenceEmu`, `CSMSCore`, `ParityProbe`) — runs the
  original ROM next to our sim in deterministic lockstep to measure and converge the tuning.

## Developer notes

- **The reference emulator core (`CSMSCore/smsplus`) is GPL-2 and DEV-ONLY.** It is used only
  by the parity debugger to compare against the original; it must **not** ship in the app. A
  Swift-native emulator is planned to replace it behind the `ReferenceCore` protocol.
- **The ROM is not included** (copyrighted). Provide your own `Astro Warrior.sms`; the parity
  tools load it from a gitignored local path.

## Build

```
cd AstroWarriorKit && swift build && swift test      # headless engine + tests
```
Open `AstroWarrior/AstroWarrior.xcodeproj` for the app (macOS scheme).
