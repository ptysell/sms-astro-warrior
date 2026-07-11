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
    public static let scrollSpeed: Double = 1.0     // [extract] logical units / tick
    public static let spawnDistance: Double = 200.0 // [extract] activate-ahead distance (§6.3)

    // Scoring & lives
    public static let startingLives: Int = 3
    public static let extraLifeEvery: Int = 50_000  // up to 4 (§2)
    public static let maxExtraLives: Int = 4

    // Power-up ladder thresholds (§2) — sequence/effects [extract] (D6).
    public static let ladderThresholds: [Int] = [12, 36, 60, 84, 108, 120]

    // RNG seed (§5.11) — fixed for determinism.
    public static let rngSeed: UInt64 = 0xA57E
}
