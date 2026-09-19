import Foundation

// Wave-3b — ROM magnitude+direction movers for the 12 Asteroid/Nebula enemies.
//
// Until now these enemies used the legacy placeholders (Descend/Weave/Dive/FormationHold), which set
// dirMask == 0 and slide the position directly — bypassing the shared ROM integrator and using best-fit
// speeds. That is the dominant driver of the Asteroid/Nebula parity gap (ParityScore 47.8 / 40.8 vs
// Galaxy 3.5). These movers replace them with the ROM's exact magnitude+direction model: each sets the
// per-axis step magnitude (stepX/stepY) and the 4-bit dirMask, and the shared Integrator (ROM 0x0416)
// advances the position and despawns on the ROM bounds — identical to the Galaxy movers in Movement.swift.
//
// Every number is ROM-EXACT (docs/rom-decode-systems.md §velocity + the Sweep-1 astneb-decode-spec
// decode/verify workflow, all independently re-derived from the ROM bytes). The ROM loop gate
// "0xC240 >= 3" (second lap onward) maps to Campaign.loop >= 1; on the parity target (loop 0) the
// loop-gated branches are OFF, so those handlers do not fire and speeds stay at their first-lap values.

@inline(__always) private func loopHeavy(_ ctx: SimContext) -> Bool { ctx.world.campaign.loop >= 1 }

// ─────────────────────────────── Asteroid ───────────────────────────────

// shamir (0x17 @0x49AC). Descend straight down at 1.0 px/f until it passes below the player's row, then
// a homing RAM at 0.9375 px/f (the aim unit halved), re-aimed toward the live player every 8 frames.
// Never fires (NoAttack). (ROM state machine: 0x49F3 descend → 0x4A10 ram.)
public struct ShamirRam: MovementBehavior {
    public init() {}
    public func step(_ e: Enemy, _ ctx: SimContext) {
        if !e.motionInited {
            e.motionInited = true
            e.dirMask = MoveDir.down
            e.stepY = Tuning.shamirDescend        // 1.0
            e.stepX = 0
            e.motionPhase = 1
            return
        }
        switch e.motionPhase {
        case 1:                                    // descend until below the player row
            if e.position.y < ctx.world.player.position.y {
                e.motionPhase = 2
                e.phaseTimer = Tuning.shamirReaimEvery
                Aim.lock(e, toward: ctx.world.player.position, speed: Tuning.shamirRamSpeed)
            }
        case 2:                                    // homing ram, re-aimed every 8 frames
            e.phaseTimer -= 1
            if e.phaseTimer <= 0 {
                e.phaseTimer = Tuning.shamirReaimEvery
                Aim.lock(e, toward: ctx.world.player.position, speed: Tuning.shamirRamSpeed)
            }
        default: break
        }
    }
}

// aster (0x1B @0x4D66). All 6 members launch from screen-centre (X=128) as a diagonal burst: |vx|=4.0,
// |vy|=2.0, each heading down-left or down-right (per member), and |vx| decelerates per-member until 0,
// then a straight 2.0 fall. Per-member (dir, decel) come from the ROM wave record (memberIndex 0..5).
public struct AsterFan: MovementBehavior {
    public init() {}
    public func step(_ e: Enemy, _ ctx: SimContext) {
        if !e.motionInited {
            e.motionInited = true
            e.position.x = 128                      // ROM forces X=128 (ignores the record X)
            e.anchorX = 128
            let i = e.memberIndex % 6
            let right = Tuning.asterMemberRight[i]
            e.dirMask = MoveDir.down | (right ? MoveDir.right : MoveDir.left)
            e.stepX = Tuning.asterVX
            e.stepY = loopHeavy(ctx) ? 3.0 : Tuning.asterVY   // vy 3.0 needs loop>=3 AND a powerup (loop-0: 2.0)
            e.motionPhase = 0
            return
        }
        if e.motionPhase == 0 {                     // decelerate |vx| to a straight fall
            e.stepX -= Tuning.asterMemberDecel[e.memberIndex % 6]
            if e.stepX <= 0 {
                e.stepX = 0
                e.dirMask = MoveDir.down
                e.motionPhase = 1
            }
        }
    }
}

// ashion (0x1D @0x4DE5). Straight-down descent at 2.0 px/f. (The ROM's on-hit +4px dodge + speed-up to
// 4.0 is a collision-response the sim can't yet express per-hit; modeled as hp:2 in the Bestiary.)
// Fire is loop-gated → silent on loop 0 (NoAttack).
public struct AshionDrop: MovementBehavior {
    public init() {}
    public func step(_ e: Enemy, _ ctx: SimContext) {
        if !e.motionInited {
            e.motionInited = true
            e.dirMask = MoveDir.down
            e.stepY = Tuning.ashionDescend         // 2.0
            e.stepX = 0
        }
    }
}

// burdle (0x1E @0x4EA7). Descend 2.0; when it reaches 32px above the player's row, a 16-frame diagonal
// veer (|vx|=|vy|=2.0) toward the player's side, then reverts to a straight fall (does not re-veer).
// Fire is loop-gated → silent on loop 0 (NoAttack).
public struct BurdleVeer: MovementBehavior {
    public init() {}
    public func step(_ e: Enemy, _ ctx: SimContext) {
        if !e.motionInited {
            e.motionInited = true
            e.dirMask = MoveDir.down
            e.stepY = Tuning.burdleDescend         // 2.0
            e.stepX = 0
            e.motionPhase = 1
            return
        }
        switch e.motionPhase {
        case 1:                                    // descend until 32px above the player row
            if e.position.y <= ctx.world.player.position.y + Tuning.burdleTriggerAbove {
                e.motionPhase = 2
                e.phaseTimer = Tuning.burdleVeerFrames
                e.stepX = Tuning.burdleVeer
                let right = ctx.world.player.position.x >= e.position.x
                e.dirMask = MoveDir.down | (right ? MoveDir.right : MoveDir.left)
            }
        case 2:                                    // 16-frame veer, then straight down
            e.phaseTimer -= 1
            if e.phaseTimer <= 0 {
                e.dirMask = MoveDir.down
                e.stepX = 0
                e.motionPhase = 3
            }
        default: break
        }
    }
}

// tinker (0x21 @0x50C3). After its spawn delay it aims at the player (unit 1.875) and multiplies BOTH
// components by a random scale, then coasts in a straight line. The scale index is hardware-random in
// the ROM, so we draw it from the deterministic sim RNG (parity is a speed DISTRIBUTION, not per-spawn).
public struct AimScaleDive: MovementBehavior {
    public init() {}
    public func step(_ e: Enemy, _ ctx: SimContext) {
        guard !e.motionInited else { return }      // one-shot aim, then coast (integrator carries it)
        e.motionInited = true
        let scales = loopHeavy(ctx) ? Tuning.tinkerScalesLoopHi : Tuning.tinkerScalesLoop0
        let scale = scales[ctx.world.rng.int(scales.count)]
        Aim.lock(e, toward: ctx.world.player.position, speed: Tuning.aimUnitSpeed * scale)
    }
}

// ufolick (0x24 @0x5302). Enters from the edge OPPOSITE the player, descends 2.0, and at the player's
// row flips to UP, doubles to 4.0, and fires a one-shot 6-shot fan (see UfolickBurst).
public struct EdgeEntryReverse: MovementBehavior {
    public init() {}
    public func step(_ e: Enemy, _ ctx: SimContext) {
        if !e.motionInited {
            e.motionInited = true
            let playerRight = ctx.world.player.position.x >= 128
            e.position.x = playerRight ? Tuning.ufolickEntryLeftX : Tuning.ufolickEntryRightX
            e.anchorX = e.position.x
            e.enteredLeft = playerRight
            e.dirMask = MoveDir.down
            e.stepY = Tuning.ufolickDescend        // 2.0
            e.stepX = 0
            e.motionPhase = 0
            return
        }
        if e.motionPhase == 0, e.position.y < ctx.world.player.position.y {
            e.dirMask = MoveDir.up
            e.stepY = Tuning.ufolickClimb          // 4.0
            e.motionPhase = 1
            e.fireBurst = true                     // signal UfolickBurst to fire once
        }
    }
}

// ─────────────────────────────── Nebula ───────────────────────────────

// caborn (0x1F @0x4F41, INDESTRUCTIBLE) & triat (0x25 @0x5428, 8-HP): pure straight-down integrator
// descent, no horizontal motion, ever. Speed 1.0 (1.5 on loop>=3). Replaces the legacy Descend, which
// bypassed the integrator + ROM despawn bounds.
public struct StraightDescend: MovementBehavior {
    public let loSpeed: Double
    public let hiSpeed: Double
    public init(lo: Double, hi: Double) { self.loSpeed = lo; self.hiSpeed = hi }
    public func step(_ e: Enemy, _ ctx: SimContext) {
        if !e.motionInited {
            e.motionInited = true
            e.dirMask = MoveDir.down
            e.stepX = 0
            e.stepY = loopHeavy(ctx) ? hiSpeed : loSpeed
        }
    }
}

// tricker (0x26 @0x54B8). Enters at an edge column at 2.0 px/f down; on reaching the player's row it
// begins a random vertical jitter (up/down/freeze, re-rolled every 32 frames). Aimed fire is a separate
// AttackBehavior (AimedShot) — faithful enough for the loop-0 threat curve.
public struct TrickerDrop: MovementBehavior {
    public init() {}
    public func step(_ e: Enemy, _ ctx: SimContext) {
        if !e.motionInited {
            e.motionInited = true
            e.dirMask = MoveDir.down
            e.stepY = Tuning.trickerDescend        // 2.0
            e.stepX = 0
            e.motionPhase = 0
            return
        }
        switch e.motionPhase {
        case 0:                                    // descend until screenY>=160 or the player's row (ROM 0x550E)
            let screenY = LOGICAL_HEIGHT - e.position.y
            if screenY >= 160 || abs(e.position.y - ctx.world.player.position.y) < 2 {
                e.motionPhase = 1
                e.phaseTimer = 0
            }
        case 1:                                    // random vertical jitter, held between re-rolls
            e.phaseTimer -= 1
            if e.phaseTimer <= 0 {
                e.phaseTimer = loopHeavy(ctx) ? (Tuning.trickerJitterEvery / 2) : Tuning.trickerJitterEvery
                switch ctx.world.rng.int(4) {
                case 1:  e.dirMask = MoveDir.up
                case 2:  e.dirMask = MoveDir.down
                default: e.dirMask = 0             // 0 or 3 → freeze (3 also fires, via AimedShot)
                }
            }
        default: break
        }
    }
}

// arbleby (0x1A @0x4C64). A swooping chaser: enters 32px to one side of the player at 2.5 px/f down,
// accelerates horizontally (0.125 px/f²) onto the player's column, overshoots at 1.5 px/f, then hovers
// 16f and mirror-sweeps back — an oscillating multi-pass. Fires aimed UNGATED (loop-1 included).
public struct ArblebySwoop: MovementBehavior {
    public init() {}
    public func step(_ e: Enemy, _ ctx: SimContext) {
        let player = ctx.world.player.position
        if !e.motionInited {
            e.motionInited = true
            e.stepY = Tuning.arblebyDive           // 2.5
            e.stepX = 0
            if player.x >= 128 {
                e.position.x = player.x - Tuning.arblebyEntryOffset
                e.dirMask = MoveDir.down | MoveDir.right
            } else {
                e.position.x = player.x + Tuning.arblebyEntryOffset
                e.dirMask = MoveDir.down | MoveDir.left
            }
            e.anchorX = e.position.x
            e.motionPhase = 1
            return
        }
        switch e.motionPhase {
        case 1:                                    // dive-chase: accelerate X until crossing player col
            e.stepX += Tuning.arblebyXAccel
            let crossed = (e.dirMask & MoveDir.right != 0) ? (e.position.x >= player.x)
                                                           : (e.position.x <= player.x)
            if crossed {
                e.stepY = Tuning.arblebySweep      // 1.5
                e.stepX = Tuning.arblebySweep
                e.motionPhase = 2
                e.phaseTimer = 24                  // ~cross duration before hover (geometry-derived)
            }
        case 2:                                    // overshoot sweep, then hover
            e.stepX += Tuning.arblebyXAccel
            e.phaseTimer -= 1
            if e.phaseTimer <= 0 {
                e.dirMask = 0                       // hover (frozen)
                e.motionPhase = 3
                e.phaseTimer = Tuning.arblebyHoverFrames
            }
        case 3:                                    // hover, then mirror-sweep back (multi-pass)
            e.phaseTimer -= 1
            if e.phaseTimer <= 0 {
                let goRight = ctx.world.player.position.x >= e.position.x
                e.dirMask = MoveDir.down | (goRight ? MoveDir.right : MoveDir.left)
                e.stepY = Tuning.arblebySweep
                e.stepX = Tuning.arblebySweep
                e.motionPhase = 2
                e.phaseTimer = 24
            }
        default: break
        }
    }
}

// dririt (0x20 @0x4FB5, splitter). Picks a random speed S applied to BOTH axes; descends 16 frames then
// enters a mirrored diagonal and SPAWNS a mirror child (dir = parent XOR left/right), repeating until it
// descends past screenY 128. Children cascade the same way; the 12-slot pool cap bounds the total.
public struct DriritSplit: MovementBehavior {
    public init() {}
    private func rollSpeed(_ ctx: SimContext) -> Double {
        let t = loopHeavy(ctx) ? Tuning.driritSpeedsLoopHi : Tuning.driritSpeedsLoop0
        return t[ctx.world.rng.int(t.count)]
    }
    public func step(_ e: Enemy, _ ctx: SimContext) {
        if !e.motionInited {                        // fresh wave-spawned PARENT
            e.motionInited = true
            let s = rollSpeed(ctx)
            e.stepX = s; e.stepY = s
            e.dirMask = MoveDir.down
            e.phaseTimer = Tuning.driritDescendFrames
            e.motionPhase = 0
            return
        }
        switch e.motionPhase {
        case 0:                                     // straight descent, count down to the split
            e.phaseTimer -= 1
            if e.phaseTimer <= 0 {
                let d: UInt8 = (ctx.world.rng.next() & 1) == 0
                    ? (MoveDir.down | MoveDir.right) : (MoveDir.down | MoveDir.left)
                e.dirMask = d
                ctx.world.spawnPoolEnemy(Bestiary.dririt, at: e.position) { child in
                    child.motionInited = true
                    let cs = self.rollSpeed(ctx)
                    child.stepX = cs; child.stepY = cs
                    child.dirMask = d ^ 0x0C        // mirror: swap left/right bits, keep down
                    child.motionPhase = 1
                    child.phaseTimer = loopHeavy(ctx) ? 1 : Tuning.driritSplitDwell
                }
                e.phaseTimer = loopHeavy(ctx) ? 1 : Tuning.driritSplitDwell
                e.motionPhase = 1
            }
        case 1:                                     // diagonal dwell → revert to descent (or freeze)
            e.phaseTimer -= 1
            if e.phaseTimer <= 0 {
                if (LOGICAL_HEIGHT - e.position.y) >= Tuning.driritYStopScreen {
                    e.dirMask = MoveDir.down          // stop splitting; ride straight down to despawn
                    e.motionPhase = 2
                } else {
                    e.dirMask = MoveDir.down
                    e.phaseTimer = Tuning.driritDescendFrames
                    e.motionPhase = 0
                }
            }
        default: break                              // state 2: hold last velocity to despawn
        }
    }
}

// dilon (0x23 @0x51EB, carrier). Descends at 2.0, then hovers on an 8-direction orbit (the same rotation
// script gyron uses), launching a type-0x18 sharlin diver (flight-path 8 or 9) every ~32 frames.
public struct DilonCarrier: MovementBehavior {
    public init() {}
    public func step(_ e: Enemy, _ ctx: SimContext) {
        if !e.motionInited {
            e.motionInited = true
            e.dirMask = MoveDir.down
            e.stepY = Tuning.dilonSpeed             // 2.0
            e.stepX = Tuning.dilonSpeed
            e.motionPhase = 0
            e.phaseTimer = Tuning.dilonDescendFrames
            e.diverTimer = Tuning.dilonDiverEvery
            e.rotIndex = 0
            return
        }
        // Diver launch cadence (runs in every phase).
        e.diverTimer -= 1
        if e.diverTimer == 10 {
            ctx.world.spawnPoolEnemy(Bestiary.sharlin, at: e.position) { child in
                child.flightPathIndex = 8 | Int(ctx.world.rng.next() & 1)   // P8 or P9
                child.motionInited = false
                child.releaseDelay = 0
            }
        }
        if e.diverTimer <= 0 { e.diverTimer = Tuning.dilonDiverEvery }

        switch e.motionPhase {
        case 0:                                     // initial straight descent
            e.phaseTimer -= 1
            if e.phaseTimer <= 0 { e.motionPhase = 1; e.phaseTimer = 0 }
        case 1:                                     // 8-direction orbit (reuse gyron's rotation LUT)
            e.phaseTimer -= 1
            if e.phaseTimer <= 0 {
                e.rotIndex = (e.rotIndex + 1) & 7
                e.dirMask = GyronSpiral.rotation[e.rotIndex]
                e.phaseTimer = (e.rotIndex == 0) ? 12 : 4
            }
        default: break
        }
    }
}

// ─────────────────────────── new Asteroid/Nebula attacks ───────────────────────────

// triat (0x25) fixed 2-shot down-V spread every N frames (does NOT aim). Both bullets 1.875 px/f,
// symmetric ±~22.5° from straight-down (sim +Y up → down is −Y). (ROM table 0x54B4 via 0x537E.)
public struct SpreadFire: AttackBehavior {
    public let interval: Double
    public init(interval: Double) { self.interval = interval }
    public func step(_ e: Enemy, _ ctx: SimContext) {
        guard e.position.y < LOGICAL_HEIGHT else { return }
        let iv = ctx.world.campaign.loop >= 1 ? interval / 2 : interval
        if e.attackCooldown > 0 { e.attackCooldown -= 1; return }
        e.attackCooldown = iv
        for sx in [0.71484, -0.71484] {
            ctx.world.add(Bullet(at: e.position, velocity: Vec2(sx, -1.73047),
                                 side: .enemy, damage: 1, sprite: SpriteRef("ebullet")))
        }
    }
}

// ufolick (0x24) one-shot 6-shot fan, fired on the reversal frame (movement sets e.fireBurst). Modeled
// as a downward fan spread toward the player's half at the shared enemy-bullet 1.875 px/f. (ROM 0x5410.)
public struct UfolickBurst: AttackBehavior {
    public init() {}
    public func step(_ e: Enemy, _ ctx: SimContext) {
        guard e.fireBurst else { return }
        e.fireBurst = false
        let speed = Tuning.aimUnitSpeed
        // six shots fanned across the lower half (±40° from straight down), biased to the player's side.
        let angles: [Double] = [-40, -24, -8, 8, 24, 40]
        for deg in angles {
            let a = deg * .pi / 180
            ctx.world.add(Bullet(at: e.position,
                                 velocity: Vec2(sin(a) * speed, -cos(a) * speed),
                                 side: .enemy, damage: 1, sprite: SpriteRef("ebullet")))
        }
    }
}
