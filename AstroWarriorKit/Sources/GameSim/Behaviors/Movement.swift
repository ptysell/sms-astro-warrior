import Foundation

// Movement strategy objects (§5.4).
//
// Wave-2a — enemy motion now follows the ROM's MAGNITUDE + DIRECTION model
// (docs/rom-decode-systems.md §"Enemy movement model"): a behavior sets the enemy's
// per-axis step magnitude (stepX/stepY) and a 4-bit direction field (dirMask), and a
// SINGLE shared integrator (Integrator.apply, ported from ROM 0x0416) advances the
// position with a sign chosen by the direction bits, despawning on the ROM off-screen
// bounds. Legacy behaviors (Descend/Weave/Dive/FormationHold) still write position
// directly and leave dirMask == 0, so the integrator is a no-op for them.
public protocol MovementBehavior {
    func step(_ e: Enemy, _ ctx: SimContext)
}

// ROM +0x02 direction bitfield (integrated at 0x0416). Bit → screen-space sign.
public enum MoveDir {
    public static let up: UInt8    = 0x01   // ROM Y− (screen up)
    public static let down: UInt8  = 0x02   // ROM Y+ (screen down)
    public static let left: UInt8  = 0x04   // ROM X−
    public static let right: UInt8 = 0x08   // ROM X+
}

// The shared per-frame position integrator — ROM 0x0416 (the dispatcher pushes its
// return address at 0x0405 so it runs after every type handler). Applies |vy| along the
// Y direction bit and |vx| along the X direction bit, then despawns on the ROM bounds:
// screen-Y ≥ 200, X < 16, X ≥ 248. Sim logical space is +Y up, so screen-Y = LOGICAL_HEIGHT − y.
public enum Integrator {
    public static func apply(to e: Enemy) {
        let m = e.dirMask
        if m == 0 { return }                         // legacy behaviors move themselves
        if m & MoveDir.down != 0 {
            e.position.y -= e.stepY                   // screen-down = logical −y
            if LOGICAL_HEIGHT - e.position.y >= Tuning.despawnScreenY { e.isDead = true; return }
        } else if m & MoveDir.up != 0 {
            e.position.y += e.stepY
        }
        if m & MoveDir.right != 0 {
            e.position.x += e.stepX
            if e.position.x >= Tuning.despawnXHigh { e.isDead = true }
        } else if m & MoveDir.left != 0 {
            e.position.x -= e.stepX
            if e.position.x < Tuning.despawnXLow { e.isDead = true }
        }
    }
}

// ─────────────────────────────── legacy primitives (Asteroid/Nebula, best-fit) ───────────────

public struct Descend: MovementBehavior {        // straight down
    public let speed: Double
    public init(speed: Double) { self.speed = speed }
    public func step(_ e: Enemy, _ ctx: SimContext) {
        e.position.y -= speed                      // +Y is up the field; enemies descend
    }
}

public struct Weave: MovementBehavior {          // sinusoidal
    public let speed, amp, freq: Double
    public init(speed: Double, amp: Double, freq: Double) {
        self.speed = speed; self.amp = amp; self.freq = freq
    }
    public func step(_ e: Enemy, _ ctx: SimContext) {
        e.position.y -= speed
        e.position.x = e.anchorX + amp * sin(Double(e.age) * freq)
    }
}

public struct Dive: MovementBehavior {           // descends, then homes toward player once
    public let speed: Double
    public let lockAt: Double                      // y at which it commits its dive heading
    public init(speed: Double, lockAt: Double = LOGICAL_HEIGHT * 0.75) {
        self.speed = speed; self.lockAt = lockAt
    }
    public func step(_ e: Enemy, _ ctx: SimContext) {
        if !e.headingLocked {
            e.position.y -= speed                  // straight descent until the commit line
            if e.position.y <= lockAt {
                let d = ctx.world.player.position - e.position
                let len = d.length
                e.velocity = len > 0.0001 ? (d / len) * speed : Vec2(0, -speed)
                e.headingLocked = true
            }
        } else {
            e.position += e.velocity                // committed straight-line dive
        }
    }
}

public struct FormationHold: MovementBehavior {  // keeps slot relative to a wave anchor
    public let speed: Double
    public init(speed: Double = 0) { self.speed = speed }
    public func step(_ e: Enemy, _ ctx: SimContext) { e.position.y -= speed }
}

// ─────────────────────────── ROM magnitude+direction behaviors (Galaxy) ──────────────────────

// cult (romType 0x15 @0x4842). Init sets no velocity; state0 AIMS at the player (constant
// 1.875 px/f split by angle, ROM 0x18fd), then the aim is held and |vx| drifts toward centre:
// state1 subtracts 0x0020 (0.125 px/f) every 16 frames until it crosses 0, flips the horizontal
// direction, and state2 rebuilds |vx| at 0x0008 (0.03125 px/f) per frame. |vy| stays fixed → a
// clean aimed descent. (docs §velocity "cult".)
public struct AimConverge: MovementBehavior {
    public init() {}
    public func step(_ e: Enemy, _ ctx: SimContext) {
        if !e.motionInited {
            Aim.lock(e, toward: ctx.world.player.position)   // set |vx|,|vy| + direction once
            e.motionInited = true
            e.motionPhase = 1
            e.phaseTimer = 0
            return
        }
        switch e.motionPhase {
        case 1:                                              // decay |vx| toward centre
            e.phaseTimer += 1
            if e.phaseTimer >= 16 {
                e.phaseTimer = 0
                e.stepX -= Tuning.cultVXDecayPer16
                if e.stepX <= 0 {
                    e.stepX = 0
                    if e.dirMask & MoveDir.right != 0 {
                        e.dirMask = (e.dirMask & ~MoveDir.right) | MoveDir.left
                    } else if e.dirMask & MoveDir.left != 0 {
                        e.dirMask = (e.dirMask & ~MoveDir.left) | MoveDir.right
                    }
                    e.motionPhase = 2
                }
            }
        case 2:                                              // rebuild |vx| the other way
            e.stepX += Tuning.cultVXRebuildPerF
        default: break
        }
    }
}

// zanix (romType 0x16 @0x48E4). Constant 0.5 px/f descent with a horizontal PENDULUM sweep:
// |vx| ramps down to 0 then back up to 1.5 px/f at accel 0.25 px/f² (0x0040/f), FLIPPING the X
// direction bit at each |vx| zero-crossing — so the enemy sweeps left↔right around its column
// while descending slowly (net ≈ centred, long-lived, exits the BOTTOM after ~400 f).
//
// GROUND-TRUTH NOTE (2026-09, ROMDBG census over idx12–14): the ROM zanix genuinely OSCILLATE —
// a tracked member sweeps X ≈ 124→130→118→103→92→100→115→129→112→97→92→106… around a stable
// centre, its X PEAKS at ~227 and NEVER reaches the despawn edge (X≥248), and it descends 0.5 px/f
// to y≈199 and exits the BOTTOM at ~400 f. So a left↔right flip IS faithful. (A drift-only
// down+right model was investigated: it makes zanix exit the right edge in ~50–160 f and cannot
// reproduce the ROM's steady 8-on-field hold across idx12–14 — it is the LESS faithful model.
// The flip lives in an early zanix state, 0x4925/0x4932, not in the state2/state3 that only pulse
// |vx|.) This pendulum is kept because it matches the measured ROM, not to inflate the metric.
public struct ZanixSweep: MovementBehavior {
    public init() {}
    public func step(_ e: Enemy, _ ctx: SimContext) {
        if !e.motionInited {
            e.dirMask = MoveDir.down | MoveDir.right
            e.stepY = Tuning.zanixDescend
            e.stepX = Tuning.zanixMaxVX
            e.motionInited = true
            e.motionPhase = 2                                // start by ramping |vx| down
            return
        }
        switch e.motionPhase {
        case 2:                                              // decelerate to 0, then flip & rebuild
            e.stepX -= Tuning.zanixVXAccel
            if e.stepX <= 0 {
                e.stepX = 0
                if e.dirMask & MoveDir.right != 0 {
                    e.dirMask = (e.dirMask & ~MoveDir.right) | MoveDir.left
                } else {
                    e.dirMask = (e.dirMask & ~MoveDir.left) | MoveDir.right
                }
                e.motionPhase = 3
            }
        case 3:                                              // accelerate back up to the cap
            e.stepX += Tuning.zanixVXAccel
            if e.stepX >= Tuning.zanixMaxVX { e.stepX = Tuning.zanixMaxVX; e.motionPhase = 2 }
        default: break
        }
    }
}

// delta (romType 0x19 @0x4B7E). 2.0 px/f descent with a triangular horizontal sweep (accel
// 0.125 px/f²): builds |vx| up to a cap, then reduces it to 0 and flips the horizontal
// direction. UNLIKE the other Galaxy grunts delta's aimed fire is NOT loop-gated (fires on
// loop 1) — see Bestiary. (docs §velocity "delta".)
public struct DeltaSweep: MovementBehavior {
    public init() {}
    public func step(_ e: Enemy, _ ctx: SimContext) {
        if !e.motionInited {
            e.dirMask = MoveDir.down | MoveDir.right
            e.stepY = Tuning.deltaDescend
            e.stepX = 0
            e.motionInited = true
            e.motionPhase = 1                                // building |vx|
            return
        }
        switch e.motionPhase {
        case 1:
            e.stepX += Tuning.deltaVXAccel
            if e.stepX >= Tuning.deltaMaxVX { e.stepX = Tuning.deltaMaxVX; e.motionPhase = 3 }
        case 3:
            e.stepX -= Tuning.deltaVXAccel
            if e.stepX <= 0 {
                e.stepX = 0
                if e.dirMask & MoveDir.right != 0 {
                    e.dirMask = (e.dirMask & ~MoveDir.right) | MoveDir.left
                } else {
                    e.dirMask = (e.dirMask & ~MoveDir.left) | MoveDir.right
                }
                e.motionPhase = 1
            }
        default: break
        }
    }
}

// kyra (romType 0x22 @0x5150). Dives straight down at 3.0 px/f; on reaching the player's row
// it turns up-and-toward the player's column and accelerates horizontally (0.125 px/f²) until
// aligned, then dives again. (docs §velocity "kyra".)
public struct KyraSwoop: MovementBehavior {
    public init() {}
    public func step(_ e: Enemy, _ ctx: SimContext) {
        let player = ctx.world.player.position
        if !e.motionInited {
            e.dirMask = MoveDir.down
            e.stepY = Tuning.kyraDive
            e.stepX = 0
            e.motionInited = true
            e.motionPhase = 0
            return
        }
        switch e.motionPhase {
        case 0:                                              // dive until at/below player row
            if e.position.y <= player.y {
                let horiz: UInt8 = player.x >= e.position.x ? MoveDir.right : MoveDir.left
                e.dirMask = MoveDir.up | horiz
                e.stepX = 0
                e.motionPhase = 1
            }
        case 1:                                              // home horizontally on player-X
            e.stepX += Tuning.kyraVXAccel
            if abs(player.x - e.position.x) < 4 {
                e.dirMask = MoveDir.down                      // re-dive
                e.stepY = Tuning.kyraDive
                e.motionPhase = 0
            }
        default: break
        }
    }
}

// gyron (romType 0x27 @0x5577). Enters at 2.0 px/f with |vx| preset to 2.0, then walks an
// 8-direction rotation script (full CW turn, 4 frames each) so it orbits/spirals; afterwards
// it accelerates horizontally (0.09375 px/f²). (docs §velocity "gyron".)
public struct GyronSpiral: MovementBehavior {
    // ROM rotation script 0x52E2 (CW): dir sequence, 4 frames each.
    static let rotation: [UInt8] = [0x08, 0x09, 0x01, 0x05, 0x04, 0x06, 0x02, 0x0A]
    public init() {}
    public func step(_ e: Enemy, _ ctx: SimContext) {
        if !e.motionInited {
            e.dirMask = MoveDir.down
            e.stepY = Tuning.gyronSpeed
            e.stepX = Tuning.gyronSpeed
            e.motionInited = true
            e.motionPhase = 0                                // rotation-script index
            e.phaseTimer = 0
            return
        }
        if e.motionPhase < Self.rotation.count * 2 {         // two full CW turns of spiral
            e.dirMask = Self.rotation[e.motionPhase % Self.rotation.count]
            e.phaseTimer += 1
            if e.phaseTimer >= 4 { e.phaseTimer = 0; e.motionPhase += 1 }
        } else {                                             // then accelerate horizontally
            e.dirMask = MoveDir.down | MoveDir.right
            e.stepX += Tuning.gyronVXAccel
        }
    }
}
