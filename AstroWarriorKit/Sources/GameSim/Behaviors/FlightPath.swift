import Foundation

// Stream flight-path script engine — ROM handler 0x18 stepper (@0x4AF0) + polar velocity LUT
// (bank6 @ CPU 0xA000 / file 0x1A000) + scripts (@0x4B6A → 0xA0A8..).
// See docs/rom-decode-systems.md §"Stream flight-path script engine".
//
// Galaxy "sharlin" streams (romType 0x18) follow a bytecode script: a list of 4-byte steps
// [duration, dirIndex→move-mask, spriteDelta, velByteOffset]. dirIndex selects a 4-bit move
// mask; velByteOffset (÷4) indexes the 42-entry polar LUT giving the (X,Y) step magnitudes.
// The mask supplies the sign/quadrant; the shared Integrator moves the position. The 4-byte
// header slot at each script's base is dropped exactly as the ROM does (first executed step =
// base+4). On the terminator the enemy HOLDS its last velocity until it exits the screen.

// One flight-script step: hold `mask`+LUT[`vel`] for `dur` frames.
public struct FlightStep: Sendable {
    public let dur: Int
    public let mask: UInt8      // ROM +0x02 move mask (via dir-index table 0x4B5F)
    public let vel: Int         // index into FlightData.velLUT
    public init(dur: Int, mask: UInt8, vel: Int) { self.dur = dur; self.mask = mask; self.vel = vel }
}

// Verbatim ROM data (LUT + all 10 scripts), ripped from AstroWarrior.sms bank6. Byte-exact.
public enum FlightData {
    // 42-entry polar velocity LUT — ripped VERBATIM from ROM bank6 @ file 0x1A000
    // (CPU 0xA000). Each entry (dX, dY) in px/frame, 8.8 fixed → value/256. 6 radius
    // rings {0.5,1,1.5,2,3,4} × 7 angles {0,15,30,45,60,75,90}°, X=r·cosθ, Y=r·sinθ.
    public static let velLUT: [(dx: Double, dy: Double)] = [
        (128/256.0, 0/256.0),  // idx 0
        (123/256.0, 34/256.0),  // idx 1
        (110/256.0, 64/256.0),  // idx 2
        (90/256.0, 91/256.0),  // idx 3
        (64/256.0, 111/256.0),  // idx 4
        (33/256.0, 124/256.0),  // idx 5
        (0/256.0, 128/256.0),  // idx 6
        (256/256.0, 0/256.0),  // idx 7
        (247/256.0, 67/256.0),  // idx 8
        (221/256.0, 128/256.0),  // idx 9
        (181/256.0, 181/256.0),  // idx 10
        (128/256.0, 222/256.0),  // idx 11
        (66/256.0, 248/256.0),  // idx 12
        (0/256.0, 256/256.0),  // idx 13
        (384/256.0, 0/256.0),  // idx 14
        (370/256.0, 100/256.0),  // idx 15
        (332/256.0, 192/256.0),  // idx 16
        (271/256.0, 272/256.0),  // idx 17
        (192/256.0, 333/256.0),  // idx 18
        (99/256.0, 371/256.0),  // idx 19
        (0/256.0, 384/256.0),  // idx 20
        (512/256.0, 0/256.0),  // idx 21
        (494/256.0, 133/256.0),  // idx 22
        (443/256.0, 256/256.0),  // idx 23
        (362/256.0, 362/256.0),  // idx 24
        (256/256.0, 444/256.0),  // idx 25
        (132/256.0, 495/256.0),  // idx 26
        (0/256.0, 512/256.0),  // idx 27
        (768/256.0, 0/256.0),  // idx 28
        (741/256.0, 199/256.0),  // idx 29
        (665/256.0, 384/256.0),  // idx 30
        (543/256.0, 543/256.0),  // idx 31
        (384/256.0, 665/256.0),  // idx 32
        (199/256.0, 742/256.0),  // idx 33
        (0/256.0, 768/256.0),  // idx 34
        (1024/256.0, 0/256.0),  // idx 35
        (989/256.0, 265/256.0),  // idx 36
        (886/256.0, 512/256.0),  // idx 37
        (724/256.0, 724/256.0),  // idx 38
        (512/256.0, 887/256.0),  // idx 39
        (265/256.0, 989/256.0),  // idx 40
        (0/256.0, 1024/256.0),  // idx 41
    ]

    // 10 flight scripts — ripped VERBATIM from ROM bank6 (pointer table @0x4B6A).
    // Header slot (scriptBase+0) is dropped exactly as the ROM stepper does (first
    // executed step = base+4). Each step: (duration frames, move-mask, velLUT index).
    // move-mask bits: 0x01 up, 0x02 down, 0x04 left, 0x08 right (ROM +0x02 semantics).
    public static let scripts: [[FlightStep]] = [
        [ FlightStep(dur: 24, mask: 0x0A, vel: 26), FlightStep(dur: 16, mask: 0x0A, vel: 25), FlightStep(dur: 32, mask: 0x0A, vel: 24), FlightStep(dur: 32, mask: 0x0A, vel: 23), FlightStep(dur: 48, mask: 0x0A, vel: 22) ],  // P0
        [ FlightStep(dur: 24, mask: 0x06, vel: 26), FlightStep(dur: 16, mask: 0x06, vel: 25), FlightStep(dur: 32, mask: 0x06, vel: 24), FlightStep(dur: 32, mask: 0x06, vel: 23), FlightStep(dur: 48, mask: 0x06, vel: 22) ],  // P1
        [ FlightStep(dur: 12, mask: 0x0A, vel: 33), FlightStep(dur: 12, mask: 0x0A, vel: 32), FlightStep(dur: 8, mask: 0x0A, vel: 31), FlightStep(dur: 8, mask: 0x0A, vel: 30), FlightStep(dur: 3, mask: 0x0A, vel: 29), FlightStep(dur: 2, mask: 0x0A, vel: 28), FlightStep(dur: 3, mask: 0x09, vel: 29), FlightStep(dur: 3, mask: 0x09, vel: 30), FlightStep(dur: 3, mask: 0x09, vel: 31), FlightStep(dur: 3, mask: 0x09, vel: 32), FlightStep(dur: 3, mask: 0x09, vel: 33), FlightStep(dur: 3, mask: 0x09, vel: 34), FlightStep(dur: 3, mask: 0x05, vel: 33), FlightStep(dur: 3, mask: 0x05, vel: 32), FlightStep(dur: 3, mask: 0x05, vel: 31), FlightStep(dur: 3, mask: 0x05, vel: 30), FlightStep(dur: 3, mask: 0x05, vel: 29), FlightStep(dur: 3, mask: 0x05, vel: 28), FlightStep(dur: 3, mask: 0x06, vel: 29), FlightStep(dur: 3, mask: 0x06, vel: 30), FlightStep(dur: 3, mask: 0x06, vel: 31), FlightStep(dur: 3, mask: 0x06, vel: 32), FlightStep(dur: 3, mask: 0x06, vel: 33), FlightStep(dur: 3, mask: 0x0A, vel: 34), FlightStep(dur: 16, mask: 0x0A, vel: 33), FlightStep(dur: 64, mask: 0x0A, vel: 32) ],  // P2
        [ FlightStep(dur: 12, mask: 0x06, vel: 33), FlightStep(dur: 12, mask: 0x06, vel: 32), FlightStep(dur: 8, mask: 0x06, vel: 31), FlightStep(dur: 8, mask: 0x06, vel: 30), FlightStep(dur: 3, mask: 0x06, vel: 29), FlightStep(dur: 2, mask: 0x06, vel: 28), FlightStep(dur: 3, mask: 0x05, vel: 29), FlightStep(dur: 3, mask: 0x05, vel: 30), FlightStep(dur: 3, mask: 0x05, vel: 31), FlightStep(dur: 3, mask: 0x05, vel: 32), FlightStep(dur: 3, mask: 0x05, vel: 33), FlightStep(dur: 3, mask: 0x05, vel: 34), FlightStep(dur: 3, mask: 0x09, vel: 33), FlightStep(dur: 3, mask: 0x09, vel: 32), FlightStep(dur: 3, mask: 0x09, vel: 31), FlightStep(dur: 3, mask: 0x09, vel: 30), FlightStep(dur: 3, mask: 0x09, vel: 29), FlightStep(dur: 3, mask: 0x09, vel: 28), FlightStep(dur: 3, mask: 0x0A, vel: 29), FlightStep(dur: 3, mask: 0x0A, vel: 30), FlightStep(dur: 3, mask: 0x0A, vel: 31), FlightStep(dur: 3, mask: 0x0A, vel: 32), FlightStep(dur: 3, mask: 0x0A, vel: 33), FlightStep(dur: 3, mask: 0x06, vel: 34), FlightStep(dur: 16, mask: 0x06, vel: 33), FlightStep(dur: 64, mask: 0x06, vel: 32) ],  // P3
        [ FlightStep(dur: 14, mask: 0x06, vel: 26), FlightStep(dur: 14, mask: 0x06, vel: 25), FlightStep(dur: 14, mask: 0x06, vel: 24), FlightStep(dur: 14, mask: 0x06, vel: 25), FlightStep(dur: 12, mask: 0x06, vel: 26), FlightStep(dur: 8, mask: 0x0A, vel: 27), FlightStep(dur: 12, mask: 0x0A, vel: 26), FlightStep(dur: 16, mask: 0x0A, vel: 25), FlightStep(dur: 32, mask: 0x0A, vel: 26) ],  // P4
        [ FlightStep(dur: 14, mask: 0x0A, vel: 26), FlightStep(dur: 14, mask: 0x0A, vel: 25), FlightStep(dur: 14, mask: 0x0A, vel: 24), FlightStep(dur: 14, mask: 0x0A, vel: 25), FlightStep(dur: 12, mask: 0x0A, vel: 26), FlightStep(dur: 8, mask: 0x06, vel: 27), FlightStep(dur: 12, mask: 0x06, vel: 26), FlightStep(dur: 16, mask: 0x06, vel: 25), FlightStep(dur: 32, mask: 0x06, vel: 26) ],  // P5 (unreferenced/dead)
        [ FlightStep(dur: 8, mask: 0x0A, vel: 26), FlightStep(dur: 8, mask: 0x0A, vel: 25), FlightStep(dur: 8, mask: 0x0A, vel: 24), FlightStep(dur: 8, mask: 0x0A, vel: 25), FlightStep(dur: 8, mask: 0x0A, vel: 26), FlightStep(dur: 8, mask: 0x0A, vel: 27), FlightStep(dur: 8, mask: 0x06, vel: 26), FlightStep(dur: 8, mask: 0x06, vel: 25), FlightStep(dur: 8, mask: 0x06, vel: 24), FlightStep(dur: 12, mask: 0x06, vel: 23), FlightStep(dur: 12, mask: 0x06, vel: 24), FlightStep(dur: 8, mask: 0x06, vel: 25), FlightStep(dur: 8, mask: 0x06, vel: 26), FlightStep(dur: 8, mask: 0x0A, vel: 27), FlightStep(dur: 8, mask: 0x0A, vel: 26), FlightStep(dur: 8, mask: 0x0A, vel: 25), FlightStep(dur: 32, mask: 0x0A, vel: 24) ],  // P6
        [ FlightStep(dur: 8, mask: 0x06, vel: 26), FlightStep(dur: 8, mask: 0x06, vel: 25), FlightStep(dur: 8, mask: 0x06, vel: 24), FlightStep(dur: 8, mask: 0x06, vel: 25), FlightStep(dur: 8, mask: 0x06, vel: 26), FlightStep(dur: 8, mask: 0x06, vel: 27), FlightStep(dur: 8, mask: 0x0A, vel: 26), FlightStep(dur: 8, mask: 0x0A, vel: 25), FlightStep(dur: 8, mask: 0x0A, vel: 24), FlightStep(dur: 12, mask: 0x0A, vel: 23), FlightStep(dur: 12, mask: 0x0A, vel: 24), FlightStep(dur: 8, mask: 0x0A, vel: 25), FlightStep(dur: 8, mask: 0x0A, vel: 26), FlightStep(dur: 8, mask: 0x06, vel: 27), FlightStep(dur: 8, mask: 0x06, vel: 26), FlightStep(dur: 8, mask: 0x06, vel: 25), FlightStep(dur: 32, mask: 0x06, vel: 24) ],  // P7
        [ FlightStep(dur: 3, mask: 0x06, vel: 33), FlightStep(dur: 3, mask: 0x06, vel: 32), FlightStep(dur: 3, mask: 0x06, vel: 31), FlightStep(dur: 3, mask: 0x06, vel: 30), FlightStep(dur: 3, mask: 0x06, vel: 29), FlightStep(dur: 3, mask: 0x06, vel: 28), FlightStep(dur: 3, mask: 0x05, vel: 29), FlightStep(dur: 3, mask: 0x05, vel: 30), FlightStep(dur: 3, mask: 0x05, vel: 31), FlightStep(dur: 3, mask: 0x05, vel: 32), FlightStep(dur: 3, mask: 0x05, vel: 33), FlightStep(dur: 3, mask: 0x09, vel: 34), FlightStep(dur: 3, mask: 0x09, vel: 33), FlightStep(dur: 3, mask: 0x09, vel: 32), FlightStep(dur: 3, mask: 0x09, vel: 31), FlightStep(dur: 3, mask: 0x09, vel: 30), FlightStep(dur: 3, mask: 0x09, vel: 29), FlightStep(dur: 3, mask: 0x0A, vel: 28), FlightStep(dur: 3, mask: 0x0A, vel: 29), FlightStep(dur: 3, mask: 0x0A, vel: 30), FlightStep(dur: 3, mask: 0x0A, vel: 31), FlightStep(dur: 3, mask: 0x0A, vel: 32), FlightStep(dur: 3, mask: 0x0A, vel: 33), FlightStep(dur: 3, mask: 0x0A, vel: 34), FlightStep(dur: 3, mask: 0x06, vel: 33), FlightStep(dur: 48, mask: 0x06, vel: 32) ],  // P8 (dilon divers)
        [ FlightStep(dur: 3, mask: 0x0A, vel: 33), FlightStep(dur: 3, mask: 0x0A, vel: 32), FlightStep(dur: 3, mask: 0x0A, vel: 31), FlightStep(dur: 3, mask: 0x0A, vel: 30), FlightStep(dur: 3, mask: 0x0A, vel: 29), FlightStep(dur: 3, mask: 0x0A, vel: 28), FlightStep(dur: 3, mask: 0x09, vel: 29), FlightStep(dur: 3, mask: 0x09, vel: 30), FlightStep(dur: 3, mask: 0x09, vel: 31), FlightStep(dur: 3, mask: 0x09, vel: 32), FlightStep(dur: 3, mask: 0x09, vel: 33), FlightStep(dur: 3, mask: 0x05, vel: 34), FlightStep(dur: 3, mask: 0x05, vel: 33), FlightStep(dur: 3, mask: 0x05, vel: 32), FlightStep(dur: 3, mask: 0x05, vel: 31), FlightStep(dur: 3, mask: 0x05, vel: 30), FlightStep(dur: 3, mask: 0x05, vel: 29), FlightStep(dur: 3, mask: 0x06, vel: 28), FlightStep(dur: 3, mask: 0x06, vel: 29), FlightStep(dur: 3, mask: 0x06, vel: 30), FlightStep(dur: 3, mask: 0x06, vel: 31), FlightStep(dur: 3, mask: 0x06, vel: 32), FlightStep(dur: 3, mask: 0x06, vel: 33), FlightStep(dur: 3, mask: 0x06, vel: 34), FlightStep(dur: 3, mask: 0x0A, vel: 33), FlightStep(dur: 48, mask: 0x0A, vel: 32) ],  // P9 (dilon divers)
    ]
}

// Per-wave flight-path assignment for Galaxy streams (type 0x18), decoded from the variant-0
// wave table: idx5→P0, 7→P1, 16→P6, 19→P3, 24→P7, 27→P2, 44→P4, 47→P2, 49→P3, 51→P3.
// The Bestiary factory has no wave index (DefaultContent is fixed), so this sequences the paths
// across the fixed schedule: every Galaxy sharlin wave is exactly 6 members, so member N picks
// path sequence[N/6]. Deterministic for the single-World scoring/gameplay run; reset() lets a
// test re-seed it. (docs §flightpath "Galaxy wave → path-index map".)
public enum GalaxyStreamPaths {
    public static let sequence = [0, 1, 6, 3, 7, 2, 4, 2, 3, 3]
    public static let membersPerWave = 6
    // The sim runs in a single isolation domain (see Entity.swift); this per-process sequencer
    // is only touched from the game loop, so nonisolated(unsafe) is the faithful, cheap choice.
    nonisolated(unsafe) private static var callCount = 0

    public static func nextPath() -> Int {
        let wave = callCount / membersPerWave
        callCount += 1
        return sequence[min(wave, sequence.count - 1)]
    }
    public static func reset() { callCount = 0 }
}

// Flight-script mover: plays the given script step-by-step, holding each step's velocity for
// its duration, then holding the terminal velocity until the shared Integrator despawns it.
public struct FlightPathMove: MovementBehavior {
    public let pathIndex: Int
    public init(pathIndex: Int) { self.pathIndex = pathIndex }

    public func step(_ e: Enemy, _ ctx: SimContext) {
        let script = FlightData.scripts[pathIndex]
        guard !script.isEmpty else { return }
        if !e.motionInited {
            e.motionInited = true
            e.flightIndex = 0
            e.flightHold = script[0].dur
            apply(script[0], to: e)
            return
        }
        if e.flightHold > 0 {
            e.flightHold -= 1
            if e.flightHold == 0, e.flightIndex + 1 < script.count {
                e.flightIndex += 1
                e.flightHold = script[e.flightIndex].dur
                apply(script[e.flightIndex], to: e)
            }
            // On the last step flightHold hits 0 and stays there → terminal velocity holds.
        }
    }

    private func apply(_ s: FlightStep, to e: Enemy) {
        let v = FlightData.velLUT[s.vel]
        e.stepX = v.dx; e.stepY = v.dy; e.dirMask = s.mask
    }
}
