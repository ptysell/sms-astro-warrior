#if canImport(SpriteKit)
import SpriteKit
import GameSim

// GalaxyAtlas — turns our hand-authored GalaxyPixelArt grids into nearest-neighbor SKTextures
// and maps each Galaxy sim sprite id to one. Replaces the FNV-hash shape fallback for Galaxy
// types; unauthored ids return nil so GameScene keeps its vector-shape fallback.
@MainActor
public enum GalaxyAtlas {
    private static let palette = GalaxyPalette.shared

    // SKTexture(cgImage:) uses a bottom-left origin, so flip our top-row-first grids vertically.
    private static func tex(_ art: GalaxyPixelArt.Art) -> SKTexture {
        guard let img = GalaxyPixelArt.cgImage(art, palette: palette, flipV: true) else {
            return SKTexture()
        }
        let t = SKTexture(cgImage: img)
        t.filteringMode = .nearest
        return t
    }

    // Built once, lazily, on the main actor.
    private static let textures: [String: SKTexture] = [
        "ship":     tex(GalaxyPixelArt.ship),
        "drone":    tex(GalaxyPixelArt.sharlin),   // wingman reuses the small-ship art
        "bullet":   tex(GalaxyPixelArt.bullet),
        "ebullet":  tex(GalaxyPixelArt.ebullet),
        "cult":     tex(GalaxyPixelArt.cult),
        "zanix":    tex(GalaxyPixelArt.zanix),
        "sharlin":  tex(GalaxyPixelArt.sharlin),
        "kyra":     tex(GalaxyPixelArt.kyra),
        "gyron":    tex(GalaxyPixelArt.gyron),
        "delta":    tex(GalaxyPixelArt.delta),
        "zanoni":   tex(GalaxyPixelArt.zanoni),
    ]

    /// The one-shot explosion burst texture (used by the renderer's hit flash).
    public static let explosion: SKTexture = tex(GalaxyPixelArt.explosion)

    /// Texture for a Galaxy sim sprite id, or nil if we haven't authored art for it yet.
    public static func texture(for id: String) -> SKTexture? { textures[id] }

    /// Every id we ship authored art for (used by tests / callers).
    public static var authoredIDs: [String] { Array(textures.keys) }
}
#endif
