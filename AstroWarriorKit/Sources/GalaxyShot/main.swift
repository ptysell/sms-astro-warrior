import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import GameSim
import GameRenderSpriteKit
#if canImport(SpriteKit)
import SpriteKit
#endif
#if canImport(Metal)
import Metal
#endif

// GalaxyShot — headless Galaxy screenshot. Drives the PURE sim a few frames, builds the SpriteKit
// Galaxy skin (our starfield + recreated sprites + fortress) into an SKScene, and renders it to a
// PNG with SKRenderer/Metal. Verification only — no ROM is linked or read.
//
// Usage: GalaxyShot [outPath=/tmp/astro-render/galaxy.png] [--boss]

let outPath = CommandLine.arguments.dropFirst().first(where: { !$0.hasPrefix("--") }) ?? "/tmp/astro-render/galaxy.png"
let wantBoss = CommandLine.arguments.contains("--boss")

@MainActor
func run() -> Int32 {
    let scaleFactor = 3
    let vpW = Int(LOGICAL_WIDTH) * scaleFactor   // 768
    let vpH = Int(LOGICAL_HEIGHT) * scaleFactor  // 576
    let viewport = CGSize(width: vpW, height: vpH)
    let camera = Camera(viewport: viewport)      // scale == 3

    // ── 1. Drive the pure sim and keep the BUSIEST on-screen Galaxy frame ────────
    let world = World()
    var intent = Intent()
    intent.fire = true                            // rising edge on frame 1 → title → playing

    func onScreen(_ d: Snapshot.SpriteDraw) -> Bool { d.pos.y >= 4 && d.pos.y <= 188 }
    func isEnemy(_ id: String) -> Bool { !["ship", "bullet", "ebullet", "drone"].contains(id) }
    /// Score a candidate frame: reward enemies visible on the field + a bonus per distinct species.
    func score(_ s: Snapshot) -> Int {
        let vis = s.sprites.filter { isEnemy($0.sprite.id) && onScreen($0) }
        let species = Set(vis.map { $0.sprite.id }).count
        return vis.count + species * 2
    }

    var best = world.snapshot()
    var bestScore = -1
    var bestTick = 0
    var snap = best
    var tick = 0
    let maxTicks = 1400
    while tick < maxTicks {
        let phase = Double(tick) * 0.05
        intent.moveAxis = Vec2(sin(phase), 0)     // gentle left↔right sweep → motion + bullets
        world.step(intent)
        tick += 1
        snap = world.snapshot()
        let sc = score(snap)
        if sc > bestScore { bestScore = sc; best = snap; bestTick = tick }
    }
    snap = best

    // Boss/fortress verification: the sim's boss only fires after ~7400 surviving frames, so for a
    // fortress shot we synthesize the boss state (a Zanoni core + zanix turrets) and let the real
    // GalaxyBackdrop draw the fortress. The render path (backdrop + atlas) is exactly production.
    if wantBoss {
        var s = snap.sprites.filter { $0.sprite.id == "ship" || $0.sprite.id == "bullet" }
        s.append(.init(sprite: SpriteRef("zanoni"), pos: Vec2(128, 150), size: Vec2(32, 32), z: 60))
        s.append(.init(sprite: SpriteRef("zanix"), pos: Vec2(88, 140), size: Vec2(14, 14), z: 55))
        s.append(.init(sprite: SpriteRef("zanix"), pos: Vec2(168, 140), size: Vec2(14, 14), z: 55))
        snap = Snapshot(sprites: s, scrollY: snap.scrollY, background: snap.background,
                        audio: [], events: [], hud: snap.hud)
    }

    let visEnemies = snap.sprites.filter { isEnemy($0.sprite.id) && onScreen($0) }
    print("GalaxyShot: picked frame @tick \(bestTick), scrollY=\(Int(snap.scrollY)), sprites=\(snap.sprites.count), on-screen enemies=\(visEnemies.count), species=\(Set(visEnemies.map{$0.sprite.id}).sorted())")

    // ── 2. Build the SpriteKit Galaxy skin into a scene ─────────────────────────
    let scene = SKScene(size: viewport)
    scene.scaleMode = .resizeFill
    scene.backgroundColor = SKColor.black
    scene.anchorPoint = CGPoint(x: 0, y: 0)

    let backdrop = GalaxyBackdrop()
    backdrop.setScale(camera.scale)
    backdrop.position = .zero
    scene.addChild(backdrop)
    backdrop.updateStarfield(scrollY: snap.scrollY)
    let bossPresent = snap.sprites.contains { $0.sprite.id == "zanoni" }
    backdrop.updateFortress(present: bossPresent, scrollY: snap.scrollY)

    for d in snap.sprites {
        let node: SKSpriteNode
        if let t = GalaxyAtlas.texture(for: d.sprite.id) {
            node = SKSpriteNode(texture: t)
            node.colorBlendFactor = 0
            let px = t.size()
            node.size = CGSize(width: px.width * camera.scale, height: px.height * camera.scale)
        } else {
            node = SKSpriteNode(color: .gray, size: CGSize(width: d.size.x * camera.scale,
                                                           height: d.size.y * camera.scale))
        }
        node.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        node.position = camera.project(d.pos)
        node.zPosition = CGFloat(d.z)
        scene.addChild(node)
    }

    // ── 3. Render headlessly via SKRenderer/Metal → PNG ─────────────────────────
    guard let device = MTLCreateSystemDefaultDevice() else {
        fputs("GalaxyShot: no Metal device — cannot render headlessly.\n", stderr)
        return 2
    }
    let renderer = SKRenderer(device: device)
    renderer.scene = scene

    let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                      width: vpW, height: vpH, mipmapped: false)
    td.usage = [.renderTarget, .shaderRead]
    td.storageMode = .shared
    guard let target = device.makeTexture(descriptor: td),
          let queue = device.makeCommandQueue(),
          let cb = queue.makeCommandBuffer() else {
        fputs("GalaxyShot: Metal target/queue allocation failed.\n", stderr)
        return 2
    }
    let rpd = MTLRenderPassDescriptor()
    rpd.colorAttachments[0].texture = target
    rpd.colorAttachments[0].loadAction = .clear
    rpd.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
    rpd.colorAttachments[0].storeAction = .store
    renderer.render(withViewport: CGRect(x: 0, y: 0, width: vpW, height: vpH),
                    commandBuffer: cb, renderPassDescriptor: rpd)
    cb.commit()
    cb.waitUntilCompleted()

    // Read back RGBA bytes. Metal's render target is top-left origin; SpriteKit's scene is
    // bottom-left, so the pixels come out vertically flipped — flip rows back on the way to PNG.
    var raw = [UInt8](repeating: 0, count: vpW * vpH * 4)
    raw.withUnsafeMutableBytes {
        target.getBytes($0.baseAddress!, bytesPerRow: vpW * 4,
                        from: MTLRegionMake2D(0, 0, vpW, vpH), mipmapLevel: 0)
    }
    var flipped = [UInt8](repeating: 0, count: vpW * vpH * 4)
    for y in 0..<vpH {
        let src = (vpH - 1 - y) * vpW * 4
        let dst = y * vpW * 4
        flipped.replaceSubrange(dst..<(dst + vpW * 4), with: raw[src..<(src + vpW * 4)])
    }

    try? FileManager.default.createDirectory(atPath: (outPath as NSString).deletingLastPathComponent,
                                             withIntermediateDirectories: true)
    let cs = CGColorSpaceCreateDeviceRGB()
    let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    guard let prov = CGDataProvider(data: Data(flipped) as CFData),
          let img = CGImage(width: vpW, height: vpH, bitsPerComponent: 8, bitsPerPixel: 32,
                            bytesPerRow: vpW * 4, space: cs, bitmapInfo: info, provider: prov,
                            decode: nil, shouldInterpolate: false, intent: .defaultIntent),
          let dst = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL,
                                                    UTType.png.identifier as CFString, 1, nil) else {
        fputs("GalaxyShot: PNG encode failed.\n", stderr)
        return 2
    }
    CGImageDestinationAddImage(dst, img, nil)
    guard CGImageDestinationFinalize(dst) else {
        fputs("GalaxyShot: PNG write failed.\n", stderr)
        return 2
    }
    print("GalaxyShot: wrote \(vpW)×\(vpH) → \(outPath)")
    return 0
}

exit(MainActor.assumeIsolated { run() })
