import CoreGraphics
import GameSim

// The renderer is a pure function of Snapshot (§6.1). SpriteKit is host + renderer only.
public protocol Renderer {
    func present(_ snapshot: Snapshot, lerp: Double, viewport: CGSize)
}

// TODO(P1): GameScene: SKScene host with fixed-step update(_:) driving sim.step,
// single root SKNode, node mirroring keyed by ObjectIdentifier, reap-nodes-not-in-snapshot.
// (§6.1) — kept out of the package stub until SpriteKit host is fleshed out.
