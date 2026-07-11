#if canImport(SpriteKit)
import SpriteKit
import CoreGraphics

// Placeholder vector shapes rendered once to white textures, then tinted per node.
// Stands in until the recreated SKTextureAtlas lands (§6.4). Cross-platform via CGContext.
enum ShapeKind: Hashable { case arrow, box, diamond, circle, bar }

@MainActor
enum ShapeTextures {
    private static var cache: [ShapeKind: SKTexture] = [:]

    static func texture(_ kind: ShapeKind) -> SKTexture {
        if let t = cache[kind] { return t }
        let t = SKTexture(cgImage: make(kind))
        t.filteringMode = .nearest
        cache[kind] = t
        return t
    }

    private static func make(_ kind: ShapeKind) -> CGImage {
        let n = 64
        let ctx = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        let r = CGRect(x: 6, y: 6, width: n - 12, height: n - 12)
        switch kind {
        case .box:
            ctx.fill(r)
        case .bar:
            ctx.fill(CGRect(x: n/2 - 4, y: 6, width: 8, height: n - 12))
        case .arrow:                         // points up (+Y)
            ctx.move(to: CGPoint(x: r.midX, y: r.maxY))
            ctx.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            ctx.addLine(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.28))
            ctx.addLine(to: CGPoint(x: r.minX, y: r.minY))
            ctx.closePath(); ctx.fillPath()
        case .diamond:
            ctx.move(to: CGPoint(x: r.midX, y: r.maxY))
            ctx.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            ctx.addLine(to: CGPoint(x: r.midX, y: r.minY))
            ctx.addLine(to: CGPoint(x: r.minX, y: r.midY))
            ctx.closePath(); ctx.fillPath()
        case .circle:
            ctx.fillEllipse(in: r)
        }
        return ctx.makeImage()!
    }
}
#endif
