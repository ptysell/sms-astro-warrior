#if canImport(SpriteKit)
import SpriteKit
import CoreGraphics
import Foundation
import GameSim

// GalaxyBackdrop — the Galaxy stage backdrop, in NATIVE logical coordinates (0..W, 0..H).
// The owner adds it to the world layer, sets `setScale(cameraScale)` and position .zero so
// native pixels map 1:1 onto the projected field. Two pieces, both OUR own (no ROM):
//   • a 3-layer parallax starfield that scrolls with snap.scrollY, and
//   • a teal fortress wall (recreated tiles, red cannon ports) revealed for the boss.
@MainActor
public final class GalaxyBackdrop: SKNode {
    private let fieldW = Int(LOGICAL_WIDTH)
    private let fieldH = Int(LOGICAL_HEIGHT)
    private let palette = GalaxyPalette.shared

    // Parallax layers: (container with two stacked tiles, scroll rate).
    private struct Layer { let a: SKSpriteNode; let b: SKSpriteNode; let rate: Double }
    private var layers: [Layer] = []

    private let fortress = SKNode()
    private let fortressA = SKSpriteNode()
    private let fortressB = SKSpriteNode()
    private var fortressShown = false

    public override init() {
        super.init()
        buildStarfield()
        buildFortress()
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    // MARK: build

    private func buildStarfield() {
        // Farthest → nearest: fewer/dimmer/slower to denser/brighter/faster.
        let specs: [(count: Int, seed: UInt64, rate: Double, palette: [Int], maxSize: Int, z: CGFloat)] = [
            (40, 0x9E3779B1, 0.30, [28, 3],       1, -60),  // gray / slate — distant dust
            (30, 0x1234ABCD, 0.60, [28, 17, 24],  1, -58),  // gray / white / blue
            (18, 0x0BADC0DE, 1.00, [17, 27, 22],  2, -56),  // white / pale-yellow / cyan — near, big
        ]
        for spec in specs {
            let stars = GalaxyPixelArt.stars(w: fieldW, h: fieldH, count: spec.count,
                                             seed: spec.seed, palette: spec.palette, maxSize: spec.maxSize)
            let tex = starTexture(stars)
            let a = SKSpriteNode(texture: tex); let b = SKSpriteNode(texture: tex)
            for n in [a, b] {
                n.anchorPoint = CGPoint(x: 0, y: 0)
                n.size = CGSize(width: fieldW, height: fieldH)
                n.zPosition = spec.z
                addChild(n)
            }
            layers.append(Layer(a: a, b: b, rate: spec.rate))
        }
        updateStarfield(scrollY: 0)
    }

    private func starTexture(_ stars: [GalaxyPixelArt.Star]) -> SKTexture {
        var px = [UInt8](repeating: 0, count: fieldW * fieldH * 4)
        func plot(_ x: Int, _ y: Int, _ c: GalaxyPalette.Color) {
            guard x >= 0, x < fieldW, y >= 0, y < fieldH else { return }
            let o = (y * fieldW + x) * 4
            px[o] = c.r; px[o + 1] = c.g; px[o + 2] = c.b; px[o + 3] = 255
        }
        for s in stars {
            let c = palette[s.paletteIndex]
            let bx = Int(s.x), by = Int(s.y)
            for dy in 0..<s.size { for dx in 0..<s.size { plot(bx + dx, by + dy, c) } }
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let img = CGDataProvider(data: Data(px) as CFData).flatMap {
            CGImage(width: fieldW, height: fieldH, bitsPerComponent: 8, bitsPerPixel: 32,
                    bytesPerRow: fieldW * 4, space: cs, bitmapInfo: info, provider: $0,
                    decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        }
        let t = img.map { SKTexture(cgImage: $0) } ?? SKTexture()
        t.filteringMode = .nearest
        return t
    }

    private func buildFortress() {
        let tex = fortressTexture()
        for n in [fortressA, fortressB] {
            n.texture = tex
            n.anchorPoint = CGPoint(x: 0, y: 0)
            n.size = CGSize(width: fieldW, height: fieldH)
            n.zPosition = -40
            fortress.addChild(n)
        }
        fortress.isHidden = true
        addChild(fortress)
    }

    /// A full-field teal fortress wall of 8×8 recreated tiles, with rows of red cannon ports.
    private func fortressTexture() -> SKTexture {
        let plate = GalaxyPixelArt.rgba(GalaxyPixelArt.fortressPlate, palette: palette)
        let port  = GalaxyPixelArt.rgba(GalaxyPixelArt.fortressPort, palette: palette)
        var px = [UInt8](repeating: 0, count: fieldW * fieldH * 4)
        let cols = fieldW / 8, rows = fieldH / 8
        for ty in 0..<rows {
            for tx in 0..<cols {
                // Ports punched in a regular grid; everything else is plating.
                let isPort = (ty % 5 == 2) && (tx % 4 == 1)
                let tile = isPort ? port : plate
                for r in 0..<8 {
                    for c in 0..<8 {
                        let so = (r * 8 + c) * 4
                        guard tile.px[so + 3] != 0 else { continue }
                        let dx = tx * 8 + c, dy = ty * 8 + r
                        let o = (dy * fieldW + dx) * 4
                        px[o] = tile.px[so]; px[o + 1] = tile.px[so + 1]
                        px[o + 2] = tile.px[so + 2]; px[o + 3] = 255
                    }
                }
            }
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let img = CGDataProvider(data: Data(px) as CFData).flatMap {
            CGImage(width: fieldW, height: fieldH, bitsPerComponent: 8, bitsPerPixel: 32,
                    bytesPerRow: fieldW * 4, space: cs, bitmapInfo: info, provider: $0,
                    decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        }
        let t = img.map { SKTexture(cgImage: $0) } ?? SKTexture()
        t.filteringMode = .nearest
        return t
    }

    // MARK: per-frame update

    /// Scroll the parallax layers. Stars flow DOWN the screen as the ship climbs (scrollY↑).
    public func updateStarfield(scrollY: Double) {
        let h = Double(fieldH)
        for layer in layers {
            let off = (scrollY * layer.rate).truncatingRemainder(dividingBy: h)
            layer.a.position = CGPoint(x: 0, y: -off)
            layer.b.position = CGPoint(x: 0, y: h - off)
        }
    }

    /// Show/scroll the fortress wall. `present` = a boss ("zanoni") is on the field.
    public func updateFortress(present: Bool, scrollY: Double) {
        if present != fortressShown { fortressShown = present; fortress.isHidden = !present }
        guard present else { return }
        let h = Double(fieldH)
        let off = (scrollY * 0.5).truncatingRemainder(dividingBy: h)
        fortressA.position = CGPoint(x: 0, y: -off)
        fortressB.position = CGPoint(x: 0, y: h - off)
    }
}
#endif
