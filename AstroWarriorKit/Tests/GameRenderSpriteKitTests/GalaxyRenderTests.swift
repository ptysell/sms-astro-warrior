import XCTest
@testable import GameRenderSpriteKit
import GameSim

final class GalaxyRenderTests: XCTestCase {

    // The committed Galaxy palette must carry the exact reference RGB colors (colors are facts).
    // Each expected value is one of the SMS 2-bit-per-channel levels {0,85,170,255}.
    func testPaletteMatchesReferenceColors() {
        let p = GalaxyPalette.shared
        XCTAssertEqual(p.colors.count, 32)

        func expect(_ i: Int, _ r: UInt8, _ g: UInt8, _ b: UInt8, _ label: String) {
            let c = p[i]
            XCTAssertEqual([c.r, c.g, c.b], [r, g, b], "palette[\(i)] (\(label))")
        }
        // Background palette spot-checks.
        expect(0,  0,   0,   0,   "black")
        expect(1,  255, 255, 255, "bg white")
        expect(2,  0,   170, 170, "fortress teal")
        expect(6,  255, 0,   0,   "bg red port")
        expect(9,  255, 255, 0,   "bg yellow")
        // Sprite palette spot-checks (used by our art).
        expect(17, 255, 255, 255, "white")
        expect(18, 255, 0,   170, "cult magenta")
        expect(19, 255, 255, 0,   "yellow")
        expect(20, 255, 0,   0,   "red")
        expect(21, 255, 85,  0,   "orange")
        expect(22, 0,   255, 255, "cyan")
        expect(23, 0,   255, 0,   "green")
        expect(24, 0,   170, 255, "blue")
        expect(25, 0,   0,   255, "deep blue")

        // Structural: every channel is a legal SMS quantization level.
        let levels: Set<UInt8> = [0, 85, 170, 255]
        for (i, c) in p.colors.enumerated() {
            XCTAssertTrue(levels.contains(c.r) && levels.contains(c.g) && levels.contains(c.b),
                          "palette[\(i)] has an off-quantization channel: \(c)")
        }
    }

    // Every Galaxy species (plus player / bullets / boss) must resolve to a recreated texture.
    @MainActor
    func testEverySpeciesResolvesToTexture() {
        let galaxyIDs = ["ship", "bullet", "ebullet",
                         "cult", "zanix", "sharlin", "kyra", "gyron", "delta", "zanoni"]
        for id in galaxyIDs {
            XCTAssertNotNil(GalaxyAtlas.texture(for: id), "no recreated texture for Galaxy id '\(id)'")
        }
        // An unauthored id keeps the shape fallback (nil here).
        XCTAssertNil(GalaxyAtlas.texture(for: "definitely-not-a-galaxy-sprite"))
    }

    // Native sprite sizes (SKTexture point size == pixel size for our nearest-neighbor art).
    @MainActor
    func testNativeSpriteSizes() {
        func size(_ id: String) -> CGSize? { GalaxyAtlas.texture(for: id)?.size() }
        XCTAssertEqual(size("ship"), CGSize(width: 16, height: 16))
        XCTAssertEqual(size("cult"), CGSize(width: 16, height: 16))
        XCTAssertEqual(size("sharlin"), CGSize(width: 8, height: 16))
        XCTAssertEqual(size("bullet"), CGSize(width: 8, height: 8))
    }

    // Every hand-authored grid must be a clean rectangle, and use only legend characters.
    func testPixelGridsAreRectangularAndLegal() {
        let arts: [(String, GalaxyPixelArt.Art)] = [
            ("ship", GalaxyPixelArt.ship),
            ("bullet", GalaxyPixelArt.bullet), ("ebullet", GalaxyPixelArt.ebullet),
            ("cult", GalaxyPixelArt.cult), ("zanix", GalaxyPixelArt.zanix),
            ("sharlin", GalaxyPixelArt.sharlin), ("kyra", GalaxyPixelArt.kyra),
            ("gyron", GalaxyPixelArt.gyron), ("delta", GalaxyPixelArt.delta),
            ("zanoni", GalaxyPixelArt.zanoni), ("explosion", GalaxyPixelArt.explosion),
        ]
        let legal = Set(GalaxyPixelArt.legend.keys).union([".", " "])
        for (name, art) in arts {
            let w = art.width
            XCTAssertGreaterThan(w, 0, "\(name) has zero width")
            for (r, row) in art.rows.enumerated() {
                XCTAssertEqual(row.count, w, "\(name) row \(r) width \(row.count) != \(w)")
                for ch in row where !legal.contains(ch) {
                    XCTFail("\(name) row \(r) has illegal char '\(ch)'")
                }
            }
        }
    }

    // The rasterizer produces opaque pixels where the grid is non-transparent and matches the palette.
    func testRasterizerColorsMatchPalette() {
        let p = GalaxyPalette.shared
        let (w, h, px) = GalaxyPixelArt.rgba(GalaxyPixelArt.cult, palette: p)
        XCTAssertEqual(w, 16); XCTAssertEqual(h, 16)
        // Row 0 col 4 of `cult` is magenta 'M' (index 18); confirm the raster carries that RGB.
        let o = (0 * w + 4) * 4
        let m = p[18]
        XCTAssertEqual([px[o], px[o + 1], px[o + 2], px[o + 3]], [m.r, m.g, m.b, 255])
    }
}
