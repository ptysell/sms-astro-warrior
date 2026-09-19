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
}
