import Foundation
#if canImport(SpriteKit)
import SpriteKit
#endif

// OUR-OWN Galaxy palette. Loads the committed color list (Assets/galaxy/GalaxyPalette.json) —
// the 32 exact RGB COLORS of the original Galaxy CRAM palette (colors are facts, not copyrightable).
// No ROM bytes/tiles/sprites are stored or read; only the color numbers, used to tint our own art.
public struct GalaxyPalette: Sendable {
    public struct Color: Sendable, Equatable {
        public let r: UInt8, g: UInt8, b: UInt8
        public init(_ r: UInt8, _ g: UInt8, _ b: UInt8) { self.r = r; self.g = g; self.b = b }
    }

    /// 32 colors: 0–15 background palette, 16–31 sprite palette (index == array position).
    public let colors: [Color]

    public init(colors: [Color]) { self.colors = colors }

    public subscript(_ i: Int) -> Color {
        (i >= 0 && i < colors.count) ? colors[i] : Color(0, 0, 0)
    }

    // MARK: named sprite-palette colors (indices per GalaxyPalette.json)
    public var white: Color   { self[17] }
    public var magenta: Color { self[18] }
    public var yellow: Color  { self[19] }
    public var red: Color     { self[20] }
    public var orange: Color  { self[21] }
    public var cyan: Color    { self[22] }
    public var green: Color   { self[23] }
    public var blue: Color     { self[24] }
    public var deepBlue: Color { self[25] }
    public var paleGreen: Color { self[26] }
    public var paleYellow: Color { self[27] }
    public var gray: Color     { self[28] }
    public var aqua: Color     { self[29] }
    public var teal: Color     { self[2] }   // background teal — the fortress body color
    public var darkRed: Color  { self[7] }
    public var darkestRed: Color { self[8] }

    // MARK: loading

    private struct Entry: Decodable { let index: Int; let r: Int; let g: Int; let b: Int }
    private struct File: Decodable { let background: [Entry]; let sprite: [Entry] }

    public static let shared: GalaxyPalette = load()

    static func load() -> GalaxyPalette {
        guard let url = Bundle.module.url(forResource: "GalaxyPalette", withExtension: "json",
                                          subdirectory: "Assets/galaxy")
                ?? Bundle.module.url(forResource: "GalaxyPalette", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else {
            // Should never happen (resource is committed); fall back to a black palette.
            return GalaxyPalette(colors: Array(repeating: Color(0, 0, 0), count: 32))
        }
        var out = [Color](repeating: Color(0, 0, 0), count: 32)
        for e in file.background + file.sprite where e.index >= 0 && e.index < 32 {
            out[e.index] = Color(UInt8(clamping: e.r), UInt8(clamping: e.g), UInt8(clamping: e.b))
        }
        return GalaxyPalette(colors: out)
    }

    #if canImport(SpriteKit)
    public func skColor(_ i: Int) -> SKColor {
        let c = self[i]
        return SKColor(red: CGFloat(c.r) / 255, green: CGFloat(c.g) / 255,
                       blue: CGFloat(c.b) / 255, alpha: 1)
    }
    #endif
}
