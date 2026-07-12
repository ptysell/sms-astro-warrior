# Roadmap — Two Parallel Tracks: the Game and the Framework

We run two efforts from one codebase, together. They are symbiotic: the game is the
proving ground; the framework is what's left when you remove the game-specific bits.

- **Track A — Astro Warrior.** A faithful, modern object-oriented Swift port of the
  specific 1986 SMS game (the deliverable).
- **Track B — the Framework** *(working name: SegaKit).* The reusable, system-agnostic
  reverse-engineering + faithful-port toolkit, **harvested from Track A** — not built
  speculatively.

The guiding principle: **harvest, don't abstract ahead of evidence.** Track B is
*noticed* emerging from Track A and extracted once patterns repeat (rule of three /
after a second game), not designed up front.

---

## The honest boundary (what Track B is and isn't)

Full auto-decompilation — *throw in any ROM, out comes a clean OOP game* — is **not the
goal**, because it isn't feasible: recovering a game's *meaning* (this Z80 is an AI state
machine; this table is a level) is an irreducible reverse-engineering act. Even the most
successful "ROM → source" projects (SM64/Zelda decomps) are enormous per-game human
efforts that aim for byte-*matching* C, not modern OOP.

So Track B automates **everything around the understanding**, and makes the human/AI
understanding **fast and verifiable** — an *RE + faithful-port studio*, not a magic
converter. That is a real thing that doesn't exist; the magic version isn't.

---

## What each track owns

**Track A — game-specific (data & content):**
- RAM offset map, entity type→species table, coordinate conventions
- `Tuning` values, `Bestiary`, level/wave content, boss scripts
- Recreated art, audio, HUD/menus

**Track B — generic (reusable machinery):**
- `ReferenceCore` protocol + pluggable emulator cores (the "oracle")
- **Probe primitives** (proven generic 8-bit RE tools): monotonic-byte scan
  (find counters/score), diff-under-input (find what a button touches), motion
  classification (label entities by velocity), entity-pool discovery, framebuffer dump
- **Parity harness**: deterministic lockstep, input record/replay, the System Monitor /
  live object inspector
- **Architecture template**: the `GameSim` Entity + strategy-behavior + `Snapshot` +
  `Tuning` pattern for any 2D game
- **Asset codecs**: tile (4bpp planar), palette (CRAM), PSG audio — hardware-standard,
  fully generic to extract

Rough split today: ~60% of Track B's pieces already exist inside Track A; they just
aren't extracted yet.

---

## How they run together (sequencing)

1. **Now:** get Astro Warrior to real parity (Track A end-to-end), keeping seams clean —
   per-game specifics as *data/config* separable from generic machinery (Track B hygiene).
2. **As patterns stabilize:** mark the candidate framework boundaries; still don't extract.
3. **Second game** (ideally a different genre, same repo): the forcing function that turns
   "reusable-looking" into "actually reused." Harvest `SegaKit` here.
4. **New systems:** Game Gear is nearly free (same Z80/VDP/PSG core); NES/Genesis/etc. =
   a new core + asset codecs behind the *same* protocols — the parity/probe/architecture
   layers don't change.

---

## Module-boundary north-star (illustrative, not committed)

```
SegaKit  (generic, Track B)
├── SegaKitEmu       # ReferenceCore protocol + per-system emulator cores
├── SegaKitProbe     # RE primitives (byte-scan, diff-under-input, motion classify, …)
├── SegaKitParity    # lockstep harness, record/replay, System Monitor
├── SegaKitAssets    # tile/palette/PSG codecs
└── GameSim          # Entity/behavior/Snapshot/Tuning architecture template

AstroWarrior  (game, Track A)
└── config + content + art layered on top of SegaKit
```

This lives as a lodestar: when tooling has a near-free fork between "hardcode for Astro
Warrior" and "config/protocol-driven," lean reusable — but earn the abstraction, don't
guess it. See [`parity-findings.md`](parity-findings.md) for the concrete Track-A data.
