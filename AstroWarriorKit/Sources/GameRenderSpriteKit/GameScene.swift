#if canImport(SpriteKit)
import SpriteKit
import GameSim
import GameController

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// The host (§6.1). SpriteKit is host + renderer only — the sim owns truth.
//   1. Fixed-step inside update(_:) — sim never driven by SpriteKit frame time.
//   2. No SKPhysicsBody for gameplay — collision lives in the sim.
//   3. Nodes are views, hold zero gameplay state — present() is one-way (sim → nodes).
@MainActor
public final class GameScene: SKScene {
    private var world = World()
    private let layer = SKNode()              // single root (texture-loading gotcha)
    private let cam = SKCameraNode()
    private var pool: [SKSpriteNode] = []     // index-pooled placeholder sprites

    private var lastTime: TimeInterval = 0
    private var accumulator: Double = 0
    private var intent = Intent()             // fire defaults on → auto-fire + auto-start

    /// When false (parity debugger), the scene ignores its own mouse/controller and
    /// waits at the title screen — an external driver is the sole input source.
    public var acceptsInternalInput = true {
        didSet { if !acceptsInternalInput { intent.fire = false } }
    }

    /// When true, the internal display-linked update loop does not advance the sim;
    /// an external driver calls stepSim() (parity debugger lockstep).
    public var externallyDriven = false

    /// Current simulation mode (title / playing / …) — used for the debugger's title overlay.
    public var simMode: Mode { world.mode }

    /// Rebuild the world from scratch (parity reset). `fireHeld` primes the title-start
    /// latch so a button already held across the reset doesn't auto-start play.
    public func resetWorld(fireHeld: Bool = false) {
        world = World()
        world.primeTitleFire(fireHeld)
        intent.fire = fireHeld
        pool.forEach { $0.isHidden = true }
        present(world.snapshot())          // render the fresh title state immediately
    }

    private var lastHUD: HUDState?
    /// Called (on main) when the HUD state changes — GameUI bridges this to SwiftUI.
    public var onHUD: ((HUDState) -> Void)?

    public override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .black
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    public override func didMove(to view: SKView) {
        addChild(layer)
        addChild(cam)
        camera = cam
        positionCamera()
    }
    public override func didChangeSize(_ oldSize: CGSize) { positionCamera() }

    private let fieldBorder = SKShapeNode()     // playfield outline (also shows the true scale)

    private func positionCamera() {
        let cam2 = Camera(viewport: size)
        cam.position = cam2.fieldCenter
        // Redraw the 256×192 field outline at the current scale.
        let s = cam2.scale
        fieldBorder.path = CGPath(rect: CGRect(x: 0, y: 0, width: LOGICAL_WIDTH * s, height: LOGICAL_HEIGHT * s), transform: nil)
        fieldBorder.strokeColor = SKColor(white: 0.25, alpha: 1)
        fieldBorder.lineWidth = 1
        fieldBorder.zPosition = -10
        if fieldBorder.parent == nil { layer.addChild(fieldBorder) }
    }

    // §6.2 fixed-timestep. Skipped when externally driven (the parity debugger steps
    // the sim itself, in lockstep with the ROM, via stepSim).
    public override func update(_ currentTime: TimeInterval) {
        guard !externallyDriven else { return }
        pollController()
        if lastTime == 0 { lastTime = currentTime }
        accumulator += currentTime - lastTime
        lastTime = currentTime

        var steps = 0
        while accumulator >= SIM_DT && steps < 5 {
            world.step(intent)
            accumulator -= SIM_DT
            steps += 1
        }
        present(world.snapshot())
    }

    /// Advance the sim exactly `ticks` and render — used for deterministic lockstep.
    public func stepSim(_ ticks: Int = 1) {
        guard ticks > 0 else { return }
        for _ in 0..<ticks { world.step(intent) }
        present(world.snapshot())
    }

    /// Player position in logical units — telemetry for the parity readout.
    public var playerPos: Vec2 { world.player.position }

    // Live sim introspection for the debugger's system monitor.
    public var simScore: Int { world.score }
    public var simLives: Int { world.lives }
    public var simForm: Int { world.player.form }
    public var simEntityCount: Int { world.entities.count }
    public var simEnemyCount: Int { world.entities.reduce(0) { $0 + ($1 is Enemy ? 1 : 0) } }
    public var simBulletCount: Int { world.entities.reduce(0) { $0 + ($1 is Bullet ? 1 : 0) } }
    public var simPlayerBullets: Int { world.entities.reduce(0) { $0 + (($1 as? Bullet)?.side == .player ? 1 : 0) } }
    public var simEnemyBullets: Int { world.entities.reduce(0) { $0 + (($1 as? Bullet)?.side == .enemy ? 1 : 0) } }
    public var simBossCount: Int { world.entities.reduce(0) { $0 + ($1 is Boss ? 1 : 0) } }
    public var simPowerUpCount: Int { world.entities.reduce(0) { $0 + ($1 is PowerUp ? 1 : 0) } }
    public var simScrollY: Double { world.scrollY }

    // MARK: render
    private func present(_ snap: Snapshot) {
        let camera = Camera(viewport: size)
        ensurePool(snap.sprites.count)
        for (i, d) in snap.sprites.enumerated() {
            let n = pool[i]
            let look = Appearance.of(d.sprite)
            n.texture = ShapeTextures.texture(look.shape)
            n.colorBlendFactor = 1
            n.color = look.color
            // Draw at EXACTLY the collision size carried in the snapshot (visual == hitbox).
            n.size = CGSize(width: d.size.x * camera.scale, height: d.size.y * camera.scale)
            n.position = camera.project(d.pos)
            n.zPosition = CGFloat(d.z)
            n.isHidden = false
        }
        for i in snap.sprites.count..<pool.count { pool[i].isHidden = true }

        for e in snap.events { spawnEffect(e, camera) }

        if lastHUD != snap.hud { lastHUD = snap.hud; onHUD?(snap.hud) }
    }

    private func ensurePool(_ count: Int) {
        while pool.count < count {
            let n = SKSpriteNode(texture: ShapeTextures.texture(.box))
            n.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            layer.addChild(n)
            pool.append(n)
        }
    }

    private func spawnEffect(_ event: Snapshot.Event, _ camera: Camera) {
        let (pos, color, size): (Vec2, SKColor, Double)
        switch event {
        case let .explosion(p): (pos, color, size) = (p, .orange, 18)
        case let .playerHit(p): (pos, color, size) = (p, .white, 30)
        }
        let burst = SKSpriteNode(texture: ShapeTextures.texture(.circle))
        burst.colorBlendFactor = 1
        burst.color = color
        let px = size * camera.scale
        burst.size = CGSize(width: px, height: px)
        burst.position = camera.project(pos)
        burst.zPosition = 200
        layer.addChild(burst)
        burst.run(.sequence([
            .group([.scale(to: 2.4, duration: 0.25), .fadeOut(withDuration: 0.25)]),
            .removeFromParent()
        ]))
    }

    // MARK: input → Intent (§7). The sim never sees an NSEvent / UITouch / GCController.
    /// Directional drive from keyboard / stick / external driver. Deadzoned.
    public func setMoveAxis(_ v: Vec2) {
        if v.length > 0.2 {
            intent.moveAxis = v
            intent.moveTarget = nil
        } else {
            intent.moveAxis = .zero
        }
    }

    /// Fire input (held). The game holds it permanently; the debugger drives it from Button 1.
    public func setFire(_ on: Bool) { intent.fire = on }

    private func setTarget(scenePoint p: CGPoint) {
        guard acceptsInternalInput else { return }
        let s = Camera(viewport: size).scale
        intent.moveTarget = Vec2(Double(p.x) / s, Double(p.y) / s)
        intent.moveAxis = .zero
    }

    private func pollController() {
        guard acceptsInternalInput, let pad = GCController.current?.extendedGamepad else { return }
        let dx = pad.leftThumbstick.xAxis.value + pad.dpad.xAxis.value
        let dy = pad.leftThumbstick.yAxis.value + pad.dpad.yAxis.value
        let v = Vec2(Double(dx), Double(dy))
        if v.length > 0.2 { setMoveAxis(v) }   // only when actually pushed (don't wipe keys)
    }

    #if os(macOS)
    public override func mouseDown(with event: NSEvent) { setTarget(scenePoint: event.location(in: self)) }
    public override func mouseDragged(with event: NSEvent) { setTarget(scenePoint: event.location(in: self)) }
    #elseif canImport(UIKit)
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let t = touches.first { setTarget(scenePoint: t.location(in: self)) }
    }
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let t = touches.first { setTarget(scenePoint: t.location(in: self)) }
    }
    #endif
}

// Placeholder look-up until the SKTextureAtlas lands (§6.4). Color + shape only —
// size is authoritative from the sim hitbox (Snapshot.SpriteDraw.size).
enum Appearance {
    static func of(_ sprite: SpriteRef) -> (color: SKColor, shape: ShapeKind) {
        switch sprite.id {
        case "ship":    return (.green, .arrow)
        case "drone":   return (.cyan, .arrow)
        case "bullet":  return (.yellow, .bar)
        case "ebullet": return (.red, .circle)
        case "powerup": return (.magenta, .diamond)
        case "zanoni", "nebiros", "belzebul":
            return (.orange, .box)
        case "spindow":
            return (.orange, .diamond)
        default:                                       // standard enemies: distinct hue per type
            return (hueColor(for: sprite.id), .circle)
        }
    }

    // Stable per-id color (Swift's String.hashValue is randomized per run, so FNV here).
    private static func hueColor(for id: String) -> SKColor {
        var h: UInt32 = 2166136261
        for b in id.utf8 { h = (h ^ UInt32(b)) &* 16777619 }
        let hue = CGFloat(h % 360) / 360.0
        return SKColor(hue: hue, saturation: 0.75, brightness: 1.0, alpha: 1.0)
    }
}
#endif
