# Astro Warrior (SMS) — modern Swift rebuild

A ground-up rebuild of the 1986 Sega Master System shooter *Astro Warrior* for Apple
platforms (Mac-first dev), whose **gameplay simulation is ported from the original so it
plays identically**, while presentation is rebuilt with SpriteKit / SwiftUI. See
[`docs/`](docs/) for the full build blueprint and the worksweep plan.

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
