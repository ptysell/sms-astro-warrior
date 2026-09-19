// The single auditable surface of gameplay constants, in logical units (§5.12).
// EVERY value here is [extract] — set against emulator measurement (§11, §16).
// Placeholders below are guesses to make the sim runnable; they are NOT faithful yet.
public enum Tuning {
    // Ship
    public static let shipSpeed: Double = 1.5       // MEASURED from ROM (px/frame, total; normalized)
    public static let shipStartScreenY: Double = 144 // MEASURED: ROM ship rests at screen-y 144
    /// Start Y in our +Y-up logical space (screen-y measured from the top).
    public static var shipStartY: Double { LOGICAL_HEIGHT - shipStartScreenY }  // = 48
    public static let shipFireInterval: Double = 8  // MEASURED: ~8 frames between shots
    public static let shipBulletSpeed: Double = 12.0 // MEASURED from ROM (px/frame, upward)

    // Ship movement bounds — MEASURED from ROM (position is the ship centre).
    public static let shipMinX: Double = 18
    public static let shipMaxX: Double = 242
    public static let shipMinY: Double = LOGICAL_HEIGHT - 182   // screen-Y max 182 → y=10
    public static let shipMaxY: Double = LOGICAL_HEIGHT - 0     // screen-Y min 0  → y=192

    // Scroll & spawning
    public static let scrollSpeed: Double = 1.0     // MEASURED: 1 tick/frame (2 ticks = 1 visual pixel)
    public static let visualScrollPxPerTick: Double = 0.5  // MEASURED: VDP scrolls 0.5 px/frame
    public static let spawnDistance: Double = 200.0 // [extract] activate-ahead distance (§6.3)

    // Scoring & lives
    public static let startingLives: Int = 3
    public static let extraLifeEvery: Int = 50_000  // up to 4 (§2)
    public static let maxExtraLives: Int = 4

    // Power-up ladder thresholds (§2) — sequence/effects [extract] (D6).
    public static let ladderThresholds: [Int] = [12, 36, 60, 84, 108, 120]

    // RNG seed (§5.11) — fixed for determinism.
    public static let rngSeed: UInt64 = 0xA57E

    // —— Enemy motion (Wave-2a) — ROM-EXACT magnitude+direction model (docs/rom-decode-systems.md
    // §"Enemy movement model"). Speeds are px/frame; 8.8-fixed ROM immediates shown as value/256.
    // The shared integrator (Integrator.apply) despawns on the ROM off-screen bounds below.
    public static let despawnScreenY: Double = 200      // ROM: Y_hi >= 0xC8 (bit1/down branch @0x0416)
    public static let despawnXLow: Double = 16          // ROM: X_hi < 0x10 (bit2/left branch)
    public static let despawnXHigh: Double = 248        // ROM: X_hi >= 0xF8 (bit3/right branch)

    public static let aimUnitSpeed: Double = 1.875      // ROM 0x01E0/256 — aim primitive @0x18fd

    // cult (0x15): aimed descent, X drifting to centre. state1 -0.125 px/f each 16f, state2 +0.03125 px/f.
    public static let cultVXDecayPer16: Double = 32.0 / 256.0   // 0x0020
    public static let cultVXRebuildPerF: Double = 8.0 / 256.0   // 0x0008

    // zanix (0x16): 0.5 px/f descent + horizontal sweep |vx| 0..1.5, accel 0.25 px/f² (0x0040/f).
    public static let zanixDescend: Double = 128.0 / 256.0      // 0x0080
    public static let zanixMaxVX: Double = 384.0 / 256.0        // 0x0180
    public static let zanixVXAccel: Double = 64.0 / 256.0       // 0x0040

    // delta (0x19): 2.0 px/f descent + triangular X sweep, accel 0.125 px/f² (0x0020/f). Fires on loop 1.
    public static let deltaDescend: Double = 512.0 / 256.0      // 0x0200
    public static let deltaVXAccel: Double = 32.0 / 256.0       // 0x0020
    public static let deltaMaxVX: Double = 320.0 / 256.0        // sweep amplitude cap (best-fit)

    // kyra (0x22): 3.0 px/f dive, then homes on player-X (accel 0.125 px/f²), then re-dives.
    public static let kyraDive: Double = 768.0 / 256.0          // 0x0300
    public static let kyraVXAccel: Double = 32.0 / 256.0        // 0x0020

    // gyron (0x27): 2.0 px/f + 8-direction spiral (dir script), then X accel 0.09375 px/f² (0x0018/f).
    public static let gyronSpeed: Double = 512.0 / 256.0        // 0x0200
    public static let gyronVXAccel: Double = 24.0 / 256.0       // 0x0018

    // ————————————————— Asteroid / Nebula (Wave-3b) — ROM magnitude+direction model —————————————————
    // All ROM-EXACT from docs/rom-decode-systems.md §velocity + the Sweep-1 decode/verify workflow
    // (astneb-decode-spec). 8.8-fixed immediates shown as value/256; px/f. The shared Integrator despawns
    // on the same bounds as Galaxy. The ROM loop gate "0xC240 >= 3" ⟺ Campaign.loop >= 1 (2nd lap+).
    public static let enemyPoolSlots: Int = 12                  // ROM active-wave pool @0xCA00 = 12 slots
    public static let waveStartFreeSlots: Int = 6               // ROM 0x3F40: ≥6 free slots to START a wave
    // Per-member entry stagger for Ast/Neb line/arc waves (frames per member index). The ROM's record
    // +0x14/+0x13 hold-delays span ~1..64 over a 7-member wave (e.g. ashion {8,24,64,16,40,1,32}); an
    // index-proportional spread reproduces the count-sustaining staggered entry pending exact per-wave
    // decode. Tuned against ParityScore.
    public static let astNebEntryStagger: Double = 6

    // shamir (0x17): descend 1.0 until below the player row, then homing-ram at HALF the aim unit
    // (1.875/2 = 0.9375), re-aimed every 8 frames. (loop-0: renorm ×1.5 is gated off.)
    public static let shamirDescend: Double = 256.0 / 256.0     // 0x0100 = 1.0
    public static let shamirRamSpeed: Double = aimUnitSpeed / 2 // 0.9375
    public static let shamirReaimEvery: Int = 8

    // aster (0x1B): centre-launch (X=128) diagonal burst vx=4.0/vy=2.0, |vx| decelerates per-member to a
    // straight 2.0 fall. Per-member (dir, decel-per-frame) from the variant-1 records (grp24/25/26/27,
    // 48/49/50/51 — all identical). Members 0-2 down-LEFT, 3-5 down-RIGHT; decels {0.125,0.21875,0.75}.
    public static let asterVX: Double = 4.0                     // 0x0400
    public static let asterVY: Double = 2.0                     // 0x0200
    public static let asterMemberDecel: [Double] = [            // per member 0..5, px/f² (value/256)
        32.0/256.0, 56.0/256.0, 192.0/256.0, 192.0/256.0, 56.0/256.0, 32.0/256.0]
    public static let asterMemberRight: [Bool] = [              // per member 0..5: true = down+right
        false, false, false, true, true, true]

    // ashion (0x1D): descend 2.0, then 4.0 after a glancing hit (dodge). Fire loop-gated → silent loop-0.
    public static let ashionDescend: Double = 512.0 / 256.0     // 0x0200 = 2.0
    public static let ashionFastDescend: Double = 1024.0/256.0  // 0x0400 = 4.0

    // burdle (0x1E): descend 2.0; at player_screenY-32 a 16-frame diagonal veer (vx=vy=2.0) toward the
    // player's side, then straight down. Fire loop-gated → silent loop-0.
    public static let burdleDescend: Double = 512.0 / 256.0     // 0x0200 = 2.0
    public static let burdleVeer: Double = 512.0 / 256.0        // 0x0200 = 2.0
    public static let burdleVeerFrames: Int = 16
    public static let burdleTriggerAbove: Double = 32.0         // player_screenY - 0x20

    // tinker (0x21): after a spawn delay, aim (1.875) then multiply BOTH components by a random scale.
    // loop<3 table {3.0,1.5,2.0,2.5}; loop>=3 {3.5,2.0,2.5,3.0}. Then coast (straight-line dive).
    public static let tinkerScalesLoop0: [Double] = [3.0, 1.5, 2.0, 2.5]
    public static let tinkerScalesLoopHi: [Double] = [3.5, 2.0, 2.5, 3.0]

    // ufolick (0x24): enter from the edge OPPOSITE the player, descend 2.0, at the player row flip UP and
    // double to 4.0 while firing a one-shot 6-shot fan.
    public static let ufolickEntryLeftX: Double = 32.0
    public static let ufolickEntryRightX: Double = 224.0
    public static let ufolickDescend: Double = 512.0 / 256.0    // 2.0
    public static let ufolickClimb: Double = 1024.0 / 256.0     // 4.0

    // caborn (0x1F, INDESTRUCTIBLE) & triat (0x25, 8-HP): pure straight-down integrator descent.
    public static let cabornDescend: Double = 256.0 / 256.0     // 1.0 (1.5 on loop>=3)
    public static let cabornDescendHi: Double = 384.0 / 256.0   // 0x0180 = 1.5
    public static let triatDescend: Double = 256.0 / 256.0      // 1.0 (1.5 on loop>=3)
    public static let triatDescendHi: Double = 384.0 / 256.0    // 1.5
    public static let triatSpreadInterval: Double = 64          // frames (32 on loop>=3)

    // tricker (0x26): edge column, descend 2.0, at player row → aimed fire + random vertical jitter.
    public static let trickerDescend: Double = 512.0 / 256.0    // 2.0
    public static let trickerJitterEvery: Int = 32              // 16 on loop>=3

    // arbleby (0x1A): multi-pass diagonal swoop onto the player column, overshoot, mirror-sweep, hover+fire.
    public static let arblebyDive: Double = 640.0 / 256.0       // 0x0280 = 2.5
    public static let arblebySweep: Double = 384.0 / 256.0      // 0x0180 = 1.5
    public static let arblebyXAccel: Double = 32.0 / 256.0      // 0x0020 = 0.125
    public static let arblebyEntryOffset: Double = 32.0
    public static let arblebyHoverFrames: Int = 16

    // dririt (0x20): random speed S on BOTH axes; descend 16f then split into a mirrored diagonal pair.
    public static let driritSpeedsLoop0: [Double] = [           // 0x50A3: 1.0..2.75 px/f
        256.0/256, 320.0/256, 384.0/256, 448.0/256, 512.0/256, 576.0/256, 640.0/256, 704.0/256]
    public static let driritSpeedsLoopHi: [Double] = [          // 0x50B3: 1.5..3.25 px/f
        384.0/256, 448.0/256, 512.0/256, 576.0/256, 640.0/256, 704.0/256, 768.0/256, 832.0/256]
    public static let driritDescendFrames: Int = 16
    public static let driritSplitDwell: Int = 4                 // 1 on loop>=3
    public static let driritYStopScreen: Double = 128.0        // stop splitting past screenY 128

    // dilon (0x23): carrier — descend 2.0, 8-dir orbit (reuse GyronSpiral.rotation), launch a type-0x18
    // sharlin diver (flight-path 8 or 9) every ~32 frames.
    public static let dilonSpeed: Double = 512.0 / 256.0        // 2.0
    public static let dilonDescendFrames: Int = 32
    public static let dilonDiverEvery: Int = 32
}
