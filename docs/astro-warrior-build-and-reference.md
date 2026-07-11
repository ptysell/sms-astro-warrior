# Astro Warrior — Complete Build & Reference Document

**Single-file handoff. Self-contained.** The main body (§1–§16) is the architecture
to build. **Appendices A–E fold in every piece of reference material** — game design,
sprite/asset manifest, the reverse-engineering map, ROM format, and sources — so a
coding session needs no other file. Every **[extract]** marker in the body points to
the appendices for where that value lives in the original ROM.

> Note on paths: appendix references to `src/`, `assets/gfx/`, `tools/`,
> `palette_candidates.txt`, etc. refer to the **separate reverse-engineering project**
> (the reference-art + extraction toolkit), *not* the iOS app being built here. They
> tell you where the extracted reference assets and the extraction scripts live.

---

## 1. Vision & principles

A **ground-up modern rewrite** of the 1986 SMS shooter *Astro Warrior* for iPhone,
whose **gameplay simulation is ported from the original so it plays identically**,
while everything visible/audible/architectural is rebuilt with current frameworks.

The organizing principle, from which everything follows:

> **The simulation is the game. The presentation is a skin.**
> "Plays identically" is a property of the simulation *only*. Build the sim in the
> original's logical world; render that world however you like.

Design tenets:

1. **Object-oriented domain model** — enemies, weapons, levels, bosses are
   first-class objects with properties and behaviors, composed (not a deep
   inheritance tree), the way a maintainable modern game is built.
2. **Deterministic logical simulation** — the sim runs in abstract logical units
   at a fixed 60 Hz tick; this is what makes "plays identically" well-defined.
3. **Resolution independence** — lock the gameplay-critical axis, flex the other;
   render at any resolution with recreated art.
4. **Data-driven content** — levels, waves, enemy stats, and tuning are data, so
   the game is authored and tuned, not hard-coded.
5. **Faithful tuning, worked backwards from the original** — the *values* and
   *behaviors* come from the ROM (measurement + disassembly-as-data); the *code* is
   modern and owes the Z80 nothing.

What we are **not** doing: reproducing the hardware. Tiles, metasprites, planar
4bpp, CRAM palette, the shadow SAT/DMA, fixed-point-for-no-FPU, byte-parity — all
discarded as Z80/VDP artifacts.

---

## 2. The game (target behavior)

Vertical top-down scroller; the field scrolls up continuously, the ship moves on
both axes. **Three zones, each ending in a boss, then it loops** faster/harder
forever (this Hang-On/Astro-Warrior combo cart ends after the third Belzebul):

| Zone | Boss | Power-up blocks |
|---|---|---|
| Galaxy | Zanoni | 159 |
| Asteroid | Nebiros | 131 |
| Nebula | Belzebul | 116 |

- **One hit = death. 3 lives. Extra life every 50,000 pts** (up to 4).
- **Three ship forms** (single → triple → laser) + **2 follower drones**, earned
  via a **power-up ladder**: shoot background power-up blocks; upgrades at
  cumulative counts **12 / 36 / 60 / 84 / 108 / 120**, interleaving speed-ups and
  weapon tiers; **dying resets the block counter to 0**.
- Enemy roster (official names): Galaxy — Mother Boon, Cult, Sharlin, Sacle, Curos,
  Spindow; Asteroid — Aster, Shamir, Ufolick, Burdle, Ashion, Tinker; Nebula —
  Caborn, Dilon, Triat, Dririt, Arbleby, Tricker. Behaviors are simple: descend,
  weave, dive, ring-fire. Two enemy types are indestructible.

Full design + sources: Appendix A, Appendix B.

---

## 3. Technology stack (current as of mid-2026, verified)

- **iOS 26 SDK**, **Swift 6** with *complete* concurrency checking, **Xcode 26**.
  (Check WWDC 2026 for any newer game framework; nothing here depends on one.)
- **Rendering / scene:** **SpriteKit**, hosted in **SwiftUI via `SpriteView`** —
  the standard native 2D path for a 100%-Swift game. **Metal** is the optional
  later upgrade for pixel-perfect/CRT, behind the renderer protocol.
- **App shell:** SwiftUI (`@main App` + `WindowGroup` + `SpriteView`), `@Observable`
  for shell/HUD state.
- **Audio:** `AVAudioEngine` (PSG-style synth or recreated samples).
- **Services:** **GameKit** (Game Center leaderboards), **CoreHaptics**,
  **GameController** (MFi/DualSense/Xbox).
- **Packaging:** Swift Package Manager, modular targets (§12).
- **Orientation:** portrait-locked (vertical shooter).

SpriteKit + SwiftUI practical notes baked into the design: keep a **single root
`SKNode`** under the scene (multiple roots can break texture loading), **sort by
Z-position** (don't rely on sibling order), and set `scaleMode = .resizeFill` so we
own the logical→screen mapping.

---

## 4. Architecture overview

Two worlds with one one-way seam.

```
┌──────────────────────────────────────────────────────────────┐
│  GameSim  (pure Swift, OOP, logical units, fixed 60 Hz)        │
│  • World owns the object graph & runs the tick                 │
│  • Player / Enemy / Bullet / Drone / PowerUp / Boss objects    │
│  • LevelDirector drives Level (waves) → spawns into World      │
│  • produces a Snapshot: immutable render + audio command list  │
│  NO UIKit / SpriteKit / Metal. Single isolation domain.        │
└───────────────▲──────────────────────────┬───────────────────┘
                │ Intent (player input)     │ Snapshot (what to draw/play)
┌───────────────┴──────────────────────────▼───────────────────┐
│  Presentation shell                                            │
│  • SKScene host: fixed-step drives sim, mirrors → SKNodes      │
│  • Camera: width-lock + vertical policy, logical→screen        │
│  • Input: touch (drag-to-move) + GameController → Intent       │
│  • Audio: AVAudioEngine driven by Snapshot commands            │
│  • SwiftUI app/HUD/menus (@Observable), Game Center, haptics   │
└──────────────────────────────────────────────────────────────┘
```

**The contract:** `GameSim` consumes an `Intent`, returns a `Snapshot`. It never
renders, never plays audio, never sees a touch, never knows the resolution. This is
what makes it deterministic, testable, and renderer-agnostic (SpriteKit today,
Metal tomorrow).

---

## 5. GameSim — the simulation (the part that plays identically)

### 5.1 Units & coordinate space

All sim quantities are in **logical units**. The playfield is **256 × 192 logical
units** (the original's), with the world extending arbitrarily far in +Y (scroll).
Positions, velocities, and hitboxes are **`Double`** — floats are fine because
determinism comes from the fixed timestep + identical constants, not from
fixed-point (which was a hardware crutch). The ship sits near the bottom; +Y is
"up the field" (scroll direction); choose one convention and keep it.

### 5.2 Timing & the loop

**Fixed 60 Hz simulation step.** The host accumulates real time and advances the
sim in whole ticks; rendering interpolates between ticks for smoothness (and runs at
the display rate, incl. 120 Hz ProMotion). This is the *one* timing rule that makes
play identical to the original's 60 Hz cadence.

```swift
public let SIM_HZ = 60.0
public let SIM_DT = 1.0 / SIM_HZ
```

### 5.3 Object model

```swift
// Logical units throughout. One isolation domain (see §9) — plain classes, no Sendable churn.
open class Entity {
    public var position: SIMD2<Double>
    public var velocity: SIMD2<Double>       // logical units / tick
    public var hitbox: Hitbox                // circle or AABB, logical units
    public var sprite: SpriteRef             // which art to draw (id + frame)
    public var isDead = false
    public init(at p: SIMD2<Double>, sprite: SpriteRef, hitbox: Hitbox) { … }
    open func update(_ ctx: SimContext) { position &+= velocity }   // one tick
    open func onHit(by other: Entity, _ ctx: SimContext) {}
}

public protocol Damageable: AnyObject { var hp: Int { get set }
    func takeDamage(_ amount: Int, _ ctx: SimContext) }
public protocol Faction { var side: Side { get } }   // .player / .enemy / .neutral
public enum Side { case player, enemy, neutral }

public struct Hitbox { enum Shape { case circle(r: Double); case aabb(half: SIMD2<Double>) }
    var shape: Shape; var offset: SIMD2<Double> = .zero }
```

```swift
public final class Player: Entity, Damageable {
    public var hp = 1                         // 1-hit death  [extract: confirm]
    public var speed: Double                  // [extract] raised by speed-up pickups
    public var weapon: Weapon                 // composition: swapped on power-up
    public var drones: [Drone] = []           // 0…2 options
    public var blocksDestroyed = 0            // power-up ladder counter (reset on death)
    public func fire(_ ctx: SimContext) { weapon.fire(from: position, ctx) }
    public func takeDamage(_ amount: Int, _ ctx: SimContext) { hp -= amount; if hp <= 0 { die(ctx) } }
}

public final class Enemy: Entity, Damageable, Faction {
    public let side = Side.enemy
    public var hp: Int                        // [extract] per type
    public let points: Int                    // [extract] per type
    public let movement: MovementBehavior     // strategy objects (§5.4)
    public let attack: AttackBehavior
    public let indestructible: Bool           // steel ball / invincible orb
    public override func update(_ ctx: SimContext) {
        movement.step(self, ctx); attack.step(self, ctx)
    }
    public func takeDamage(_ amount: Int, _ ctx: SimContext) {
        guard !indestructible else { return }
        hp -= amount; if hp <= 0 { ctx.world.addScore(points); spawnExplosion(ctx); isDead = true }
    }
}

public final class Bullet: Entity, Faction { public let side: Side; public let damage: Int }
public final class Drone:  Entity { /* mirrors player offset; fires with player */ }
public final class PowerUp: Entity { public let kind: PowerUpKind }  // speedUp / weaponUp
public enum PowerUpKind { case speedUp, triple, laser }
```

**Why composition for enemies:** one `Enemy` class configured with a
`MovementBehavior` + `AttackBehavior` + stats, rather than 18 subclasses. New enemy
= new configuration, not new type.

### 5.4 Behaviors (strategy objects)

```swift
public protocol MovementBehavior { func step(_ e: Enemy, _ ctx: SimContext) }
public struct Descend: MovementBehavior { let speed: Double }                 // straight down
public struct Weave:   MovementBehavior { let speed, amp, freq: Double }      // sinusoidal
public struct Dive:    MovementBehavior { let speed: Double; /* homes toward player once */ }
public struct Formation­Hold: MovementBehavior { /* keeps slot relative to a wave anchor */ }

public protocol AttackBehavior { func step(_ e: Enemy, _ ctx: SimContext) }
public struct NoAttack:  AttackBehavior { func step(_ e: Enemy, _ ctx: SimContext) {} }
public struct AimedShot: AttackBehavior { let interval: Double; let bulletSpeed: Double }  // [extract]
public struct RingFire:  AttackBehavior { let interval: Double; let count: Int; let bulletSpeed: Double }
```

All numeric fields are **[extract]** — sourced per §11.

### 5.5 Bestiary (enemy catalog)

A factory mapping each named enemy to a configured `Enemy`. Values **[extract]**.

```swift
public enum Bestiary {
    public static func cult() -> Enemy {
        Enemy(hp: 2, points: 100, sprite: .cult,
              hitbox: .circle(r: 7),
              movement: Weave(speed: 1.2, amp: 24, freq: 0.05),
              attack: NoAttack(), indestructible: false)
    }
    public static func spindow() -> Enemy { /* 24×24 boss-class … */ }
    // …one per roster entry (§2)
}
```

### 5.6 Collision

**In the logical sim — never SpriteKit physics** (float, non-deterministic,
framework-stepped). Broad phase: a uniform grid / spatial hash over the playfield
(cheap at these counts); narrow phase: circle/AABB tests in logical units using the
original's **[extract]** hitbox sizes. Resolution pairs: player↔enemy (player dies),
player-bullet↔enemy (enemy takes damage), player↔powerup (collect),
player↔power-up-block (increment ladder). Indestructible enemies ignore bullets.

```swift
struct CollisionSystem {
    func resolve(_ world: World, _ ctx: SimContext) { /* grid build → pair tests → onHit */ }
}
```

### 5.7 Weapons & power-up ladder

```swift
public protocol Weapon { func fire(from: SIMD2<Double>, _ ctx: SimContext) }
public struct SingleShot: Weapon { let speed: Double }                 // [extract]
public struct TripleShot: Weapon { let speed: Double; let spreadDeg: Double }  // [extract]
public struct LaserBeam:  Weapon { /* piercing, persistent */ }

public enum PowerUpLadder {                                            // §2 thresholds
    static let thresholds = [12, 36, 60, 84, 108, 120]
    // mapping threshold → (speedUp | form upgrade); exact sequence [extract]
    static func apply(to player: Player, blocks: Int) { … }
}
```

Drones: up to 2 `Drone` entities that trail the ship at fixed logical offsets and
fire in sync with the player's weapon.

### 5.8 Levels, waves, director, campaign

Content is data; `World` is the running state.

```swift
public struct Level {                         // a Zone — pure data
    public let id: ZoneID                      // .galaxy / .asteroid / .nebula
    public let scrollSpeed: Double             // [extract] logical units / tick
    public let scrollLength: Double            // [extract] field length before boss
    public let waves: [WaveCue]                // sorted by atScroll
    public let boss: BossSpec
    public let background: BackgroundSpec       // cosmetic
    public let music: TrackID
}
public struct WaveCue { public let atScroll: Double; public let wave: Wave }
public struct Wave {
    public let make: () -> Enemy               // Bestiary entry
    public let formation: Formation            // .line / .vee / .arc / .stream
    public let count: Int
    public let interval: Double                // stagger between members (ticks)
}

public final class LevelDirector {            // subsystem of World.step
    private var level: Level, scroll = 0.0, next = 0
    private enum Phase { case scrolling, boss, cleared }
    private var phase = Phase.scrolling
    func update(_ world: World, _ ctx: SimContext) {
        switch phase {
        case .scrolling:
            scroll += level.scrollSpeed
            while next < level.waves.count, level.waves[next].atScroll <= scroll {
                world.spawn(level.waves[next].wave); next += 1
            }
            if scroll >= level.scrollLength { world.spawnBoss(level.boss); phase = .boss }
        case .boss:    if world.bossDefeated { phase = .cleared }
        case .cleared: world.campaign.advance(self)        // next zone or loop +difficulty
        }
    }
}

public final class Campaign {                 // ordered zones + infinite loop
    let levels: [Level]                        // [galaxy, asteroid, nebula]  [extract content]
    var index = 0, loop = 0
    func advance(_ director: LevelDirector) { /* next or wrap; scale difficulty by loop */ }
}
```

Level content (which waves at which scroll positions, formations, scroll speed,
boss) is **[extract]** from the original's spawn/wave data — the name-table object
layer located in Appendix C. Express as a Swift level-builder DSL or a
decoded data file so zones stay editable.

### 5.9 Bosses

Each boss is its own object with a **phase state machine** (intro → attack
patterns → death), spawned from `BossSpec` at zone end. Large multi-part sprites;
HP and attack scripts **[extract]**.

```swift
public final class Boss: Entity, Damageable {
    public var hp: Int                         // [extract]
    private var phase: BossPhase
    public override func update(_ ctx: SimContext) { phase.step(self, ctx) }
}
protocol BossPhase { func step(_ b: Boss, _ ctx: SimContext) -> Void }
```

### 5.10 World, game state, scoring

```swift
public enum Mode { case title, playing, boss, gameOver }

public final class World {
    public private(set) var entities: [Entity] = []
    public var player: Player
    public var camera: Camera                  // §6.3 (scrollY lives here)
    public let campaign: Campaign
    public private(set) var director: LevelDirector
    public var score = 0, hiScore = 0, lives = 3
    public var mode: Mode = .title
    public var rng = RNG(seed: 0xA57E)         // §5.11

    public func step(_ intent: Intent) {       // ONE TICK — order matters (faithful)
        switch mode {
        case .playing, .boss:
            player.update(ctx(intent))         // movement + fire cadence + form
            director.update(self, ctx(intent)) // scroll, spawn waves, boss, transitions
            for e in entities { e.update(ctx(intent)) }   // enemies / bullets / drones
            CollisionSystem().resolve(self, ctx(intent))
            reapDead(); checkExtraLife()
        default: updateMenus(intent)
        }
    }
    public func snapshot() -> Snapshot { /* §5.13 */ }
    func addScore(_ p: Int) { score += p; hiScore = max(hiScore, score) }
}
```

- **1-hit death**, **3 lives**, **extra life @ 50,000** (≤4). On death: lose a life,
  reset `player.blocksDestroyed`, reset form to single, respawn or game-over.

### 5.11 RNG

Seeded, deterministic (`xoshiro128**` / SplitMix64), threaded through `SimContext`.
No `Date()`, no `.random()`. Only strictly needed if you want replays/netplay
(§11); cheap to include from day one.

### 5.12 Tuning

One file, `Tuning.swift`, holding **every** gameplay constant in logical units —
ship speed/accel/bounds, fire cadence, bullet speeds, scroll speed, power-up
thresholds, spawn distance, hitbox sizes, scoring, loop scaling. This is the
single auditable surface you compare against measurement (§11). All **[extract]**.

### 5.13 Snapshot (output)

Immutable description the renderer/audio consume; logical coordinates.

```swift
public struct Snapshot: Sendable {
    public struct SpriteDraw { let sprite: SpriteRef; let pos: SIMD2<Double>; let z: Int }
    public let sprites: [SpriteDraw]           // logical positions
    public let scrollY: Double                 // camera position in the world
    public let background: BackgroundRef
    public let audio: [AudioCommand]           // play sfx / set music — no audio API here
    public let hud: HUDState                   // score, lives, form (for SwiftUI)
}
```

---

## 6. Presentation layer

### 6.1 Renderer protocol + SpriteKit host

The renderer is a **pure function of `Snapshot`**. SpriteKit is a *host + renderer*
only; the sim owns truth.

```swift
public protocol Renderer { func present(_ snapshot: Snapshot, lerp: Double, viewport: CGSize) }
```

```swift
final class GameScene: SKScene {            // the host
    let sim = World()
    let root = SKNode()                     // single root (texture-loading gotcha)
    let cam  = SKCameraNode()
    let atlas = SKTextureAtlas(named: "sprites")
    var nodes: [ObjectIdentifier: SKSpriteNode] = [:]
    var last = 0.0, acc = 0.0
    var intent = Intent()

    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        addChild(root); root.addChild(cam); camera = cam
    }
    override func update(_ now: TimeInterval) {     // §6.2
        if last == 0 { last = now }
        acc += now - last; last = now
        while acc >= SIM_DT { sim.step(intent); acc -= SIM_DT }
        present(sim.snapshot(), lerp: acc / SIM_DT, viewport: size)
    }
    func present(_ snap: Snapshot, lerp: Double, viewport: CGSize) {
        let camera = Camera(viewport: viewport)     // §6.3
        cam.position = camera.cameraPoint(scrollY: snap.scrollY)
        for d in snap.sprites {
            let n = node(for: d.sprite)
            n.position = camera.project(d.pos)      // logical → screen
            n.zPosition = CGFloat(d.z)              // sort by Z, not sibling order
        }
        reapNodesNotIn(snap)
    }
}
```

**Three discipline rules (these keep "plays identically" intact inside SpriteKit):**
1. **Fixed-step inside `update(_:)`** — never let SpriteKit's variable frame time
   drive the sim.
2. **No `SKPhysicsBody` for gameplay** — collision lives in the sim. SpriteKit
   physics only for cosmetic effects, if at all.
3. **Nodes are views, hold zero gameplay state** — `present()` is one-way
   (sim → nodes). This is also what makes the Metal swap a rewrite of only this file.

Cosmetics that *are* SpriteKit's job: scene graph, texture atlas + batching,
`SKEmitterNode` particles, `SKCameraNode`, audio nodes, scrolling background.

### 6.2 The fixed-timestep pattern

Accumulate `now - last`; step the sim while `acc >= SIM_DT`; render once with
`lerp = acc / SIM_DT` for between-tick interpolation. ProMotion renders at 120 Hz;
the sim still ticks at 60. Guard against spiral-of-death with a max-steps clamp.

### 6.3 Camera & resolution independence

Lock the gameplay-critical axis (width), flex the other (height).

```swift
struct Camera {
    let viewport: CGSize
    var scale: Double { viewport.width / 256.0 }            // lock width (5.156× on 1320pt)
    var visibleHeight: Double { Double(viewport.height) / scale }   // ~556 logical on 2868pt
    func project(_ p: SIMD2<Double>) -> CGPoint { CGPoint(x: p.x * scale, y: p.y * scale) }
    func cameraPoint(scrollY: Double) -> CGPoint { … }
    var policy: VerticalPolicy = .extendedField
}
public enum VerticalPolicy { case extendedField, fixedWindow, showMore }
```

- **Width locked:** `scale = viewport.width / 256`.
- **Height flexes:** `viewport.height / scale` logical units visible (~556 vs the
  original 192 on a 1320×2868 phone — ~2.9× the field).
- **`.extendedField` (default):** the world scrolls in the taller window, but
  enemies **spawn/activate at a fixed logical distance ahead** (the original's,
  **[extract]**), so reaction time is identical; the area above the spawn line is
  scrolling scenery. Fills the screen *and* plays identically.
- **`.fixedWindow`:** gameplay in a centered 256×192 box; margins are decorative.
- **`.showMore`:** taller view is live; accept easier readability as a QoL change.

iPad/landscape later: pillarbox the 256 width or extend with scenery — **never
stretch the playfield** (that would change play).

### 6.4 Sprite assets

Recreated art packed into `SKTextureAtlas`. For crisp pixel-art set
`texture.filteringMode = .nearest`; for hi-res redraws use `.linear`. The original
sprites (extracted via the project's tooling) are **reference/silhouette**, not the
shipping atlas. Logical→pixel scale handles any art resolution: 1 logical unit = N
pixels for free.

### 6.5 Metal upgrade path

Swap `SpriteView` → `MTKView` and provide a `MetalRenderer: Renderer`: an instanced
sprite-batch pipeline + tilemap pass, nearest-neighbor, integer-scaled, with room
for CRT/scanline/bloom shaders. The sim and `Snapshot` are untouched — this is a
leaf change.

---

## 7. Input

Drag-to-move + auto-fire (the mobile-shmup standard), plus `GameController`.

```swift
public struct Intent: Sendable {
    public var moveTarget: SIMD2<Double>?      // logical point the ship eases toward
    public var fire = true                     // auto-fire on in play
    public var special = false
    public var pause = false
}
```

Touch (in `GameScene.touchesMoved`) converts the touch point to logical units via
the camera scale and sets `intent.moveTarget`, offset so the thumb doesn't cover the
ship; the sim eases the ship toward it at `Tuning.shipSpeed`. The sim never sees a
`UITouch`. `GameController` maps the stick/buttons to the same `Intent`. Add an
input-recording hook here for replay capture (§11).

---

## 8. Audio

`AVAudioEngine`. The original PSG tracks are short; either **synthesize the
SN76489** (3 square + noise via `AVAudioSourceNode`, exact timbre) or play
**recreated/remixed samples**. Audio is driven by `Snapshot.audio` commands so the
sim stays silent and deterministic. Simple SFX can use `SKAudioNode`; music and
mixing go through `AVAudioEngine`.

---

## 9. Concurrency (Swift 6, complete checking)

The sim is an **object graph with a single owner**, so it lives on one isolation
domain — run the loop on `@MainActor` (or a dedicated `@globalActor GameLoop`). The
classes never cross actors, so no `Sendable` gymnastics. The only thing handed
across a boundary is the immutable `Snapshot` (`Sendable`) and `Intent` (`Sendable`),
so moving rendering off-main later is clean. `@MainActor` for SwiftUI/`AppModel`;
render driven by `SpriteView`/`MTKView` on main; `AVAudioEngine` and asset loading
as actors / `async` tasks.

---

## 10. App shell

```swift
@main struct AstroWarriorApp: App {
    var body: some Scene { WindowGroup { GameContainerView() }.persistentSystemOverlays(.hidden) }
}
struct GameContainerView: View {
    @State private var model = AppModel()
    var body: some View {
        ZStack {
            SpriteView(scene: model.scene, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()
            HUDOverlay(model: model)            // score/lives/form, menus
        }.statusBarHidden()
    }
}
@Observable final class AppModel {
    let scene = GameScene()
    var phase: Mode = .title                    // UI mirror of sim.mode
    // HUD pulls Snapshot.hud each frame; menus drive sim transitions
}
```

- **Game Center** (GameKit) leaderboard for the high score; **CoreHaptics** for
  hits/explosions; **Settings**: control scheme, camera policy, CRT on/off,
  faithful vs enhanced. `@Observable` drives **menus/HUD only** — never the hot loop.

---

## 11. "Plays identically" — what's pinned, and verification

**Pinned (the port):** the logical 256×192 space, the fixed 60 Hz tick, and the
original's tuning constants/behaviors (`Tuning.swift`, `Bestiary`, level data).
**Free (modern):** resolution, art, frame rate, audio, effects, architecture.

**No byte-parity, no fixed-point.** Verify by **feel-parity**, which is measurable:

1. **Measure** the original by frame-stepping an emulator — ship logical-units/tick,
   bullet speed, fire interval, scroll rate, hitbox sizes, spawn distance — and set
   `Tuning.swift` to the logical equivalents.
2. **Side-by-side playtest** against the emulator for movement, spawn timing, and
   difficulty curve; tune `Tuning`/level data until indistinguishable.
3. **(Optional)** seed the RNG + log inputs → deterministic replays; diff a replay
   against the emulator for an objective parity check. Adopt only if you want
   replays/netplay as features.

---

## 12. Module structure (SPM)

```
AstroWarrior/
├── Package.swift
├── Sources/
│   ├── GameSim/            # pure, no deps — the ported game (logical, 60 Hz, OOP)
│   │   ├── World.swift  Entity.swift  Player.swift  Enemy.swift  Bullet.swift
│   │   ├── Drone.swift  PowerUp.swift  Weapons/  Behaviors/  Bestiary.swift
│   │   ├── Level.swift  Wave.swift  LevelDirector.swift  Campaign.swift  Bosses/
│   │   ├── Collision.swift  RNG.swift  Tuning.swift  Snapshot.swift  Geometry.swift
│   ├── GameRenderSpriteKit/  # SKScene host + Camera + node mirroring (Renderer impl)
│   ├── GameRenderMetal/       # later: MTKView Renderer impl
│   ├── GameAudio/             # AVAudioEngine PSG/samples
│   ├── GameInput/             # touch + GameController → Intent
│   └── GameUI/                # SwiftUI shell, HUD, menus, settings, @Observable models
├── App/                       # @main App, Game Center, entitlements, assets catalog
├── Art/                       # recreated sprite atlas (any resolution)
└── Tests/                     # Swift Testing — see §13
```

Target deps: `GameSim` depends on nothing. Render/Audio/Input/UI depend on
`GameSim`. `App` wires them. This dependency direction is the discipline that keeps
the sim pure.

---

## 13. Testing

- **Swift Testing** over `GameSim` (pure → fully testable headless).
- **Golden replay tests:** record an `Intent` stream, replay through `World`, assert
  the resulting state/score is bit-identical — catches behavioral drift from any
  refactor.
- **Tuning regression:** assert key constants match the measured originals.
- **Parity harness (optional):** drive the emulator and `GameSim` with one input
  stream; diff. The objective "is it faithful" gate.
- Render/UI: snapshot/UI tests as normal; the sim carries the gameplay test weight.

---

## 14. Build milestones

- **M1 — feel first (highest risk).** `GameSim` skeleton + fixed-step host +
  `Player` drag-to-move + one `Enemy` (Descend) + logical collision; SpriteKit
  renderer with placeholder art; width-lock scale on-device. **Tune ship + scroll +
  fire against the emulator until it *moves* like Astro Warrior.**
- **M2 — the game.** Full `Bestiary` behaviors; `Level`/`Wave`/`Director` with zone
  1 content; power-up ladder + ship forms + drones; scoring/lives. Recreated sprites
  in. Camera vertical policy.
- **M3 — content & feel.** All three zones + bosses (phase machines); `AVAudioEngine`
  music/SFX; HUD/menus; Game Center; haptics.
- **M4 — modern polish.** Metal renderer + CRT/particles; widescreen/enhanced mode
  behind flags; 120 Hz; controller; accessibility.
- **M5 — ship.** Settings, balancing pass, App Store packaging.

---

## 15. Open decisions (with recommendations)

1. **Renderer first impl:** SpriteKit (recommended — fastest to playable) vs Metal
   from the start (viable given the seam). Either way the sim is unchanged.
2. **Camera vertical policy default:** `.extendedField` (recommended) vs
   `.fixedWindow` vs `.showMore`; ship one, expose the rest as a setting.
3. **Art direction:** faithful redraw (crisp/hi-res, same look — recommended for v1)
   vs reimagined style.
4. **Constant sourcing precision:** measured-and-tuned (fast, feel-faithful —
   recommended) vs pulled exactly from disassembly-as-data (slower, precise); refine
   from disasm only where feel is ambiguous.
5. **Replays/netplay:** include seed + input log now (cheap if early) or skip — only
   if those features are wanted.
6. **Min iOS:** 26 (newest APIs) vs 18 (reach).

---

## 16. The data bridge — what to extract from the ROM

The architecture above is complete; the remaining work is filling the **[extract]**
values. Sources, in order of preference: emulator **measurement**, the
**disassembly-as-data** (already mapped — see below), and the **reference wikis**.

| Needs | Lands in | Source |
|---|---|---|
| ship speed, accel, bounds, fire cadence | `Tuning` | measure |
| bullet speeds; weapon form behaviors | `Tuning`, `Weapons/` | measure + disasm |
| per-enemy hp / points / hitbox / movement / fire | `Bestiary`, `Behaviors/` | measure + disasm |
| scroll speed, spawn distance | `Tuning`, `Camera` | measure |
| wave composition + positions per zone | `Level` data | disasm (name-table layer, Appendix C) |
| power-up ladder mapping (12…120 → effects) | `PowerUpLadder` | game-design + measure |
| boss hp + attack scripts | `Bosses/` | measure + disasm |
| scoring values, extra-life threshold | `Tuning` | game-design |

**Reused from prior project work:** the asset extractor → reference art for
redrawing; Appendix A / Appendix B → the design + naming spec; the
sprite-engine RE → the map to the spawn/wave tables. **Discarded:** everything
hardware (tiles/metasprites/palette/SAT/DMA/fixed-point) — not part of this build.

---

## 17. Reference material

All reference material is folded into the appendices below:
**A** game-design spec · **B** sprite & asset manifest · **C** reverse-engineering
map (entity engine + ROM addresses) · **D** ROM format · **E** external sources.

---

## Appendix A — Game-design spec


Gameplay synthesized from the StrategyWiki guide
(<https://strategywiki.org/wiki/Astro_Warrior>), **cross-referenced to the
reverse-engineering** in Appendix C / Appendix D. The point of
this doc is to make the rebuild *behaviourally* faithful, not just visually — and
to anchor each mechanic to where it lives in the ROM.

### Overview

Vertically-scrolling top-down shooter (1986, Sega). The field scrolls upward
continuously; the ship can move on both axes within the screen. Three zones, each
ending in a boss. After the third boss the zones **loop**, faster and with more
enemies — indefinitely, *except* on this Hang-On / Astro Warrior combo cart, which
**ends after Belzebul is beaten a third time**.

> RE anchor: the loop/zone progression is driven by a small counter — `sub_2309`
> increments `0xC238` and wraps at `CP 6`, consistent with a 3-zone × 2-phase
> (field / boss) cycle. The combo-cart end condition is a finite iteration count
> on top of that.

### Player ship

- **One hit = death.** No health bar. **3 lives.** Extra life every **50,000
  points**, up to 4 extra.
- Three ship **forms**, each a weapon tier, plus two follower drones:
  1. **Starting ship** — single forward bullet.
  2. **Triple-shot ship** — 3-way fire.
  3. **Laser-beam ship** — piercing beam.
  4. **+2 copy drones** (Gradius-style options) — mirror the ship's fire and trail
     its movement.
- **Speed-ups** are separate and critical: the base ship is too slow to dodge
  later waves.

> RE anchor: player handler `0x0807` selects ship graphics by a form flag
> (`0xC264` → pages tiles from window `0xAA00` vs `0xB100`) and animates via a
> counter `0xC229` indexing frame tables `0x0C98` / `0x0CA8`. That form switch =
> these weapon tiers. Drones are separate entities in the `0xC6C0` sub-pool (the
> player handler iterates `0xC6C0`, 6 slots, setting their active bit).

### Power-up system

You earn upgrades by shooting **power-up blocks** embedded in the *background*
(not enemies). After enough blocks are destroyed, a pickup travels down the
centre of the screen.

- Upgrades arrive at cumulative block counts **12, 36, 60, 84, 108, 120**,
  interleaving speed-ups and weapon tiers.
- After 120 blocks you get the Laser Beam every 12 blocks until maxed; past that,
  no more pickups appear.
- **Dying resets the block counter to 0** — you re-climb the upgrade ladder.

> RE anchor: background blocks are the **name-table object layer** (`sub_2534`
> draws tile objects into VRAM `0x3800`, the scrolling field). A block counter in
> work RAM gates pickup spawns at the thresholds above and is zeroed on death.

### Zones & bosses

| # | Zone | Boss | Power-up blocks in zone |
|---|---|---|---|
| 1 | Galaxy Zone | **Zanoni** | 159 |
| 2 | Asteroid Zone | **Nebiros** | 131 |
| 3 | Nebula Zone | **Belzebul** | 116 |

Stages have no terrain obstacles — only enemies and the destructible background
blocks. Reaching the end of a zone triggers its boss fight.

### Enemy roster

Official enemy names (SMS Power), grouped by zone — these map onto the **16-entry
type dispatch table at `0x0518`** (type 1 = player; 2–15 = enemies / bosses /
effects). Full catalog with sizes and ROM locations in Appendix B.

- **Galaxy Zone:** Mother Boon, Cult, Sharlin, Sacle, Curos, Spindow
- **Asteroid Zone:** Aster, Shamir, Ufolick, Burdle, Ashion, Tinker
- **Nebula Zone:** Caborn, Dilon, Triat, Dririt, Arbleby, Tricker

Plus allied weapons/pickups: Triple Shot Canon, Beam Canon, Asistor (drone),
Speedup Parts. **Curos is located exactly** (bank 4 tile 40, 100% match); the
ringed "Cult" sits in bank 4. The StrategyWiki boss names (Zanoni / Nebiros /
Belzebul) don't map 1:1 onto these; boss sprites are large and resolved by the
per-handler decode.

Difficulty scales after the first loop: more enemies, faster movement, heavier
fire — a global "loop index" multiplier on spawn rate / velocity.

### Implementation mapping (game concept → ROM → code)

| Mechanic | ROM anchor | `src/` target |
|---|---|---|
| Continuous scroll | scroll regs via `sub_059B` (VDP r8/r9) | `updateScroll` |
| Entity update by type | jump table `0x0518`, structs at `0xC600` | `subsystems` + per-type dispatch |
| Player forms/weapons | `0x0807`, form flag `0xC264`, frames `0x0C98/0x0CA8` | player state machine |
| Drones (2) | sub-pool `0xC6C0` ×6 | option entities |
| Background blocks + pickups | name-table layer `sub_2534` → VRAM `0x3800`; block counter | tilemap-object layer + pickup logic |
| Zones / bosses / loop | progression counter `0xC238` (wrap 6) | `mode` / zone state |
| Lives / 1-hit death / 50k extra | scoring + life RAM | `GameState.score/lives` |
| Sprite output | shadow SAT `0xC400`/`0xC480` → VRAM `0x7F00` | frame `sprites[]` |

### Open items

- Per-handler decode (types 2–15) for exact enemy behaviours, fire patterns, and
  full-size sprites.
- Locate the block counter and pickup-spawn thresholds in RAM to confirm the
  12/36/60/84/108/120 ladder.
- Boss state machines (Zanoni / Nebiros / Belzebul) — large multi-part sprites and
  scripted attack phases.

---

## Appendix B — Sprite & asset manifest


Authoritative sprite catalog, compiled from SMS Power
(<https://www.smspower.org/Sprites/AstroWarrior-SMS>) and the StrategyWiki guide,
cross-referenced to the ROM. "dots" = non-transparent pixel count (a size proxy)
as reported by SMS Power.

### Confirmed sprite format

- **8×16 hardware sprites paired into 16×16 metasprites, column-major** tile order
  (TL, BL, TR, BR). Verified: **Curos matches the ROM at 100%** at bank 4 tile 40
  (ROM 0x10500) under this exact ordering.
- The SMS VDP has **no sprite flipping**, so symmetric objects store left and right
  halves as separate tiles.
- Sprite palette varies per object/zone — there is no single global sprite palette.
  The true palette for a located sprite is recoverable by mapping ROM color-indices
  to the reference's pixel colors (done for Curos; 5 colors).

### Allied forces (player)

| Sprite | Role | Size (dots) | Notes |
|---|---|---|---|
| The Astoro Raider 1 | base ship — single shot | — | weapon tier 1 |
| The Astoro Raider 2 | ship — triple shot form | 166 | weapon tier 2 |
| The Astoro Raider 3 | ship — laser form | 172 | weapon tier 3 |
| Triple Shot Canon | 3-way bullet | 158 | tier-2 projectile |
| Beam Canon | laser beam | — | tier-3 projectile |
| Asistor | follower drone (option) | — | up to 2, sub-pool 0xC6C0 |
| Speedup Parts | speed-up pickup | 138 | critical pickup |

> Ship graphics are paged from window `0xAA00` / `0xB100` (player handler 0x0807);
> the physical tiles sit in bank 4 around **0x12A00**. The three Raiders are the
> three forms switched by the weapon-tier flag `0xC264`.

### Enemies by zone (Devil Star Corp)

**Galaxy Zone:** Mother Boon · Cult · Sharlin · Sacle · Curos · Spindow
**Asteroid Zone:** Aster · Shamir · Ufolick · Burdle · Ashion · Tinker
**Nebula Zone:** Caborn · Dilon · Triat · Dririt · Arbleby · Tricker

| Enemy | Zone | Size (dots) | ROM (where located) |
|---|---|---|---|
| Curos | Galaxy | 116 | **bank 4 t40 / 0x10500 (exact, 100%)** |
| Cult | Galaxy | 132 | bank 4 region (ringed enemy) |
| Sharlin | Galaxy | 136 | — |
| Spindow | Galaxy | 414 | 24×24, largest — likely boss-class |
| Shamir | Asteroid | 160 | — |
| Ufolick | Asteroid | 161 | — |
| Burdle | Asteroid | 156 | — |
| Ashion | Asteroid | 129 | — |
| Tinker | Asteroid | 93 | smallest |
| Dririt | Nebula | 112 | — |
| Arbleby | Nebula | 200 | — |
| Tricker | Nebula | 156 | — |

### Naming note (bosses)

The StrategyWiki guide names the three zone bosses **Zanoni** (Galaxy),
**Nebiros** (Asteroid), **Belzebul** (Nebula). SMS Power lists per-zone enemy sets
under different names (Mother Boon, Aster, Caborn…). The correspondence isn't
1:1 and isn't asserted here; Spindow (414 dots) is the largest ripped sprite and
is boss-class. Boss sprites are large multi-part objects — resolving them is part
of the per-handler decode.

### Type ↔ name mapping (in progress)

The 16-entry dispatch table at `0x0518` holds: type 1 = player; types 2–15 =
enemies / bosses / effects. Confirmed sprite locations so far map Curos and the
ringed "Cult" into bank 4. Completing the type→name→tiles map is the per-handler
decode (read each handler's tile base + frame table + per-sprite X/Y offsets),
which also yields exact full-size sprites and their per-object palettes — closing
the sub-tile-alignment gap that defeats block matching for the complex sprites.

---

## Appendix C — Reverse-engineering map (entity engine + ROM)


All addresses confirmed by tracing the code. This is the spec the modern entity /
sprite system should mirror, and the map needed to finish per-object extraction.

### Shadow SAT (RAM 0xC400)

The game maintains a shadow Sprite Attribute Table in work RAM and DMAs it to
VRAM every frame:

| RAM | Size | Contents |
|---|---|---|
| `0xC400`–`0xC43F` | 64 B | sprite **Y** coordinates (one per hardware sprite) |
| `0xC480`–`0xC4FF` | 128 B | 64 × (**X**, **tile#**) pairs |

`Y = 0xD0` terminates the active sprite list (SMS convention). The "hide all
sprites" routine at `0x05D9` writes `0xD0` to `0xC400`.

### Sprite DMA — `sub_0394`

Runs each frame from the VBlank ISR:

```
0394: LD HL,0x7F00 ; VRAM SAT base
0397: RST 0x18      ; set VDP write address = HL
0398: LD HL,0xC400  ; shadow SAT (Y)
039B: LD BC,0x40BE  ; 64 bytes -> port 0xBE
039E: OTIR
03A0: LD HL,0x7F80 ; VRAM SAT + 0x80 (X/tile section)
03A4: LD HL,0xC480  ; shadow SAT (X,tile)
03A9: OTIR (0x80)
```

`RST 0x18` (`0x0018`) = output L then H to port `0xBF` — i.e. set the VDP address
register. Used everywhere as "point VRAM at HL."

### Entities

Object pools of fixed-size structs:

| Pool | Purpose | Stride | Count |
|---|---|---|---|
| `0xC600` | player + main enemies | `0x40` | up to `0x28` (40) |
| `0xC6C0` | sub-objects / formation members | `0x40` | 6 |
| `0xCFC0` | additional pool (alternate-frame processed) | `0x40` | — |

#### Entity struct (0x40 bytes) — confirmed fields

| Offset | Field |
|---|---|
| `+0x00` | type / state (0 = inactive; index into the dispatch table) |
| `+0x01` | flags (bit 7 = initialised; seen `0x80` / `0xA0`) |
| `+0x02` | movement-direction control bits (rotated to test each axis) |
| `+0x08` / `+0x09` | **X** position lo / hi (8.8 fixed-point) |
| `+0x0A` / `+0x0B` | **Y** position lo / hi |
| `+0x0C` / `+0x0D` | **X** velocity lo / hi |
| `+0x0E` / `+0x0F` | **Y** velocity lo / hi |
| `+0x1E` | active / visibility flag |

Movement (handler `0x0416`) adds velocity to position with per-axis enable bits
from `+0x02`, and culls when position leaves the playfield.

### Type dispatch — jump table at `0x0518`

Each frame, for each active entity, `A = entity[0]`, then jump via
`table[A]` (16 entries, 2 bytes each):

| Type | Handler | Likely role |
|---|---|---|
| 0 | `0x04FA` | inactive / skip |
| 1 | `0x0807` | **player ship** |
| 2–9 | `0x0AB2 … 0x0BD4` | enemy variants |
| 10 | `0x1F9A` | (boss / large) |
| 11–15 | `0x0FF9 … 0x0C0B` | bullets / effects / bosses |

#### Player handler `0x0807` (worked sample)

Init sets start position (`+0x09`=Y `0x90`, `+0x0B`=X `0x80`); animation runs off
a counter at `0xC229` indexing frame tables at `0x0C98` / `0x0CA8` (chosen by
facing flag `0xC250`); ship graphics are paged in from window addresses
`0xAA00` / `0xB100` (i.e. from a banked ROM page) and uploaded to VRAM tiles.

**Implication:** sprites are assembled *procedurally* with animation — there is no
single static "metasprite shape table" to parse. Exact per-object pixel extents
come from decoding each type handler's draw path (its tile base + frame table +
width/height). That's a type-by-type job; this map makes it tractable.

### Separate tile-object layer — `sub_2534`

Distinct from hardware sprites: walks the entity pool and draws tile objects into
the **name table** at VRAM `0x3800` (used for the scrolling field / large terrain
objects). Computes `0x3800 + (row<<6) + col` style addresses.

### What this means for the port

The modern entity system should model: a fixed-size entity record with
type/flags/pos(8.8)/vel, a per-type update+draw dispatch, a shadow-SAT list with a
`Y=0xD0` terminator, and a separate tilemap-object layer. See `src/core/` — the
`GameState`/subsystem split already mirrors this; the field offsets above let it be
made faithful.

### Status of sprite extraction

- 16×16 metasprites (column-major 8×16 pairs): **done**, correct for standard
  enemies — see `assets/gfx/sprites/`.
- Exact full-size objects (player ship, bosses, multi-cell enemies): requires the
  per-type handler decode above. A heuristic full-size pass exists
  (`assets/gfx/sprites/_experimental_fullsize_overview.png`) but is unreliable on
  runs that hold multiple objects or animation frames.

---

## Appendix D — ROM format notes


Reference for the extraction tooling and the reimplementation. Values marked
**[confirmed]** were decoded from the ROM; the rest is the standard SMS model.

### Header (`0x7FF0`) [confirmed]
`TMR SEGA` signature, product code 569, Export region, 128 KB size code, checksum
`0x7511` which **validates** over the whole image (a properly mastered ROM).

### Banking [confirmed]
Sega mapper. Three 16 KB slots in CPU space:

| Slot | CPU range | Contents |
|---|---|---|
| 0 | `0x0000-3FFF` | bank 0 (fixed) — program |
| 1 | `0x4000-7FFF` | bank 1 (fixed) — program + data |
| 2 | `0x8000-BFFF` | **paged** — selected by writing `0xFFFF` |

Mapper control registers live at `0xFFFC-0xFFFF`. This title pages data/graphics
into slot 2 via `0xFFFF` (8 switch sites found). Slots 0/1 stay on banks 0/1.

### Tile graphics [confirmed]
8×8, **4bpp planar**, 32 bytes/tile. Each row = 4 bytes (one per bitplane);
pixel color = bitplane bits combined into a 0–15 index. Decoder:

```
for row in 0..8:
    b0,b1,b2,b3 = data[off + row*4 : off + row*4 + 4]
    for x in 0..8:
        bit = 7 - x
        color = (b0>>bit&1) | (b1>>bit&1)<<1 | (b2>>bit&1)<<2 | (b3>>bit&1)<<3
```

Tiles in this ROM are **uncompressed** — they decode directly (banks 4–5 hold the
sprite/UI graphics; the `©SEGA 1986` logo tiles are in bank 5).

### Palette (CRAM)
32 entries: 0–15 background, 16–31 sprite. Each entry one byte `--BBGGRR`
(2 bits/channel). 8-bit conversion: `channel * 85`. The code uploads palettes
from ROM tables; `tools/extract_gfx.py` lists candidate tables in
`palette_candidates.txt`. Exact per-screen colors require matching each palette
upload to the screen that uses it (phase 1). The **active sprite palette** for the
Astro Warrior gameplay is the table at **ROM 0x1131** (CRAM 16–31 half of the
32-entry table at 0x1121) — verified against SMS Power rips, e.g. Curos at 100%.

### Sprites (SAT)
Up to 64 hardware sprites, 8×8 or 8×16, from the Sprite Attribute Table in VRAM.
This title uses **8×16 sprites paired into 16×16 metasprites**, stored in
**column-major** tile order (TL, BL, TR, BR) — confirmed by re-assembling against
known rips. Row-major splits every sprite. Hardware limit: **8 sprites per
scanline** (extras drop → flicker), which shaped enemy counts/layout, so faithful
mode can optionally re-impose it.

> Identity: the ROM is the **Hang-On / Astro Warrior** combo cart (©SEGA 1986),
> which is why both a vertical space shooter (Astro Warrior) and motorcycle-racer
> graphics (Hang-On) appear in the banks. Bank 4 holds the Astro Warrior sprites.

### Audio (PSG) [confirmed]
SN76489: 3 square-tone channels (10-bit divider) + 1 noise, 4-bit volume each.
Driven by writes to `OUT (0x7F)` (11 sites). Music = a driver ticking these
registers from pattern tables in the data banks.

### Input [confirmed]
Controller ports `IN (0xDC)` / `IN (0xDD)`, active-low button bits, polled once
per frame inside the VBlank ISR.

### Execution model [confirmed]
Reset at `0x0000`: `DI` → `IM 1` → `LD SP,0xDFFE` → clear RAM (`LDIR`) → init HW →
`JP 0x1D40`. VBlank interrupt (vector `0x38`) → `0x030F`, which saves all
registers, polls input, bumps the frame counter at `0xC01C`, runs the per-frame
subsystems, and returns. The interrupt **is** the frame tick.

---

## Appendix E — External sources

- **Gameplay guide:** StrategyWiki — *Astro Warrior*
  <https://strategywiki.org/wiki/Astro_Warrior>
- **Sprite rips & official names:** SMS Power — *Astro Warrior (SMS)* sprites
  <https://www.smspower.org/Sprites/AstroWarrior-SMS>
- **Stack:** SwiftUI `SpriteView` hosting `SKScene`
  <https://developer.apple.com/documentation/spritekit/spriteview> ·
  Swift 6 strict concurrency + `@Observable` (current 2026 iOS practice) ·
  SpriteKit for 2D, Metal as the custom-rendering upgrade.
- **Original:** Hang-On / Astro Warrior combo cart, © SEGA 1986 (SMS).
